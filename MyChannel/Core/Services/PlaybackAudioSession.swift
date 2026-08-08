//
//  PlaybackAudioSession.swift
//  MyChannel
//
//  Single owner of the app's *playback* AVAudioSession configuration.
//
//  Video playback previously configured the audio session in three separate
//  places — MyChannelApp launch, GlobalPlayerAudioLifecycle, and
//  VideoPlayerManager — each with a *different* option set. That produced
//  repeated setCategory/setActive churn and OSStatus -50 (paramErr) errors in
//  the logs (one of which was `setActive(true, options: .notifyOthersOnDeactivation)`,
//  an invalid combination — that option is only valid when deactivating).
//
//  Routing every playback consumer through this idempotent owner removes the
//  conflict and gives us one canonical category.
//
//  NOTE: Recording features (VoiceSearch `.record`, WatchParty `.playAndRecord`)
//  are intentionally NOT routed here — they own the session while active. They
//  should call `PlaybackAudioSession.shared.reactivate()` when they finish so
//  playback audio is restored cleanly.
//

import AVFoundation

final class PlaybackAudioSession {
    static let shared = PlaybackAudioSession()
    private init() {}

    // Canonical playback configuration for a background-capable video app:
    // exclusive `.playback` (audible to App Store reviewers, plays in background)
    // with AirPlay + high-quality Bluetooth output routing.
    private let category: AVAudioSession.Category = .playback
    private let mode: AVAudioSession.Mode = .moviePlayback
    private let options: AVAudioSession.CategoryOptions = [.allowAirPlay, .allowBluetoothA2DP]

    private var isConfigured = false
    private var isSessionActive = false

    /// Idempotently applies the canonical playback category and activates the
    /// session. Safe to call from any playback entry point. Redundant calls are
    /// cheap no-ops; only real changes hit AVAudioSession.
    @discardableResult
    func activate() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        let session = AVAudioSession.sharedInstance()
        do {
            if !isConfigured || session.category != category || session.categoryOptions != options {
                try session.setCategory(category, mode: mode, options: options)
                isConfigured = true
            }
            if !isSessionActive {
                // No options here: `.notifyOthersOnDeactivation` is only valid
                // when deactivating and passing it to setActive(true) yields -50.
                try session.setActive(true)
                isSessionActive = true
            }
            return true
        } catch {
            #if DEBUG
            print("⚠️ [PlaybackAudioSession] activate failed: \(error.localizedDescription)")
            #endif
            return false
        }
        #endif
    }

    /// Forces the next `activate()` to re-apply the category and re-activate.
    /// Call after an interruption/route change, or when a recording consumer
    /// hands the session back.
    func reactivate() {
        isConfigured = false
        isSessionActive = false
        activate()
    }
}
