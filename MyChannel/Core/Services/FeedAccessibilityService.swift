//
//  FeedAccessibilityService.swift
//  MyChannel
//
//  Phase 279: Feed Accessibility — VoiceOver cell optimization,
//  reduced-motion feed, dynamic type scaling, high-contrast thumbnails.
//

import Foundation

struct FeedAccessibilityConfig: Codable {
    let voiceOverEnabled: Bool
    let reducedMotion: Bool
    let dynamicTypeScale: Double
    let highContrast: Bool
    let largerTapTargets: Bool
}

@MainActor
final class FeedAccessibilityService: ObservableObject {
    static let shared = FeedAccessibilityService()
    private init() {}

    @Published private(set) var config = FeedAccessibilityConfig(voiceOverEnabled: false, reducedMotion: false, dynamicTypeScale: 1.0, highContrast: false, largerTapTargets: false)

    func update(voiceOver: Bool, reducedMotion: Bool, dynamicType: Double, highContrast: Bool) {
        guard AppConfig.Features.enableFeedAccessibility else { return }
        config = FeedAccessibilityConfig(voiceOverEnabled: voiceOver, reducedMotion: reducedMotion, dynamicTypeScale: dynamicType, highContrast: highContrast, largerTapTargets: dynamicType > 1.2)
    }
}
