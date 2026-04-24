//
//  OnboardingExperimentService.swift
//  MyChannel
//
//  Phase 52: Onboarding A/B framework.
//  Wraps Firebase Remote Config + the existing ABTestingManager with
//  a typed set of onboarding variants and activation metrics.
//

import Foundation
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

enum OnboardingVariant: String, Codable, CaseIterable {
    case control                  // current flow
    case valueFirst               // show value props before signup
    case videoTour                // auto-play 20s tour
    case interestPicker           // pick 3 interests first
    case creatorFirst             // creator onboarding by default
    case referralFirst            // ask for referral code up front
    case fastTrack                // sign in first, personalize later
    case personaQuiz              // 3-question persona quiz
    case trendingTonight          // open on trending reel
    case myChannelPlusTrial       // offer 7-day Plus+ trial immediately
}

enum ActivationEvent: String {
    case appOpen
    case signupComplete
    case firstVideoWatched
    case firstInteraction       // like/comment/subscribe
    case firstReturnD1
    case firstReturnD7
}

@MainActor
final class OnboardingExperimentService: ObservableObject {
    static let shared = OnboardingExperimentService()
    private init() {}

    @Published private(set) var assignedVariant: OnboardingVariant = .control
    @Published private(set) var isReady: Bool = false

    /// Resolve the user's assigned variant. Called very early in app launch.
    func resolve(userId: String) async {
        guard AppConfig.Features.enableOnboardingExperiments else {
            assignedVariant = .control
            isReady = true
            return
        }

        // 1. Try Remote Config key `onboarding_variant_v1`.
        #if canImport(FirebaseRemoteConfig)
        let rc = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600
        rc.configSettings = settings
        rc.setDefaults(["onboarding_variant_v1": "control" as NSString])
        _ = try? await rc.fetchAndActivate()
        let raw = rc.configValue(forKey: "onboarding_variant_v1").stringValue
        if let v = OnboardingVariant(rawValue: raw) {
            assignedVariant = v
            isReady = true
            return
        }
        #endif

        // 2. Deterministic hash fallback so same user always gets same variant.
        assignedVariant = Self.hashAssign(userId: userId)
        isReady = true
    }

    /// Log an activation event. Server-side BigQuery pipeline computes D1/D7/D30.
    func logActivation(_ event: ActivationEvent, userId: String) {
        guard AppConfig.Features.enableOnboardingExperiments else { return }
        struct Request: Encodable {
            let task: String
            let uid: String
            let variant: String
            let event: String
            let ts: Double
        }
        Task.detached {
            _ = try? await CloudRunAgentRouter.post(
                .abTestingAI,
                path: "/predict",
                body: Request(
                    task: "log_event",
                    uid: userId,
                    variant: await MainActor.run { self.assignedVariant.rawValue },
                    event: event.rawValue,
                    ts: Date().timeIntervalSince1970
                )
            ) as _Empty
        }
    }

    // MARK: - Helpers

    private static func hashAssign(userId: String) -> OnboardingVariant {
        let all = OnboardingVariant.allCases
        let sum = userId.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return all[sum % all.count]
    }

    private struct _Empty: Decodable {}
}
