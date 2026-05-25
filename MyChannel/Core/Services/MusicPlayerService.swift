//
//  MusicPlayerService.swift
//  MyChannel
//
//  Primary music playback engine for MyChannel Music.
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum MusicRepeatMode: String, Codable {
    case off
    case one
    case all
}

@MainActor
final class MusicPlayerService: ObservableObject {
    static let shared = MusicPlayerService()
    
    // MARK: - Published State
    @Published private(set) var currentSong: Song?
    @Published private(set) var queue: [Song] = []
    @Published private(set) var previousSongs: [Song] = []
    
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isBuffering: Bool = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: MusicRepeatMode = .off
    @Published var isCrossfadeEnabled: Bool = false
    @Published var crossfadeDuration: TimeInterval = 2.0
    @Published var isGaplessEnabled: Bool = true
    @Published var audioQuality: Song.AudioQuality = .standard
    @Published var isSpatialAudioEnabled: Bool = false
    @Published private(set) var sleepTimerEndTime: Date?
    private var sleepTimerTask: Task<Void, Never>?
    
    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var nowPlayingCenter = MPNowPlayingInfoCenter.default()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        configureAudioSession()
        configureRemoteCommands()
    }
    
    // MARK: - Public API
    
    func play(song: Song, inQueue queue: [Song]) {
        // Reuse if same song is already playing
        if currentSong?.id == song.id {
            togglePlayPause()
            return
        }
        
        previousSongs.removeAll()
        self.queue = queue
        
        startPlayback(for: song)
    }
    
    func play(song: Song) {
        play(song: song, inQueue: [song])
    }
    
    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            updateNowPlayingPlaybackRate()
        } else {
            player.play()
            isPlaying = true
            updateNowPlayingPlaybackRate()
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackRate()
    }
    
    func skipNext() {
        guard !queue.isEmpty else {
            if repeatMode == .one, let currentSong {
                startPlayback(for: currentSong)
                return
            }
            stop()
            return
        }
        
        let next: Song
        if isShuffleEnabled {
            next = queue.randomElement() ?? queue[0]
            queue.removeAll { $0.id == next.id }
        } else {
            next = queue.removeFirst()
        }
        
        if let current = currentSong {
            previousSongs.append(current)
        }
        
        startPlayback(for: next)
    }
    
    func skipPrevious() {
        guard let previous = previousSongs.popLast() else {
            // Restart current song if near the beginning
            seek(toFraction: 0)
            return
        }
        
        if let current = currentSong {
            queue.insert(current, at: 0)
        }
        startPlayback(for: previous)
    }
    
    func seek(toFraction fraction: Double) {
        guard let player, duration > 0 else { return }
        let clamped = max(0.0, min(1.0, fraction))
        let seconds = duration * clamped
        seek(toTime: seconds)
    }
    
    func seek(toTime seconds: TimeInterval) {
        guard let player else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time) { [weak self] _ in
            guard let self else { return }
            self.currentTime = seconds
            if self.isPlaying { player.play() }
        }
    }
    
    func setShuffle(_ enabled: Bool) {
        isShuffleEnabled = enabled
    }
    
    func setRepeatMode(_ mode: MusicRepeatMode) {
        repeatMode = mode
    }
    
    func setCrossfadeEnabled(_ enabled: Bool) {
        // NOTE: Crossfade wiring hook; real implementation would blend AVPlayers.
        isCrossfadeEnabled = enabled
    }
    
    // MARK: - Queue Management
    
    func moveQueue(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
    }
    
    func removeFromQueue(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
    }
    
    func clearQueue() {
        queue.removeAll()
    }
    
    func stop() {
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        
        isPlaying = false
        isBuffering = false
        progress = 0
        currentTime = 0
        duration = 0
        currentSong = nil
        nowPlayingCenter.nowPlayingInfo = nil
    }
    
    // MARK: - Sleep Timer
    
    func setSleepTimer(minutes: Int) {
        sleepTimerTask?.cancel()
        sleepTimerEndTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        sleepTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if let endTime = sleepTimerEndTime, Date() >= endTime {
                    pause()
                    sleepTimerEndTime = nil
                    break
                }
            }
        }
    }
    
    func cancelSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerEndTime = nil
    }
    
    var sleepTimerRemaining: TimeInterval? {
        guard let endTime = sleepTimerEndTime else { return nil }
        return max(0, endTime.timeIntervalSinceNow)
    }
    
    // MARK: - Private helpers
    
    private func startPlayback(for song: Song) {
        guard let url = song.streamURL ?? song.alternateStreamURLs.first else {
            // No stream available; nothing to play
            return
        }
        
        isBuffering = true
        currentSong = song
        
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
        
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        
        addObservers()
        player?.play()
        isPlaying = true
        
        updateNowPlayingInfo(for: song)
        
        // Track recently played in Firestore
        Task {
            await saveToRecentlyPlayed(song: song)
        }
    }
    
    private func saveToRecentlyPlayed(song: Song) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        let uid = Auth.auth().currentUser?.uid
        let listenerId = uid ?? "anonymous_\(UUID().uuidString)"
        let db = Firestore.firestore()
        
        do {
            let regionCode = Locale.current.regionCode ?? "US"
            let countryName = Locale.current.localizedString(forRegionCode: regionCode) ?? regionCode
            #if canImport(UIKit)
            let deviceType: String = {
                switch UIDevice.current.userInterfaceIdiom {
                case .pad: return "iPad"
                case .phone: return "iPhone"
                case .tv: return "Apple TV"
                case .mac: return "Mac"
                default: return "Other"
                }
            }()
            #else
            let deviceType = "Unknown"
            #endif

            // Save to user's recently played collection
            let playData: [String: Any] = [
                "songId": song.id,
                "title": song.title,
                "artistIds": song.artistIds,
                "primaryArtistId": song.primaryArtistId,
                "artworkURL": song.artworkURL?.absoluteString ?? "",
                "duration": song.duration,
                "playedAt": FieldValue.serverTimestamp()
            ]

            if let uid {
                try await db.collection("users").document(uid)
                    .collection("recently_played")
                    .document(song.id)
                    .setData(playData, merge: true)
            }

            try await db.collection("music_plays").document().setData([
                "songId": song.id,
                "artistId": song.primaryArtistId,
                "listenerId": listenerId,
                "playedAt": FieldValue.serverTimestamp(),
                "country": countryName,
                "countryCode": regionCode,
                "deviceType": deviceType
            ])

            try await db.collection("music_tracks").document(song.id).setData([
                "streamCount": FieldValue.increment(Int64(1)),
                "lastPlayedAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            // Keep only last 50 recently played
            if let uid {
                let snapshot = try await db.collection("users").document(uid)
                    .collection("recently_played")
                    .order(by: "playedAt", descending: true)
                    .getDocuments()
                
                if snapshot.documents.count > 50 {
                    let toDelete = snapshot.documents.suffix(from: 50)
                    for doc in toDelete {
                        try await doc.reference.delete()
                    }
                }
            }
        } catch {
            print("Error saving to recently played: \(error)")
        }
        #endif
    }
    
    private func addObservers() {
        guard let player else { return }
        
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            guard let item = player.currentItem else { return }
            let durationSeconds = item.duration.seconds
            self.duration = durationSeconds.isFinite ? durationSeconds : 0
            self.currentTime = time.seconds
            if durationSeconds > 0 {
                self.progress = min(1, max(0, time.seconds / durationSeconds))
            } else {
                self.progress = 0
            }
            self.isBuffering = item.isPlaybackLikelyToKeepUp == false && !item.isPlaybackBufferEmpty
            self.updateElapsed(time: time.seconds, duration: durationSeconds)
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            switch self.repeatMode {
            case .one:
                self.seek(toFraction: 0)
                self.player?.play()
            case .all:
                self.skipNext()
            case .off:
                if self.queue.isEmpty {
                    self.stop()
                } else {
                    self.skipNext()
                }
            }
        }
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            // Intentionally ignore; playback still works in most cases.
        }
    }
    
    private func configureRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        
        commands.playCommand.addTarget { [weak self] _ in
            self?.resumeFromRemote()
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            self?.pauseFromRemote()
            return .success
        }
        commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipNext()
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipPrevious()
            return .success
        }
    }
    
    private func resumeFromRemote() {
        player?.play()
        isPlaying = true
        updateNowPlayingPlaybackRate()
    }
    
    private func pauseFromRemote() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackRate()
    }
    
    private func updateNowPlayingInfo(for song: Song) {
        var info: [String: Any] = [
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPMediaItemPropertyPlaybackDuration: song.duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        
        info[MPMediaItemPropertyTitle] = song.title
        
        if let firstArtistId = song.artistIds.first {
            info[MPMediaItemPropertyArtist] = firstArtistId
        }
        
        nowPlayingCenter.nowPlayingInfo = info
    }
    
    private func updateElapsed(time: Double, duration: Double) {
        guard var info = nowPlayingCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingCenter.nowPlayingInfo = info
    }
    
    private func updateNowPlayingPlaybackRate() {
        guard var info = nowPlayingCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingCenter.nowPlayingInfo = info
    }
}

