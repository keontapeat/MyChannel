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
    private var endObserver: NSObjectProtocol?
    private var artworkTask: Task<Void, Never>?
    private var playbackSessionId: UUID?
    private var hasSubmittedQualifiedPlay = false
    private var listenedSeconds: Double = 0
    private var lastObservedTime: Double?
    private var remoteCommandTargets: [(command: MPRemoteCommand, token: Any)] = []
    private var nowPlayingCenter = MPNowPlayingInfoCenter.default()
    
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
        removePlaybackObservers()
        artworkTask?.cancel()
        artworkTask = nil
        player?.pause()
        player = nil

        isPlaying = false
        isBuffering = false
        progress = 0
        currentTime = 0
        duration = 0
        currentSong = nil
        playbackSessionId = nil
        hasSubmittedQualifiedPlay = false
        listenedSeconds = 0
        lastObservedTime = nil
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
        guard let url = publicPlaybackURL(for: song) else {
            return
        }

        isBuffering = true
        currentSong = song
        removePlaybackObservers()
        artworkTask?.cancel()

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        playbackSessionId = UUID()
        hasSubmittedQualifiedPlay = false
        listenedSeconds = 0
        lastObservedTime = 0

        addObservers()
        player?.play()
        isPlaying = true

        updateNowPlayingInfo(for: song)

        Task {
            await saveToRecentlyPlayed(song: song)
        }
    }

    private func publicPlaybackURL(for song: Song) -> URL? {
        let candidates = ([song.streamURL] + song.alternateStreamURLs.map(Optional.some)).compactMap { $0 }
        let publicCandidates = candidates.filter {
            $0.scheme?.lowercased() == "https" && $0.host?.isEmpty == false
        }
        return publicCandidates.first { $0.pathExtension.lowercased() == "m3u8" }
            ?? publicCandidates.first { $0.pathExtension.lowercased() == "mp3" }
            ?? publicCandidates.first
    }
    
    private func saveToRecentlyPlayed(song: Song) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        do {
            let playData: [String: Any] = [
                "songId": song.id,
                "title": song.title,
                "artistIds": song.artistIds,
                "primaryArtistId": song.primaryArtistId,
                "artworkURL": song.artworkURL?.absoluteString ?? "",
                "duration": song.duration,
                "playedAt": FieldValue.serverTimestamp()
            ]
            try await db.collection("users").document(uid)
                .collection("recently_played")
                .document(song.id)
                .setData(playData, merge: true)

            let snapshot = try await db.collection("users").document(uid)
                .collection("recently_played")
                .order(by: "playedAt", descending: true)
                .getDocuments()
            if snapshot.documents.count > 50 {
                for document in snapshot.documents.dropFirst(50) {
                    try await document.reference.delete()
                }
            }
        } catch {
            // Playback remains available when optional listening history cannot be saved.
        }
        #endif
    }
    
    private func addObservers() {
        guard let player else { return }

        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, let item = player.currentItem else { return }
            let durationSeconds = item.duration.seconds
            self.recordPlayback(currentTime: time.seconds)
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

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let finalTime = player.currentItem?.duration.seconds ?? self.duration
            self.recordPlayback(currentTime: finalTime, isFinalSample: true)
            switch self.repeatMode {
            case .one:
                if let currentSong = self.currentSong {
                    self.startPlayback(for: currentSong)
                }
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

    private func removePlaybackObservers() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    private func recordPlayback(currentTime: Double, isFinalSample: Bool = false) {
        defer { lastObservedTime = currentTime }
        guard isPlaying,
              isFinalSample || (player?.rate ?? 0) > 0,
              let previousTime = lastObservedTime else { return }
        let forwardDelta = currentTime - previousTime
        guard forwardDelta > 0, forwardDelta <= 1.5 else { return }
        listenedSeconds += forwardDelta
        guard listenedSeconds >= 30,
              !hasSubmittedQualifiedPlay,
              let songId = currentSong?.id,
              let sessionId = playbackSessionId else { return }
        hasSubmittedQualifiedPlay = true
        let qualifiedSeconds = max(30, Int(listenedSeconds.rounded(.down)))
        Task {
            try? await MusicAPIClient.shared.submitQualifiedPlay(
                trackId: songId,
                sessionId: sessionId,
                qualifiedSeconds: qualifiedSeconds
            )
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
        let playTarget = commands.playCommand.addTarget { [weak self] _ in
            self?.resumeFromRemote()
            return .success
        }
        let pauseTarget = commands.pauseCommand.addTarget { [weak self] _ in
            self?.pauseFromRemote()
            return .success
        }
        let toggleTarget = commands.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        let nextTarget = commands.nextTrackCommand.addTarget { [weak self] _ in
            self?.skipNext()
            return .success
        }
        let previousTarget = commands.previousTrackCommand.addTarget { [weak self] _ in
            self?.skipPrevious()
            return .success
        }
        remoteCommandTargets = [
            (commands.playCommand, playTarget),
            (commands.pauseCommand, pauseTarget),
            (commands.togglePlayPauseCommand, toggleTarget),
            (commands.nextTrackCommand, nextTarget),
            (commands.previousTrackCommand, previousTarget)
        ]
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

