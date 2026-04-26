//
//  AccessibilityIntelligenceService.swift
//  MyChannel
//
//  Phase 135: Accessibility Intelligence.
//  Auto alt-text, audio descriptions, cognitive load adaptation, WCAG AAA automation.
//  Uses `super-ai-team` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct AccessibilityReport: Codable, Identifiable {
    let id: String
    let videoId: String
    let wcagLevel: WCAGLevel
    let score: Double          // 0–100
    let issues: [A11yIssue]
    let generatedAt: Date
}

enum WCAGLevel: String, Codable { case a, aa, aaa }

struct A11yIssue: Codable, Identifiable, Equatable {
    let id: String
    let type: A11yIssueType
    let description: String
    let timestampSec: Double?
    let autoFixAvailable: Bool
}

enum A11yIssueType: String, Codable, CaseIterable {
    case missingAltText, missingCaptions, lowContrast, flashingContent, missingAudioDescription, complexNavigation
}

struct AudioDescription: Codable, Identifiable {
    let id: String
    let videoId: String
    let locale: String
    let audioURL: URL?
    let durationSec: Double
}

struct CognitiveAdaptation: Codable {
    let simplifiedUI: Bool
    let reducedMotion: Bool
    let extendedTimers: Bool
    let readingLevel: String
}

// MARK: - Service

@MainActor
final class AccessibilityIntelligenceService: ObservableObject {
    static let shared = AccessibilityIntelligenceService()
    private init() {}

    @Published private(set) var latestReport: AccessibilityReport?
    @Published private(set) var audioDescriptions: [AudioDescription] = []

    func auditVideo(videoId: String) async throws {
        guard AppConfig.Features.enableAccessibilityIntelligence else { return }
        struct Request: Encodable { let task: String; let videoId: String }
        struct RawIssue: Decodable { let type: String; let description: String; let timestamp: Double?; let auto_fix: Bool }
        struct Raw: Decodable { let level: String?; let score: Double?; let issues: [RawIssue]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "a11y_audit", videoId: videoId), timeout: 45
        )
        latestReport = AccessibilityReport(
            id: UUID().uuidString, videoId: videoId,
            wcagLevel: WCAGLevel(rawValue: r.level ?? "a") ?? .a,
            score: r.score ?? 0,
            issues: (r.issues ?? []).map {
                A11yIssue(id: UUID().uuidString, type: A11yIssueType(rawValue: $0.type) ?? .missingCaptions,
                         description: $0.description, timestampSec: $0.timestamp, autoFixAvailable: $0.auto_fix)
            },
            generatedAt: Date()
        )
    }

    func generateAltText(videoId: String, timestampSec: Double) async throws -> String {
        guard AppConfig.Features.enableAccessibilityIntelligence else { return "" }
        struct Request: Encodable { let task: String; let videoId: String; let timestamp: Double }
        struct Raw: Decodable { let alt_text: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "generate_alt_text", videoId: videoId, timestamp: timestampSec)
        )
        return r.alt_text ?? ""
    }

    func generateAudioDescription(videoId: String, locale: String) async throws -> String {
        guard AppConfig.Features.enableAccessibilityIntelligence else { return "" }
        struct Request: Encodable { let task: String; let videoId: String; let locale: String }
        struct Raw: Decodable { let audio_url: String?; let duration: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "audio_description", videoId: videoId, locale: locale), timeout: 90
        )
        if let url = r.audio_url {
            let desc = AudioDescription(id: UUID().uuidString, videoId: videoId, locale: locale,
                                       audioURL: URL(string: url), durationSec: r.duration ?? 0)
            audioDescriptions.append(desc)
        }
        return r.audio_url ?? ""
    }

    func autoFix(videoId: String, issueId: String) async throws -> Bool {
        guard AppConfig.Features.enableAccessibilityIntelligence else { return false }
        struct Request: Encodable { let task: String; let videoId: String; let issueId: String }
        struct Raw: Decodable { let fixed: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "auto_fix_a11y", videoId: videoId, issueId: issueId)
        )
        return r.fixed ?? false
    }

    func cognitiveAdaptation(userId: String) async throws -> CognitiveAdaptation {
        guard AppConfig.Features.enableAccessibilityIntelligence else {
            return CognitiveAdaptation(simplifiedUI: false, reducedMotion: false, extendedTimers: false, readingLevel: "standard")
        }
        struct Request: Encodable { let task: String; let userId: String }
        struct Raw: Decodable { let simplified: Bool?; let reduced_motion: Bool?; let extended_timers: Bool?; let reading_level: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "cognitive_adapt", userId: userId)
        )
        return CognitiveAdaptation(simplifiedUI: r.simplified ?? false, reducedMotion: r.reduced_motion ?? false,
                                  extendedTimers: r.extended_timers ?? false, readingLevel: r.reading_level ?? "standard")
    }
}
