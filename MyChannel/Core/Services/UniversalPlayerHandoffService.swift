//
//  UniversalPlayerHandoffService.swift
//  MyChannel
//
//  Phase 160: Universal Player Handoff.
//  AirPlay 2 multi-room, Handoff to Mac/TV, CarPlay audio mode.
//

import Foundation
import AVFoundation
import MediaPlayer

// MARK: - Models

struct HandoffState: Codable, Equatable {
    let videoId: String
    let currentTimeSec: Double
    let playbackRate: Float
    let quality: String
    let sourceDevice: String
    let timestamp: Date
}

enum HandoffTarget: String, CaseIterable {
    case appleTV, mac, homePod, carPlay, airPlaySpeaker
    
    var displayName: String {
        switch self {
        case .appleTV: return "Apple TV"
        case .mac: return "Mac"
        case .homePod: return "HomePod"
        case .carPlay: return "CarPlay"
        case .airPlaySpeaker: return "AirPlay Speaker"
        }
    }
    
    var icon: String {
        switch self {
        case .appleTV: return "appletv"
        case .mac: return "laptopcomputer"
        case .homePod: return "homepodmini"
        case .carPlay: return "car"
        case .airPlaySpeaker: return "airplayaudio"
        }
    }
}

struct AirPlayDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let type: HandoffTarget
    let isConnected: Bool
}

// MARK: - Service

@MainActor
final class UniversalPlayerHandoffService: ObservableObject {
    static let shared = UniversalPlayerHandoffService()
    private init() {}

    @Published var isHandoffActive: Bool = false
    @Published var currentHandoffState: HandoffState?
    @Published var availableDevices: [AirPlayDevice] = []
    @Published var connectedDevice: AirPlayDevice?
    @Published var isCarPlayMode: Bool = false
    @Published var isAudioOnlyMode: Bool = false

    func prepareHandoff(videoId: String, currentTimeSec: Double, playbackRate: Float, quality: String) -> HandoffState {
        let state = HandoffState(
            videoId: videoId, currentTimeSec: currentTimeSec,
            playbackRate: playbackRate, quality: quality,
            sourceDevice: UIDevice.current.name, timestamp: Date()
        )
        currentHandoffState = state
        return state
    }

    func initiateHandoff(to target: HandoffTarget) {
        guard AppConfig.Features.enableUniversalPlayerHandoff else { return }
        isHandoffActive = true
        switch target {
        case .carPlay:
            enableCarPlayMode()
        case .airPlaySpeaker, .homePod:
            enableAudioOnlyMode()
        default:
            break
        }
    }

    func receiveHandoff(_ state: HandoffState) {
        guard AppConfig.Features.enableUniversalPlayerHandoff else { return }
        currentHandoffState = state
        isHandoffActive = true
    }

    func enableAirPlay(for player: AVPlayer) {
        guard AppConfig.Features.enableUniversalPlayerHandoff else { return }
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
    }

    func enableCarPlayMode() {
        guard AppConfig.Features.enableUniversalPlayerHandoff else { return }
        isCarPlayMode = true
        isAudioOnlyMode = true
        setupNowPlayingInfo()
    }

    func disableCarPlayMode() {
        isCarPlayMode = false
        isAudioOnlyMode = false
    }

    func enableAudioOnlyMode() {
        guard AppConfig.Features.enableUniversalPlayerHandoff else { return }
        isAudioOnlyMode = true
    }

    func setupNowPlayingInfo() {
        guard let state = currentHandoffState else { return }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = "MyChannel Video"
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = state.currentTimeSec
        info[MPNowPlayingInfoPropertyPlaybackRate] = state.playbackRate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func setupRemoteCommands(onPlay: @escaping () -> Void, onPause: @escaping () -> Void, onSeek: @escaping (Double) -> Void) {
        guard AppConfig.Features.enableUniversalPlayerHandoff else { return }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in onPlay(); return .success }
        center.pauseCommand.addTarget { _ in onPause(); return .success }
        center.changePlaybackPositionCommand.addTarget { event in
            if let e = event as? MPChangePlaybackPositionCommandEvent { onSeek(e.positionTime) }
            return .success
        }
    }

    func endHandoff() {
        isHandoffActive = false
        currentHandoffState = nil
        isCarPlayMode = false
        isAudioOnlyMode = false
    }
}
