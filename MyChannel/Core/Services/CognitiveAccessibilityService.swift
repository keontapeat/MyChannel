//
//  CognitiveAccessibilityService.swift
//  MyChannel
//
//  Phase 219: Cognitive accessibility — simplified UI modes,
//  reading assistance, focus modes, cognitive load scoring.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation

struct CognitiveProfile: Codable {
    let userId: String
    let mode: CognitiveMode
    let readingLevel: Int
    let focusModeEnabled: Bool
    let simplifiedNavigation: Bool
    let reducedChoices: Bool
    let autoPauseEnabled: Bool
    let captionSize: String
    enum CognitiveMode: String, Codable { case standard, simplified, focus, assisted }
}

struct CognitiveLoadScore: Codable {
    let screen: String
    let elementCount: Int
    let interactionCount: Int
    let textDensity: Double
    let score: Double
    let recommendation: String
}

@MainActor
final class CognitiveAccessibilityService: ObservableObject {
    static let shared = CognitiveAccessibilityService()
    private init() {}
    @Published private(set) var profile: CognitiveProfile?

    func fetchProfile(userId: String) async throws {
        struct Req: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let mode: String?; let level: Int?; let focus: Bool?; let simple_nav: Bool?; let reduced: Bool?; let auto_pause: Bool?; let caption: String? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "fetch_cognitive_profile", userId: userId))
        profile = CognitiveProfile(userId: userId, mode: .init(rawValue: r.mode ?? "standard") ?? .standard,
            readingLevel: r.level ?? 3, focusModeEnabled: r.focus ?? false, simplifiedNavigation: r.simple_nav ?? false,
            reducedChoices: r.reduced ?? false, autoPauseEnabled: r.auto_pause ?? false, captionSize: r.caption ?? "large")
    }

    func updateProfile(userId: String, mode: CognitiveProfile.CognitiveMode, focusEnabled: Bool, simplifiedNav: Bool) async throws {
        struct Req: Encodable { let task: String; let userId: String; let mode: String; let focus: Bool; let simple_nav: Bool }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "update_cognitive_profile", userId: userId, mode: mode.rawValue, focus: focusEnabled, simple_nav: simplifiedNav))
        profile = CognitiveProfile(userId: userId, mode: mode, readingLevel: profile?.readingLevel ?? 3,
            focusModeEnabled: focusEnabled, simplifiedNavigation: simplifiedNav, reducedChoices: profile?.reducedChoices ?? false,
            autoPauseEnabled: profile?.autoPauseEnabled ?? false, captionSize: profile?.captionSize ?? "large")
    }

    func assessLoad(screen: String, elements: Int, interactions: Int, textChars: Int) -> CognitiveLoadScore {
        let density = Double(textChars) / max(Double(elements), 1)
        let score = min(10.0, Double(elements) * 0.3 + Double(interactions) * 0.4 + density * 0.01)
        let rec = score > 7 ? "Simplify: reduce elements and interactions" : score > 5 ? "Consider grouping related controls" : "Acceptable cognitive load"
        return CognitiveLoadScore(screen: screen, elementCount: elements, interactionCount: interactions, textDensity: density, score: score, recommendation: rec)
    }
}
