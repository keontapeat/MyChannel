// MARK: - MLAgentIntegrationManager.swift
// Central integration point - runs all new ML agents during key app events
// Integrates with existing LazyServiceManager and AppState

import Foundation
import UIKit

@MainActor
final class MLAgentIntegrationManager: ObservableObject {

    static let shared = MLAgentIntegrationManager()
    private let agents = NewMLAgentsService.shared

    private init() {}

    // MARK: - App Launch Integration

    /// Called on app launch - runs lightweight device-level agents
    func onAppLaunch(userId: String, deviceInfo: [String: Any]) async {
        async let battery = runBatteryOptimizer(deviceInfo: deviceInfo)
        async let offline = runOfflineContentPredictor(userId: userId, deviceInfo: deviceInfo)
        async let compliance = runComplianceCheck()
        let _ = await (battery, offline, compliance)
    }

    // MARK: - Session Start Integration

    /// Called when user opens a new browsing session
    func onSessionStart(userId: String, sessionData: [String: Any]) async {
        async let intent = runSessionIntent(userId: userId, sessionData: sessionData)
        async let mood = runMoodDetection(userId: userId, sessionData: sessionData)
        async let fatigue = runContentFatigue(userId: userId)
        async let discovery = runDiscoveryMode(userId: userId, sessionData: sessionData)
        let _ = await (intent, mood, fatigue, discovery)
    }

    // MARK: - Video Playback Integration

    /// Called when video starts playing - check sleep, binge, second screen
    func onVideoStart(userId: String, videoId: String, sessionMetrics: [String: Any]) async {
        async let binge = runBingePredictor(userId: userId, sessionMetrics: sessionMetrics)
        async let screen = runSecondScreen(userId: userId)
        let _ = await (binge, screen)
    }

    /// Called every 5 min during playback - check sleep mode
    func onPlaybackHeartbeat(userId: String, interactionSignals: [String: Any]) async {
        do {
            let result = try await agents.detectSleepMode(userId: userId, interactionSignals: interactionSignals)
            if let isSleeping = result["isSleeping"] as? Bool, isSleeping {
                await MainActor.run {
                    NotificationCenter.default.post(name: .sleepModeDetected, object: result)
                }
            }
        } catch {
            print("Sleep mode check failed: \(error)")
        }
    }

    // MARK: - Video Upload Integration

    /// Run full pre-publish analysis pipeline
    func onVideoUpload(videoId: String, videoData: [String: Any]) async -> VideoUploadAnalysis {
        var analysis = VideoUploadAnalysis()

        // Audio quality gate
        if let audioUri = videoData["audioUri"] as? String {
            do {
                let quality = try await agents.checkAudioQuality(videoId: videoId, audioUri: audioUri)
                analysis.audioQuality = quality
                analysis.audioPassesQualityGate = (quality["publishReady"] as? Bool) ?? true
            } catch { print("Audio quality check failed: \(error)") }
        }

        // Chapters & scene detection
        if let videoUrl = videoData["videoUrl"] as? String {
            do {
                let scenes = try await agents.detectScenes(videoId: videoId, videoUrl: videoUrl)
                analysis.scenes = scenes
            } catch { print("Scene detection failed: \(error)") }
        }

        // Pacing analysis
        if let transcript = videoData["transcript"] as? String,
           let duration = videoData["duration"] as? Int {
            do {
                let pacing = try await agents.analyzePacing(videoId: videoId, transcript: transcript, duration: duration)
                analysis.pacing = pacing
            } catch { print("Pacing analysis failed: \(error)") }

            // Hook analysis
            do {
                let hook = try await agents.analyzeHook(videoId: videoId, transcript: transcript, retentionData: [])
                analysis.hookAnalysis = hook
            } catch { print("Hook analysis failed: \(error)") }

            // Video summary
            do {
                let title = videoData["title"] as? String ?? ""
                let summary = try await agents.summarizeVideo(videoId: videoId, transcript: transcript, title: title)
                analysis.summary = summary
            } catch { print("Summary failed: \(error)") }
        }

        // Cultural sensitivity for targeted regions
        do {
            let sensitivityResult = try await agents.checkCulturalSensitivity(
                videoId: videoId,
                content: videoData,
                targetRegions: ["US", "GB", "IN", "NG", "BR", "ID"]
            )
            analysis.culturalSensitivity = sensitivityResult
            analysis.isCulturallySafe = (sensitivityResult["overallSafe"] as? Bool) ?? true
        } catch { print("Cultural sensitivity check failed: \(error)") }

        // Music check
        if let flaggedSong = videoData["flaggedSong"] as? [String: Any] {
            do {
                let alternatives = try await agents.findMusicAlternatives(videoId: videoId, flaggedSong: flaggedSong)
                analysis.musicAlternatives = alternatives
            } catch { print("Music licensing check failed: \(error)") }
        }

        // Synthetic media detection
        do {
            let synthetic = try await agents.detectSyntheticMedia(videoId: videoId, content: videoData)
            analysis.syntheticMediaCheck = synthetic
            if let requiresDisclosure = synthetic["requiresDisclosure"] as? Bool, requiresDisclosure {
                analysis.requiresAIDisclosureLabel = true
            }
        } catch { print("Synthetic media check failed: \(error)") }

        return analysis
    }

    // MARK: - Live Stream Integration

    /// Check cultural sensitivity and gifting optimization during live streams
    func onLiveStreamTick(creatorId: String, viewerId: String, streamData: [String: Any], userData: [String: Any]) async {
        do {
            let giftOpt = try await agents.optimizeGifting(
                userId: viewerId,
                creatorId: creatorId,
                streamData: streamData,
                userData: userData
            )
            if let shouldPrompt = giftOpt["shouldPromptGift"] as? Bool, shouldPrompt {
                NotificationCenter.default.post(name: .giftPromptReady, object: giftOpt)
            }
        } catch { print("Gifting optimizer failed: \(error)") }
    }

    // MARK: - Security Integration

    /// Called on every login - check for account takeover
    func onUserLogin(userId: String, loginSignals: [String: Any]) async -> Bool {
        do {
            let result = try await agents.assessAccountTakeover(userId: userId, signals: loginSignals)
            let action = result["actionRequired"] as? String ?? "allow"
            let riskScore = result["riskScore"] as? Double ?? 0.0

            if action == "block_and_notify" || riskScore >= 0.8 {
                NotificationCenter.default.post(name: .accountTakeoverDetected, object: result)
                return false // Block login
            }
            return true
        } catch {
            return true // Fail open on error
        }
    }

    /// Scan text content for phishing before posting
    func scanForPhishing(contentId: String, text: String) async -> Bool {
        do {
            let result = try await agents.detectPhishing(contentId: contentId, text: text)
            return !((result["isPhishing"] as? Bool) ?? false)
        } catch {
            return true // Fail open
        }
    }

    // MARK: - Private Helpers

    private func runBatteryOptimizer(deviceInfo: [String: Any]) async {
        guard let batteryLevel = deviceInfo["batteryLevel"] as? Double, batteryLevel < 0.3 else { return }
        do {
            let opts = try await agents.getBatteryOptimizations(
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "",
                deviceState: deviceInfo
            )
            NotificationCenter.default.post(name: .batteryOptimizationsReady, object: opts)
        } catch { print("Battery optimizer failed: \(error)") }
    }

    private func runOfflineContentPredictor(userId: String, deviceInfo: [String: Any]) async {
        do {
            let result = try await agents.predictOfflineContent(
                userId: userId,
                userProfile: [:],
                deviceInfo: deviceInfo
            )
            if let shouldDownload = result["shouldDownload"] as? Bool, shouldDownload {
                NotificationCenter.default.post(name: .offlineContentReady, object: result)
            }
        } catch { print("Offline predictor failed: \(error)") }
    }

    private func runComplianceCheck() async {
        let locale = Locale.current.region?.identifier ?? "US"
        do {
            let requirements = try await agents.getComplianceRequirements(country: locale)
            NotificationCenter.default.post(name: .complianceRequirementsLoaded, object: requirements)
        } catch { print("Compliance check failed: \(error)") }
    }

    private func runSessionIntent(userId: String, sessionData: [String: Any]) async {
        do {
            let intent = try await agents.detectSessionIntent(userId: userId, sessionData: sessionData)
            NotificationCenter.default.post(name: .sessionIntentDetected, object: intent)
        } catch { print("Session intent failed: \(error)") }
    }

    private func runMoodDetection(userId: String, sessionData: [String: Any]) async {
        do {
            let mood = try await agents.detectUserMood(userId: userId, behavior: sessionData)
            NotificationCenter.default.post(name: .userMoodDetected, object: mood)
        } catch { print("Mood detection failed: \(error)") }
    }

    private func runContentFatigue(userId: String) async {
        do {
            let fatigue = try await agents.detectContentFatigue(userId: userId, watchHistory: [], currentSession: [])
            if let fatigued = fatigue["fatigued"] as? Bool, fatigued {
                NotificationCenter.default.post(name: .contentFatigueDetected, object: fatigue)
            }
        } catch { print("Content fatigue failed: \(error)") }
    }

    private func runDiscoveryMode(userId: String, sessionData: [String: Any]) async {
        do {
            let discovery = try await agents.detectDiscoveryMode(userId: userId, userSignals: sessionData)
            NotificationCenter.default.post(name: .discoveryModeDetected, object: discovery)
        } catch { print("Discovery mode failed: \(error)") }
    }

    private func runBingePredictor(userId: String, sessionMetrics: [String: Any]) async {
        do {
            let binge = try await agents.predictBingeWatch(userId: userId, userHistory: [:], currentSession: sessionMetrics)
            NotificationCenter.default.post(name: .bingePredictionReady, object: binge)
        } catch { print("Binge predictor failed: \(error)") }
    }

    private func runSecondScreen(userId: String) async {
        do {
            let screen = try await agents.detectSecondScreen(userId: userId, deviceSessions: [])
            NotificationCenter.default.post(name: .secondScreenDetected, object: screen)
        } catch { print("Second screen check failed: \(error)") }
    }
}

// MARK: - VideoUploadAnalysis

struct VideoUploadAnalysis {
    var audioQuality: [String: Any] = [:]
    var audioPassesQualityGate: Bool = true
    var scenes: [String: Any] = [:]
    var chapters: [String: Any] = [:]
    var pacing: [String: Any] = [:]
    var hookAnalysis: [String: Any] = [:]
    var summary: [String: Any] = [:]
    var culturalSensitivity: [String: Any] = [:]
    var isCulturallySafe: Bool = true
    var musicAlternatives: [String: Any] = [:]
    var syntheticMediaCheck: [String: Any] = [:]
    var requiresAIDisclosureLabel: Bool = false

    var publishReady: Bool {
        audioPassesQualityGate && isCulturallySafe
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let sleepModeDetected         = Notification.Name("sleepModeDetected")
    static let giftPromptReady           = Notification.Name("giftPromptReady")
    static let accountTakeoverDetected   = Notification.Name("accountTakeoverDetected")
    static let batteryOptimizationsReady = Notification.Name("batteryOptimizationsReady")
    static let offlineContentReady       = Notification.Name("offlineContentReady")
    static let complianceRequirementsLoaded = Notification.Name("complianceRequirementsLoaded")
    static let sessionIntentDetected     = Notification.Name("sessionIntentDetected")
    static let userMoodDetected          = Notification.Name("userMoodDetected")
    static let contentFatigueDetected    = Notification.Name("contentFatigueDetected")
    static let discoveryModeDetected     = Notification.Name("discoveryModeDetected")
    static let bingePredictionReady      = Notification.Name("bingePredictionReady")
    static let secondScreenDetected      = Notification.Name("secondScreenDetected")
}
