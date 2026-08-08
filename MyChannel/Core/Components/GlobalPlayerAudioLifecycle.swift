//
//  GlobalPlayerAudioLifecycle.swift
//  MyChannel
//
//  AVAudioSession configuration + UIApplication lifecycle observers
//  extracted from GlobalVideoPlayerManager.
//
//  Audio session conflict with Flicks:
//  - Global player configures `.playback` / `.moviePlayback` once at init.
//  - Flicks uses per-cell AVPlayers (NuclearVideoPlayerView) with its own mute state.
//  - When Flicks tab opens, GlobalVideoPlayerManager.pauseForFlicksEngagement() pauses
//    long-form playback and sets `pausedByFlicks = true` so both surfaces never compete
//    for audio. FlicksView.onDisappear calls resumeAfterLeavingFlicks().
//  - Do NOT call setActive(false) here — that would fight Flicks' inline players.
//

import AVFoundation
import UIKit

@MainActor
final class GlobalPlayerAudioLifecycle {
    var onDidEnterBackground: () -> Void = {}
    var onWillEnterForeground: () -> Void = {}
    var onRouteChange: () -> Void = {}

    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private static var didConfigureAudioSession = false

    func configureAudioSessionOnce() {
        guard !Self.didConfigureAudioSession else { return }
        // Route through the single playback-session owner. The previous inline
        // config used `setActive(true, options: .notifyOthersOnDeactivation)`,
        // an invalid combination that returned OSStatus -50.
        if PlaybackAudioSession.shared.activate() {
            Self.didConfigureAudioSession = true
            print("✅ [GlobalPlayerAudioLifecycle] Audio session configured")
        }
    }

    func startObserving() {
        guard backgroundObserver == nil, foregroundObserver == nil else { return }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onDidEnterBackground()
            }
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onWillEnterForeground()
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            switch reason {
            case .newDeviceAvailable, .oldDeviceUnavailable, .categoryChange:
                Task { @MainActor in
                    self?.onRouteChange()
                }
            default:
                break
            }
        }
    }

    func stopObserving() {
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
            self.backgroundObserver = nil
        }
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
            self.foregroundObserver = nil
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
            self.routeChangeObserver = nil
        }
    }

    deinit {
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
    }
}
