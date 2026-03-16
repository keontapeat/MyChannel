//
//  MusicKitService.swift
//  MyChannel
//
//  🎵🔥 THERMONUCLEAR MUSICKIT SERVICE 🔥🎵
//  Full Apple Music integration with MusicKit
//  - Authorization and subscription status
//  - Full song playback for premium users
//  - Catalog search and browsing
//  - Synced lyrics for karaoke
//  - Spatial audio support
//

import Foundation
import MusicKit
import MediaPlayer
import Combine
import AVFoundation

// MARK: - MusicKit Authorization Status
enum MusicKitAuthStatus: String {
    case notDetermined = "Not Determined"
    case denied = "Denied"
    case restricted = "Restricted"
    case authorized = "Authorized"
}

// MARK: - MusicKit Audio Quality
enum MusicKitAudioQuality: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case highQuality = "High Quality"
    case lossless = "Lossless"
    case hiResLossless = "Hi-Res Lossless"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .standard: return "AAC 256kbps"
        case .highQuality: return "AAC 256kbps"
        case .lossless: return "ALAC up to 24-bit/48kHz"
        case .hiResLossless: return "ALAC up to 24-bit/192kHz"
        }
    }
    
    var bitrate: String {
        switch self {
        case .standard: return "256 kbps"
        case .highQuality: return "256 kbps"
        case .lossless: return "~1,411 kbps"
        case .hiResLossless: return "~9,216 kbps"
        }
    }
}

// MARK: - MusicKit Track Model
struct MusicKitTrack: Identifiable, Equatable {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String?
    let artworkURL: URL?
    let highResArtworkURL: URL?
    let duration: TimeInterval
    let isExplicit: Bool
    let hasLyrics: Bool
    let supportsSpatialAudio: Bool
    let appleMusicID: MusicItemID?
    let previewURL: URL?
    let genres: [String]
    let releaseDate: Date?
    
    // For Flint artists
    var isFlintArtist: Bool = false
    var flintArtistID: String?
    
    static func == (lhs: MusicKitTrack, rhs: MusicKitTrack) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Synced Lyrics
struct SyncedLyric: Identifiable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let words: [SyncedWord]?
}

struct SyncedWord: Identifiable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

// MARK: - MusicKit Service
@MainActor
final class MusicKitService: ObservableObject {
    static let shared = MusicKitService()
    
    // MARK: - Published Properties
    @Published private(set) var authorizationStatus: MusicKitAuthStatus = .notDetermined
    @Published private(set) var hasAppleMusicSubscription: Bool = false
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTrack: MusicKitTrack?
    @Published private(set) var currentPlaybackTime: TimeInterval = 0
    @Published private(set) var currentDuration: TimeInterval = 0
    @Published private(set) var playbackProgress: Double = 0
    @Published private(set) var currentLyrics: [SyncedLyric] = []
    @Published private(set) var currentLyricIndex: Int = 0
    @Published var audioQuality: MusicKitAudioQuality = .highQuality
    @Published var spatialAudioEnabled: Bool = true
    @Published var crossfadeDuration: TimeInterval = 3.0
    
    // Queue management
    @Published private(set) var queue: [MusicKitTrack] = []
    @Published private(set) var queueIndex: Int = 0
    @Published var shuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    
    enum RepeatMode: String, CaseIterable {
        case off = "Off"
        case all = "All"
        case one = "One"
    }
    
    // MARK: - Private Properties
    private let player = ApplicationMusicPlayer.shared
    private var playbackStateObserver: AnyCancellable?
    private var timeObserver: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        setupObservers()
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    deinit {
        timeObserver?.invalidate()
    }
    
    // MARK: - Authorization
    
    /// Request MusicKit authorization
    func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        
        switch status {
        case .authorized:
            authorizationStatus = .authorized
            await checkSubscriptionStatus()
            return true
        case .denied:
            authorizationStatus = .denied
            return false
        case .restricted:
            authorizationStatus = .restricted
            return false
        case .notDetermined:
            authorizationStatus = .notDetermined
            return false
        @unknown default:
            authorizationStatus = .notDetermined
            return false
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let status = MusicAuthorization.currentStatus
        
        switch status {
        case .authorized:
            authorizationStatus = .authorized
            await checkSubscriptionStatus()
        case .denied:
            authorizationStatus = .denied
        case .restricted:
            authorizationStatus = .restricted
        case .notDetermined:
            authorizationStatus = .notDetermined
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }
    
    /// Check if user has Apple Music subscription
    private func checkSubscriptionStatus() async {
        do {
            let subscription = try await MusicSubscription.current
            hasAppleMusicSubscription = subscription.canPlayCatalogContent
        } catch {
            print("❌ [MusicKit] Failed to check subscription: \(error)")
            hasAppleMusicSubscription = false
        }
    }
    
    /// Map MusicKit.Song to MusicKitTrack
    private func track(from song: MusicKit.Song) -> MusicKitTrack {
        MusicKitTrack(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            albumTitle: song.albumTitle,
            artworkURL: song.artwork?.url(width: 300, height: 300),
            highResArtworkURL: song.artwork?.url(width: 1000, height: 1000),
            duration: song.duration ?? 0,
            isExplicit: song.contentRating == .explicit,
            hasLyrics: song.hasLyrics,
            supportsSpatialAudio: song.audioVariants?.contains(.dolbyAtmos) ?? false,
            appleMusicID: song.id,
            previewURL: song.previewAssets?.first?.url,
            genres: song.genreNames,
            releaseDate: song.releaseDate
        )
    }
    
    /// Map MusicKit.Artist to app Artist model
    private func appArtist(from musicArtist: MusicKit.Artist) -> Artist {
        let slug = musicArtist.name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return Artist(
            id: musicArtist.id.rawValue,
            name: musicArtist.name,
            slug: slug.isEmpty ? musicArtist.id.rawValue : slug,
            avatarURL: musicArtist.artwork?.url(width: 300, height: 300),
            heroImageURL: musicArtist.artwork?.url(width: 1000, height: 1000)
        )
    }
    
    /// Map MusicKit.Album to app Album model
    private func appAlbum(from musicAlbum: MusicKit.Album) -> Album {
        Album(
            id: musicAlbum.id.rawValue,
            title: musicAlbum.title,
            artistId: "", // Load .artist relationship for id if needed
            type: .album,
            artworkURL: musicAlbum.artwork?.url(width: 300, height: 300),
            heroArtworkURL: musicAlbum.artwork?.url(width: 1000, height: 1000),
            releaseDate: musicAlbum.releaseDate,
            genres: musicAlbum.genreNames,
            trackIds: [],
            isExplicit: musicAlbum.contentRating == .explicit
        )
    }
    
    // MARK: - Search
    
    /// Search Apple Music catalog
    func search(term: String, limit: Int = 25) async throws -> [MusicKitTrack] {
        guard authorizationStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }
        
        var request = MusicCatalogSearchRequest(term: term, types: [MusicKit.Song.self])
        request.limit = limit
        
        let response = try await request.response()
        return response.songs.map { track(from: $0) }
    }
    
    /// Search for artists
    func searchArtists(term: String, limit: Int = 20) async throws -> [Artist] {
        guard authorizationStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }
        
        var request = MusicCatalogSearchRequest(term: term, types: [MusicKit.Artist.self])
        request.limit = limit
        
        let response = try await request.response()
        return response.artists.map { appArtist(from: $0) }
    }
    
    /// Search for albums
    func searchAlbums(term: String, limit: Int = 20) async throws -> [Album] {
        guard authorizationStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }
        
        var request = MusicCatalogSearchRequest(term: term, types: [MusicKit.Album.self])
        request.limit = limit
        
        let response = try await request.response()
        return response.albums.map { appAlbum(from: $0) }
    }
    
    /// Get top charts
    func getTopCharts(limit: Int = 50) async throws -> [MusicKitTrack] {
        guard authorizationStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }
        
        var request = MusicCatalogChartsRequest(kinds: [.mostPlayed], types: [MusicKit.Song.self])
        request.limit = limit
        
        let response = try await request.response()
        guard let chartSongs = response.songCharts.first?.items else {
            return []
        }
        return chartSongs.prefix(limit).map { track(from: $0) }
    }
    
    /// Get artist's top songs
    func getArtistTopSongs(artistID: MusicItemID, limit: Int = 20) async throws -> [MusicKitTrack] {
        guard authorizationStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }
        
        var request = MusicCatalogResourceRequest<MusicKit.Artist>(matching: \MusicKit.Artist.FilterType.id, equalTo: artistID)
        request.properties = [.topSongs]
        let response = try await request.response()
        guard let musicArtist = response.items.first,
              let topSongs = musicArtist.topSongs else {
            return []
        }
        return topSongs.prefix(limit).map { track(from: $0) }
    }
    
    // MARK: - Playback
    
    /// Play a track (requires Apple Music subscription or MyChannel Premium)
    func play(track: MusicKitTrack) async throws {
        guard authorizationStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }
        
        guard hasAppleMusicSubscription || StoreKitService.shared.isPremium else {
            throw MusicKitError.subscriptionRequired
        }
        
        guard let musicItemID = track.appleMusicID else {
            throw MusicKitError.invalidTrack
        }
        
        // Fetch the full song object
        let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \MusicKit.Song.FilterType.id, equalTo: musicItemID)
        let response = try await request.response()
        guard let song = response.items.first else {
            throw MusicKitError.trackNotFound
        }
        player.queue = [song]
        try await player.play()
        
        currentTrack = track
        isPlaying = true
        startTimeObserver()
        
        // Fetch lyrics if available
        if track.hasLyrics {
            await fetchLyrics(for: song)
        }
        
        // Track analytics
        HapticManager.shared.impact(style: .medium)
        print("🎵 [MusicKit] Now playing: \(track.title) by \(track.artistName)")
    }
    
    /// Play multiple tracks as a queue
    func playQueue(tracks: [MusicKitTrack], startingAt index: Int = 0) async throws {
        guard authorizationStatus == .authorized else {
            throw MusicKitError.notAuthorized
        }
        
        guard hasAppleMusicSubscription || StoreKitService.shared.isPremium else {
            throw MusicKitError.subscriptionRequired
        }
        
        let musicItemIDs = tracks.compactMap { $0.appleMusicID }
        guard !musicItemIDs.isEmpty else {
            throw MusicKitError.invalidTrack
        }
        
        // Fetch all songs
        var musicSongs: [MusicKit.Song] = []
        for id in musicItemIDs {
            let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \MusicKit.Song.FilterType.id, equalTo: id)
            if let response = try? await request.response(), let song = response.items.first {
                musicSongs.append(song)
            }
        }
        guard !musicSongs.isEmpty else {
            throw MusicKitError.trackNotFound
        }
        let startIndex = min(index, musicSongs.count - 1)
        player.queue = ApplicationMusicPlayer.Queue(for: musicSongs, startingAt: musicSongs[startIndex])
        try await player.play()
        
        queue = tracks
        queueIndex = index
        currentTrack = tracks[min(index, tracks.count - 1)]
        isPlaying = true
        startTimeObserver()
        
        HapticManager.shared.impact(style: .medium)
    }
    
    /// Pause playback
    func pause() {
        player.pause()
        isPlaying = false
        HapticManager.shared.impact(style: .light)
    }
    
    /// Resume playback
    func resume() async throws {
        try await player.play()
        isPlaying = true
        HapticManager.shared.impact(style: .light)
    }
    
    /// Toggle play/pause
    func togglePlayback() async throws {
        if isPlaying {
            pause()
        } else {
            try await resume()
        }
    }
    
    /// Skip to next track
    func skipToNext() async throws {
        try await player.skipToNextEntry()
        
        if queueIndex < queue.count - 1 {
            queueIndex += 1
            currentTrack = queue[queueIndex]
        } else if repeatMode == .all {
            queueIndex = 0
            currentTrack = queue.first
        }
        
        HapticManager.shared.impact(style: .light)
    }
    
    /// Skip to previous track
    func skipToPrevious() async throws {
        // If more than 3 seconds in, restart current track
        if currentPlaybackTime > 3 {
            await seek(to: 0)
        } else {
            try await player.skipToPreviousEntry()
            
            if queueIndex > 0 {
                queueIndex -= 1
                currentTrack = queue[queueIndex]
            }
        }
        
        HapticManager.shared.impact(style: .light)
    }
    
    /// Seek to position
    func seek(to time: TimeInterval) async {
        player.playbackTime = time
        currentPlaybackTime = time
    }
    
    /// Seek to progress (0.0 - 1.0)
    func seek(toProgress progress: Double) async {
        let time = currentDuration * progress
        await seek(to: time)
    }
    
    /// Stop playback
    func stop() {
        player.stop()
        isPlaying = false
        currentTrack = nil
        currentPlaybackTime = 0
        currentDuration = 0
        playbackProgress = 0
        currentLyrics = []
        stopTimeObserver()
    }
    
    // MARK: - Queue Management
    
    /// Add track to queue
    func addToQueue(track: MusicKitTrack) {
        queue.append(track)
    }
    
    /// Remove track from queue
    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        queue.remove(at: index)
        
        if index < queueIndex {
            queueIndex -= 1
        }
    }
    
    /// Clear queue
    func clearQueue() {
        queue.removeAll()
        queueIndex = 0
    }
    
    /// Shuffle queue
    func shuffleQueue() {
        guard queue.count > 1 else { return }
        
        let currentTrack = queue[queueIndex]
        var remainingTracks = queue
        remainingTracks.remove(at: queueIndex)
        remainingTracks.shuffle()
        
        queue = [currentTrack] + remainingTracks
        queueIndex = 0
        shuffleEnabled = true
        
        HapticManager.shared.impact(style: .medium)
    }
    
    // MARK: - Lyrics
    
    /// Fetch synced lyrics for a song
    private func fetchLyrics(for song: MusicKit.Song) async {
        // MusicKit provides lyrics through the song's lyrics property
        // For now, we'll create placeholder synced lyrics
        // In production, you'd use the actual MusicKit lyrics API
        
        // Clear existing lyrics
        currentLyrics = []
        currentLyricIndex = 0
        
        // Note: Apple's lyrics API requires additional setup
        // This is a placeholder for the structure
        print("🎤 [MusicKit] Lyrics available for: \(song.title)")
    }
    
    /// Update current lyric based on playback time
    private func updateCurrentLyric() {
        guard !currentLyrics.isEmpty else { return }
        
        let time = currentPlaybackTime
        
        for (index, lyric) in currentLyrics.enumerated() {
            if time >= lyric.startTime && time < lyric.endTime {
                if currentLyricIndex != index {
                    currentLyricIndex = index
                }
                return
            }
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Observe playback state changes
        playbackStateObserver = player.state.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updatePlaybackState()
            }
        }
    }
    
    private func updatePlaybackState() {
        isPlaying = player.state.playbackStatus == .playing
        
        // Update current track info if needed
        // Note: Duration is obtained from the track itself, not PlayParameters
        if currentTrack != nil {
            // Duration is already set when the track is loaded
        }
    }
    
    private func startTimeObserver() {
        stopTimeObserver()
        
        timeObserver = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentPlaybackTime = self.player.playbackTime
                
                if self.currentDuration > 0 {
                    self.playbackProgress = self.currentPlaybackTime / self.currentDuration
                }
                
                self.updateCurrentLyric()
            }
        }
    }
    
    private func stopTimeObserver() {
        timeObserver?.invalidate()
        timeObserver = nil
    }
    
    // MARK: - Spatial Audio
    
    /// Check if current track supports spatial audio
    var currentTrackSupportsSpatialAudio: Bool {
        currentTrack?.supportsSpatialAudio ?? false
    }
    
    /// Toggle spatial audio
    func toggleSpatialAudio() {
        spatialAudioEnabled.toggle()
        HapticManager.shared.impact(style: .rigid)
    }
}

// MARK: - Errors

enum MusicKitError: Error, LocalizedError {
    case notAuthorized
    case subscriptionRequired
    case invalidTrack
    case trackNotFound
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "MusicKit authorization required. Please allow access to Apple Music."
        case .subscriptionRequired:
            return "Apple Music or MyChannel Premium subscription required for full playback."
        case .invalidTrack:
            return "Invalid track. Unable to play this song."
        case .trackNotFound:
            return "Track not found in Apple Music catalog."
        case .playbackFailed:
            return "Playback failed. Please try again."
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension MusicKitService {
    static var preview: MusicKitService {
        let service = MusicKitService.shared
        return service
    }
}
#endif


