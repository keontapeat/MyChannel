//
//  ProfileAccessibilityService.swift
//  MyChannel
//
//  Phase 259: Profile Accessibility & Inclusive Design.
//  VoiceOver optimization, dynamic type scaling, reduced motion modes,
//  high-contrast themes, screen reader navigation.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation
import SwiftUI

// MARK: - Models

struct AccessibilityPreferences: Codable {
    let creatorId: String
    let reduceMotion: Bool
    let highContrast: Bool
    let dynamicTypeScale: Double
    let voiceOverOptimized: Bool
    let prefersColorScheme: ColorSchemePreference
    let screenReaderNavOrder: [String]

    enum ColorSchemePreference: String, Codable { case system, light, dark, highContrastLight, highContrastDark }
}

struct AccessibilityAudit: Codable, Identifiable {
    let id: String
    let creatorId: String
    let score: Double
    let issues: [AccessibilityIssue]
    let auditedAt: Date

    struct AccessibilityIssue: Codable {
        let element: String
        let severity: String
        let description: String
        let suggestion: String
    }
}

// MARK: - Service

@MainActor
final class ProfileAccessibilityService: ObservableObject {
    static let shared = ProfileAccessibilityService()
    private init() {}

    @Published private(set) var preferences: AccessibilityPreferences?
    @Published private(set) var audit: AccessibilityAudit?

    func fetchPreferences(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileAccessibility else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let reduce_motion: Bool?; let high_contrast: Bool?; let type_scale: Double?; let voiceover: Bool?; let color_scheme: String?; let nav_order: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "fetch_accessibility_prefs", creatorId: creatorId)
        )
        preferences = AccessibilityPreferences(creatorId: creatorId, reduceMotion: r.reduce_motion ?? false,
                                                  highContrast: r.high_contrast ?? false, dynamicTypeScale: r.type_scale ?? 1.0,
                                                  voiceOverOptimized: r.voiceover ?? false,
                                                  prefersColorScheme: .init(rawValue: r.color_scheme ?? "system") ?? .system,
                                                  screenReaderNavOrder: r.nav_order ?? [])
    }

    func updatePreferences(creatorId: String, reduceMotion: Bool, highContrast: Bool, typeScale: Double, colorScheme: AccessibilityPreferences.ColorSchemePreference) async throws {
        guard AppConfig.Features.enableProfileAccessibility else { return }
        struct Req: Encodable { let task: String; let creatorId: String; let reduce_motion: Bool; let high_contrast: Bool; let type_scale: Double; let color_scheme: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "update_accessibility_prefs", creatorId: creatorId,
                      reduce_motion: reduceMotion, high_contrast: highContrast, type_scale: typeScale, color_scheme: colorScheme.rawValue)
        )
        preferences = AccessibilityPreferences(creatorId: creatorId, reduceMotion: reduceMotion, highContrast: highContrast,
                                                  dynamicTypeScale: typeScale, voiceOverOptimized: preferences?.voiceOverOptimized ?? false,
                                                  prefersColorScheme: colorScheme, screenReaderNavOrder: preferences?.screenReaderNavOrder ?? [])
    }

    func runAudit(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileAccessibility else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawIssue: Decodable { let element: String; let severity: String; let desc: String; let suggestion: String }
        struct Raw: Decodable { let id: String; let score: Double?; let issues: [RawIssue]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "run_accessibility_audit", creatorId: creatorId), timeout: 30
        )
        audit = AccessibilityAudit(id: r.id, creatorId: creatorId, score: r.score ?? 0,
                                     issues: (r.issues ?? []).map { AccessibilityAudit.AccessibilityIssue(element: $0.element, severity: $0.severity, description: $0.desc, suggestion: $0.suggestion) },
                                     auditedAt: Date())
    }
}
