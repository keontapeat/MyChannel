//
//  ContentModerationService.swift
//  MyChannel
//
//  Created by AI Assistant on 10/19/25.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Content Moderation Service (YouTube Parity)
@MainActor
class ContentModerationService: ObservableObject {
    static let shared = ContentModerationService()
    
    @Published var moderationQueue: [ContentModerationItem] = []
    @Published var automatedActions: [ContentModerationAction] = []
    @Published var communityGuidelines: [CommunityGuideline] = []
    @Published var copyrightClaims: [ModerationCopyrightClaim] = []
    @Published var isProcessing = false
    
    private let networkService = NetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupModerationPipeline()
        loadCommunityGuidelines()
    }
    
    // MARK: - Content Scanning
    
    /// Scan video content for policy violations
    func scanVideoContent(
        videoId: String,
        videoURL: URL,
        metadata: ContentVideoMetadata
    ) async throws -> ContentModerationResult {
        
        isProcessing = true
        defer { isProcessing = false }
        
        var violations: [PolicyViolation] = []
        var maxConfidence: Double = 0.0
        
        // 1. Scan title and description for profanity
        let titleDesc = metadata.title + " " + metadata.description
        let textResult = EnhancedContentModeration.shared.scanText(titleDesc)
        
        if !textResult.isClean {
            for violation in textResult.violations {
                violations.append(PolicyViolation(
                    type: .spam,
                    description: violation,
                    severity: textResult.confidence > 0.7 ? .high : .medium
                ))
            }
            maxConfidence = max(maxConfidence, textResult.confidence)
        }
        
        // 2. Scan tags for inappropriate content
        let tags = metadata.tags
        for tag in tags {
            let tagResult = EnhancedContentModeration.shared.scanText(tag)
            if !tagResult.isClean {
                for violation in tagResult.violations {
                    violations.append(PolicyViolation(
                        type: .spam,
                        description: violation,
                        severity: tagResult.confidence > 0.7 ? .high : .medium
                    ))
                }
                maxConfidence = max(maxConfidence, tagResult.confidence)
            }
        }
        
        // 3. Video-frame analysis (Cloud Vision SafeSearch) runs server-side in
        // extract_thumbnails_on_ready (functions/main.py) once real transcoded
        // frames exist — client-side frame decoding can't be trusted as a
        // moderation gate. That path writes to the same contentFlags/
        // strikeCases collections this service's text scan feeds, so both
        // surfaces land in the same admin review queue (StrikeReviewView).
        
        let hasHighSeverity = violations.contains { $0.severity == .high }
        let hasMediumOrHigh = violations.contains { $0.severity == .medium || $0.severity == .high }
        
        let result = ContentModerationResult(
            type: .content,
            confidence: maxConfidence,
            violations: violations,
            requiresAction: hasHighSeverity,
            requiresHumanReview: hasMediumOrHigh
        )
        
        return result
    }
    
    /// Scan comment for policy violations
    func scanComment(
        commentId: String,
        content: String,
        userId: String
    ) async throws -> CommentModerationResult {
        
        // Real text analysis
        let textResult = EnhancedContentModeration.shared.scanText(content)
        
        // Calculate toxicity score (based on violations found)
        let toxicityScore: Double
        if textResult.violations.contains(where: { $0.contains("Hate speech") || $0.contains("Violent threat") }) {
            toxicityScore = 0.9
        } else if textResult.violations.contains(where: { $0.contains("Profanity") }) {
            toxicityScore = 0.6
        } else {
            toxicityScore = 0.1
        }
        
        // Calculate spam score
        let hasSpam = textResult.violations.contains(where: { $0.contains("Spam") })
        let spamScore: Double = hasSpam ? 0.9 : 0.1
        
        // Check for language violations
        let hasExplicit = textResult.violations.contains(where: { $0.contains("Explicit content") })
        let hasProfanity = textResult.violations.contains(where: { $0.contains("Profanity") })
        let languageViolation = hasExplicit || hasProfanity
        
        // Determine action
        let requiresAction = toxicityScore > 0.7 || spamScore > 0.8
        let suggestedAction: CommentModerationAction = requiresAction ? .remove : .none
        
        let result = CommentModerationResult(
            commentId: commentId,
            toxicityScore: toxicityScore,
            spamScore: spamScore,
            languageViolation: languageViolation,
            requiresAction: requiresAction,
            suggestedAction: suggestedAction
        )
        
        return result
    }
    
    // MARK: - Copyright Management
    
    /// Submit copyright claim
    func submitCopyrightClaim(
        videoId: String,
        claimantInfo: ModerationCopyrightClaimant,
        copyrightedWork: ModerationCopyrightedWork,
        evidence: [ModerationCopyrightEvidence]
    ) async throws -> ModerationCopyrightClaim {
        
        let claim = ModerationCopyrightClaim(
            id: UUID().uuidString,
            videoId: videoId,
            claimant: claimantInfo,
            copyrightedWork: copyrightedWork,
            evidence: evidence,
            status: .submitted,
            submittedAt: Date(),
            reviewDeadline: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
        
        copyrightClaims.append(claim)
        return claim
    }
    
    // MARK: - Community Guidelines
    
    /// Apply community guideline strike
    func applyCommunityStrike(
        userId: String,
        videoId: String,
        violation: ContentGuidelineViolation,
        severity: StrikeSeverity
    ) async throws {
        
        let strike = CommunityStrike(
            id: UUID().uuidString,
            userId: userId,
            videoId: videoId,
            violation: violation,
            severity: severity,
            appliedAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
        )
        
        // Simulate saving strike
        print("Applied community strike: \(strike.id)")
    }
    
    // MARK: - Private Methods
    
    private func setupModerationPipeline() {
        // Setup moderation monitoring
    }
    
    private func loadCommunityGuidelines() {
        communityGuidelines = [
            CommunityGuideline(
                id: "spam",
                title: "Spam and Deceptive Practices",
                description: "Don't spam users with unwanted content",
                severity: .medium
            ),
            CommunityGuideline(
                id: "harassment",
                title: "Harassment and Cyberbullying",
                description: "Don't harass or bully other users",
                severity: .high
            )
        ]
    }
}

// MARK: - Models

struct ContentModerationResult {
    let type: ContentModerationType
    let confidence: Double
    let violations: [PolicyViolation]
    let requiresAction: Bool
    let requiresHumanReview: Bool
}

enum ContentModerationType {
    case content, metadata, thumbnail, copyright, combined
}

struct PolicyViolation {
    let type: ViolationType
    let description: String
    let severity: ViolationSeverity
}

enum ViolationType: String, Codable {
    case spam, harassment, hateSpeech, violence, adultContent, copyright
}

enum ViolationSeverity: String, Codable {
    case low, medium, high, severe
}

struct ContentModerationItem: Identifiable {
    let id: String
    let videoId: String
    let moderationResult: ContentModerationResult
    let priority: ModerationPriority
    let createdAt: Date
    var status: ModerationStatus
}

enum ModerationPriority: Int {
    case low = 1, medium = 2, high = 3, critical = 4
}

enum ModerationStatus {
    case pending, inReview, resolved, escalated
}

struct ContentModerationAction: Identifiable, Codable {
    let id: String
    let videoId: String
    let actionType: ModerationActionType
    let reason: String
    let appliedAt: Date
    let isAutomated: Bool
}

enum ModerationActionType: String, Codable {
    case remove, ageRestrict, demonetize, warning, none
}

struct CommentModerationResult {
    let commentId: String
    let toxicityScore: Double
    let spamScore: Double
    let languageViolation: Bool
    let requiresAction: Bool
    let suggestedAction: CommentModerationAction
}

enum CommentModerationAction: String {
    case remove, markAsSpam, shadowBan, warning, none
}

struct ModerationCopyrightClaim: Identifiable, Codable {
    let id: String
    let videoId: String
    let claimant: ModerationCopyrightClaimant
    let copyrightedWork: ModerationCopyrightedWork
    let evidence: [ModerationCopyrightEvidence]
    var status: ModerationCopyrightClaimStatus
    let submittedAt: Date
    let reviewDeadline: Date
    var counterNotification: ModerationCopyrightCounterNotification?
}

struct ModerationCopyrightClaimant: Codable {
    let name: String
    let email: String
    let organization: String?
    let address: String
}

struct ModerationCopyrightedWork: Codable {
    let title: String
    let description: String
    let originalURL: String?
    let registrationNumber: String?
}

struct ModerationCopyrightEvidence: Codable {
    let type: ModerationEvidenceType
    let url: String
    let description: String
}

enum ModerationEvidenceType: String, Codable {
    case originalWork, registrationCertificate, other
}

enum ModerationCopyrightClaimStatus: String, Codable {
    case submitted, underReview, approved, rejected, counterNotified, resolved
}

struct ModerationCopyrightCounterNotification: Codable {
    let statement: String
    let contactInfo: String
    let submittedAt: Date
}

struct CommunityGuideline: Identifiable {
    let id: String
    let title: String
    let description: String
    let severity: ViolationSeverity
}

struct CommunityStrike: Identifiable, Codable {
    let id: String
    let userId: String
    let videoId: String
    let violation: ContentGuidelineViolation
    let severity: StrikeSeverity
    let appliedAt: Date
    let expiresAt: Date
}

struct ContentGuidelineViolation: Codable {
    let type: ViolationType
    let description: String
}

enum StrikeSeverity: String, Codable {
    case warning, strike, severePenalty
}

struct ContentVideoMetadata {
    let title: String
    let description: String
    let tags: [String]
    let thumbnailURL: String
}

enum ModerationError: Error {
    case claimNotFound
    case invalidEvidence
    case processingFailed
}
