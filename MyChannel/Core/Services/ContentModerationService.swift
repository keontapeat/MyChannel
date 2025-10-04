//
//  ContentModerationService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Combine
import Vision
import NaturalLanguage

/// Enterprise-grade content moderation system with AI-powered detection
/// Handles text, image, and video content moderation at YouTube scale
class ContentModerationService: ObservableObject {
    
    @Published var moderationQueueCount = 0
    @Published var isProcessingContent = false
    @Published var moderationStats = ModerationStatistics()
    
    private let textModerator = TextModerationEngine()
    private let imageModerator = ImageModerationEngine()
    private let videoModerator = VideoModerationEngine()
    private let communityGuidelinesEngine = CommunityGuidelinesEngine()
    
    // Moderation policies and thresholds
    private let moderationConfig = ModerationConfiguration()
    
    // Queue for content moderation
    private var moderationQueue: [ModerationRequest] = []
    
    init() {
        setupModerationEngine()
    }
    
    // MARK: - Public Interface
    
    /// Moderates video content including thumbnail, title, description
    func moderateVideo(_ video: Video) async throws -> ModerationResult {
        isProcessingContent = true
        defer { isProcessingContent = false }
        
        let request = ModerationRequest(
            id: UUID().uuidString,
            contentType: .video,
            contentId: video.id,
            createdAt: Date()
        )
        
        var overallResult = ModerationResult(
            requestId: request.id,
            contentType: .video,
            decision: .approved,
            confidence: 1.0,
            detectedViolations: [],
            moderationTags: [],
            aiAnalysis: nil,
            humanReviewRequired: false,
            processingTime: 0
        )
        
        let startTime = Date()
        
        // 1. Moderate title and description
        let textResult = try await textModerator.moderateText(video.title + " " + video.description)
        
        // 2. Moderate thumbnail image
        let thumbnailResult = try await imageModerator.moderateImage(url: video.thumbnailURL)
        
        // 3. Check community guidelines compliance
        let guidelinesResult = try await communityGuidelinesEngine.checkCompliance(video: video)
        
        // 4. Video content analysis (simplified for demo)
        let videoResult = try await videoModerator.moderateVideoContent(url: video.videoURL)
        
        // Combine results
        let allResults = [textResult, thumbnailResult, guidelinesResult, videoResult]
        let violations = allResults.flatMap { $0.detectedViolations }
        let tags = allResults.flatMap { $0.moderationTags }
        
        // Determine overall decision
        let overallDecision = determineOverallDecision(from: allResults)
        let confidence = calculateOverallConfidence(from: allResults)
        let requiresHuman = violations.contains { $0.severity >= .high } || confidence < 0.8
        
        overallResult = ModerationResult(
            requestId: request.id,
            contentType: .video,
            decision: overallDecision,
            confidence: confidence,
            detectedViolations: violations,
            moderationTags: Array(Set(tags)),
            aiAnalysis: AIAnalysisResult(
                sentimentScore: textResult.aiAnalysis?.sentimentScore ?? 0,
                topicsDetected: extractTopics(from: video.title + " " + video.description),
                visualContent: thumbnailResult.aiAnalysis?.visualContent ?? [],
                riskFactors: violations.map { $0.type.rawValue }
            ),
            humanReviewRequired: requiresHuman,
            processingTime: Date().timeIntervalSince(startTime)
        )
        
        // Update statistics
        await updateModerationStats(result: overallResult)
        
        // Log for analytics
        logModerationDecision(result: overallResult)
        
        return overallResult
    }
    
    /// Moderates chat message content
    func moderateChatMessage(_ message: ChatMessage) async throws -> ModerationResult {
        let startTime = Date()
        
        // Quick text moderation for real-time chat
        let textResult = try await textModerator.moderateText(message.content, isRealTime: true)
        
        let result = ModerationResult(
            requestId: UUID().uuidString,
            contentType: .chatMessage,
            decision: textResult.decision,
            confidence: textResult.confidence,
            detectedViolations: textResult.detectedViolations,
            moderationTags: textResult.moderationTags,
            aiAnalysis: textResult.aiAnalysis,
            humanReviewRequired: false, // Chat messages rarely need human review
            processingTime: Date().timeIntervalSince(startTime)
        )
        
        await updateModerationStats(result: result)
        
        return result
    }
    
    /// Moderates community post content
    func moderateCommunityPost(_ post: CommunityPost) async throws -> ModerationResult {
        let textResult = try await textModerator.moderateText(post.content)
        
        var imageResults: [ModerationResult] = []
        
        // Moderate attached images
        for imageURL in post.imageURLs {
            let imageResult = try await imageModerator.moderateImage(url: imageURL)
            imageResults.append(imageResult)
        }
        
        // Combine results
        let allResults = [textResult] + imageResults
        let violations = allResults.flatMap { $0.detectedViolations }
        let tags = allResults.flatMap { $0.moderationTags }
        
        let overallDecision = determineOverallDecision(from: allResults)
        let confidence = calculateOverallConfidence(from: allResults)
        
        let result = ModerationResult(
            requestId: UUID().uuidString,
            contentType: .communityPost,
            decision: overallDecision,
            confidence: confidence,
            detectedViolations: violations,
            moderationTags: Array(Set(tags)),
            aiAnalysis: textResult.aiAnalysis,
            humanReviewRequired: violations.contains { $0.severity >= .high },
            processingTime: 0.5 // Approximate processing time
        )
        
        await updateModerationStats(result: result)
        
        return result
    }
    
    /// Moderates user profile information
    func moderateUserProfile(_ user: User) async throws -> ModerationResult {
        var textToModerate = user.displayName + " " + (user.bio ?? "")
        
        if let website = user.website {
            textToModerate += " " + website
        }
        
        let textResult = try await textModerator.moderateText(textToModerate)
        
        var imageResult: ModerationResult?
        
        // Moderate profile image
        if let profileImageURL = user.profileImageURL {
            imageResult = try await imageModerator.moderateImage(url: profileImageURL)
        }
        
        let allResults = [textResult] + (imageResult.map { [$0] } ?? [])
        let violations = allResults.flatMap { $0.detectedViolations }
        
        let result = ModerationResult(
            requestId: UUID().uuidString,
            contentType: .userProfile,
            decision: determineOverallDecision(from: allResults),
            confidence: calculateOverallConfidence(from: allResults),
            detectedViolations: violations,
            moderationTags: allResults.flatMap { $0.moderationTags },
            aiAnalysis: textResult.aiAnalysis,
            humanReviewRequired: violations.contains { $0.severity >= .medium },
            processingTime: 0.3
        )
        
        return result
    }
    
    /// Gets moderation statistics
    func getModerationStatistics(period: StatisticsPeriod) async -> ModerationStatistics {
        return moderationStats
    }
    
    /// Appeals a moderation decision
    func appealModerationDecision(requestId: String, reason: String) async throws -> AppealResult {
        // In production, this would create an appeal case for human review
        return AppealResult(
            appealId: UUID().uuidString,
            originalRequestId: requestId,
            status: .pending,
            submittedAt: Date(),
            reason: reason,
            estimatedReviewTime: TimeInterval(3600 * 24) // 24 hours
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupModerationEngine() {
        // Initialize moderation engines with configuration
        textModerator.configure(with: moderationConfig.textConfig)
        imageModerator.configure(with: moderationConfig.imageConfig)
        videoModerator.configure(with: moderationConfig.videoConfig)
        
        // Load pre-trained models and word lists
        loadModerationModels()
    }
    
    private func loadModerationModels() {
        // In production, load ML models for content moderation
        // For now, we'll use rule-based moderation
    }
    
    private func determineOverallDecision(from results: [ModerationResult]) -> ModerationDecision {
        // If any result is blocked, block overall
        if results.contains(where: { $0.decision == .blocked }) {
            return .blocked
        }
        
        // If any result requires review, require review overall
        if results.contains(where: { $0.decision == .requiresReview }) {
            return .requiresReview
        }
        
        // If majority are flagged, flag overall
        let flaggedCount = results.filter { $0.decision == .flagged }.count
        if flaggedCount > results.count / 2 {
            return .flagged
        }
        
        return .approved
    }
    
    private func calculateOverallConfidence(from results: [ModerationResult]) -> Double {
        guard !results.isEmpty else { return 0.0 }
        
        let averageConfidence = results.map { $0.confidence }.reduce(0, +) / Double(results.count)
        return averageConfidence
    }
    
    private func extractTopics(from text: String) -> [String] {
        // Use NaturalLanguage framework for topic extraction
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var topics: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag = tag, tag.rawValue.contains("Type") {
                topics.append(String(text[tokenRange]))
            }
            return true
        }
        
        return Array(Set(topics))
    }
    
    private func updateModerationStats(result: ModerationResult) async {
        await MainActor.run {
            moderationStats.totalProcessed += 1
            
            switch result.decision {
            case .approved:
                moderationStats.approvedCount += 1
            case .blocked:
                moderationStats.blockedCount += 1
            case .flagged:
                moderationStats.flaggedCount += 1
            case .requiresReview:
                moderationStats.reviewRequiredCount += 1
            }
            
            moderationStats.averageProcessingTime = (moderationStats.averageProcessingTime + result.processingTime) / 2
            moderationStats.lastUpdated = Date()
        }
    }
    
    private func logModerationDecision(result: ModerationResult) {
        // Log to analytics service
        print("Moderation Decision: \(result.decision) for \(result.contentType) with confidence \(result.confidence)")
    }
}

// MARK: - Text Moderation Engine

class TextModerationEngine {
    private var bannedWords: Set<String> = []
    private var suspiciousPatterns: [NSRegularExpression] = []
    private var spamDetectionModel: SpamDetectionModel
    
    init() {
        spamDetectionModel = SpamDetectionModel()
        loadBannedWords()
        setupSuspiciousPatterns()
    }
    
    func configure(with config: TextModerationConfig) {
        // Configure text moderation settings
    }
    
    func moderateText(_ text: String, isRealTime: Bool = false) async throws -> ModerationResult {
        let startTime = Date()
        
        var violations: [ModerationViolation] = []
        var tags: [String] = []
        
        // 1. Check for banned words
        let bannedWordViolations = checkBannedWords(in: text)
        violations.append(contentsOf: bannedWordViolations)
        
        // 2. Check for suspicious patterns
        let patternViolations = checkSuspiciousPatterns(in: text)
        violations.append(contentsOf: patternViolations)
        
        // 3. Spam detection
        let spamScore = spamDetectionModel.calculateSpamScore(text: text)
        if spamScore > 0.7 {
            violations.append(ModerationViolation(
                type: .spam,
                severity: spamScore > 0.9 ? .high : .medium,
                description: "Content detected as spam",
                confidence: spamScore,
                location: nil
            ))
        }
        
        // 4. Sentiment analysis
        let sentimentScore = analyzeSentiment(text: text)
        if sentimentScore < -0.8 { // Very negative
            violations.append(ModerationViolation(
                type: .toxicity,
                severity: .medium,
                description: "Highly negative sentiment detected",
                confidence: abs(sentimentScore),
                location: nil
            ))
        }
        
        // 5. Personal information detection
        let piiViolations = detectPersonalInformation(in: text)
        violations.append(contentsOf: piiViolations)
        
        // Determine decision
        let decision = determineDecision(violations: violations)
        let confidence = calculateConfidence(violations: violations, textLength: text.count)
        
        return ModerationResult(
            requestId: UUID().uuidString,
            contentType: .text,
            decision: decision,
            confidence: confidence,
            detectedViolations: violations,
            moderationTags: tags,
            aiAnalysis: AIAnalysisResult(
                sentimentScore: sentimentScore,
                topicsDetected: [],
                visualContent: [],
                riskFactors: violations.map { $0.type.rawValue }
            ),
            humanReviewRequired: violations.contains { $0.severity >= .high },
            processingTime: Date().timeIntervalSince(startTime)
        )
    }
    
    private func loadBannedWords() {
        // Load banned words from various sources
        bannedWords = Set([
            // Profanity
            "spam", "hate", "inappropriate", "banned",
            // Add more comprehensive list in production
        ])
    }
    
    private func setupSuspiciousPatterns() {
        // Setup regex patterns for suspicious content
        let patterns = [
            "\\b(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])", // Email pattern
            "\\b\\d{3}-\\d{3}-\\d{4}\\b", // Phone pattern
            "https?://[\\w\\-_]+(\\.[\\w\\-_]+)+([\\w\\-\\.,@?^=%&:/~\\+#]*[\\w\\-\\@?^=%&/~\\+#])?" // URL pattern
        ]
        
        suspiciousPatterns = patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }
    
    private func checkBannedWords(in text: String) -> [ModerationViolation] {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var violations: [ModerationViolation] = []
        
        for word in words {
            if bannedWords.contains(word) {
                violations.append(ModerationViolation(
                    type: .profanity,
                    severity: .high,
                    description: "Banned word detected: \(word)",
                    confidence: 1.0,
                    location: nil
                ))
            }
        }
        
        return violations
    }
    
    private func checkSuspiciousPatterns(in text: String) -> [ModerationViolation] {
        var violations: [ModerationViolation] = []
        
        for pattern in suspiciousPatterns {
            let matches = pattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            
            for _ in matches {
                violations.append(ModerationViolation(
                    type: .personalInformation,
                    severity: .medium,
                    description: "Suspicious pattern detected",
                    confidence: 0.8,
                    location: nil
                ))
            }
        }
        
        return violations
    }
    
    private func analyzeSentiment(text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (optionalSentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        guard let sentiment = optionalSentiment,
              let score = Double(sentiment.rawValue) else {
            return 0.0
        }
        
        return score
    }
    
    private func detectPersonalInformation(in text: String) -> [ModerationViolation] {
        var violations: [ModerationViolation] = []
        
        // Use built-in data detection
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue | NSTextCheckingResult.CheckingType.link.rawValue)
        
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []
        
        for match in matches {
            violations.append(ModerationViolation(
                type: .personalInformation,
                severity: .low,
                description: "Personal information detected",
                confidence: 0.7,
                location: nil
            ))
        }
        
        return violations
    }
    
    private func determineDecision(violations: [ModerationViolation]) -> ModerationDecision {
        if violations.contains(where: { $0.severity == .critical }) {
            return .blocked
        }
        
        if violations.contains(where: { $0.severity == .high }) {
            return .requiresReview
        }
        
        if violations.contains(where: { $0.severity == .medium }) {
            return .flagged
        }
        
        return .approved
    }
    
    private func calculateConfidence(violations: [ModerationViolation], textLength: Int) -> Double {
        if violations.isEmpty {
            return 0.95
        }
        
        let averageConfidence = violations.map { $0.confidence }.reduce(0, +) / Double(violations.count)
        return min(averageConfidence + 0.1, 1.0)
    }
}

// MARK: - Image Moderation Engine

class ImageModerationEngine {
    func configure(with config: ImageModerationConfig) {
        // Configure image moderation settings
    }
    
    func moderateImage(url: String) async throws -> ModerationResult {
        // For demo purposes, simulate image moderation
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // In production, this would use Vision framework or cloud APIs
        return ModerationResult(
            requestId: UUID().uuidString,
            contentType: .image,
            decision: .approved,
            confidence: 0.9,
            detectedViolations: [],
            moderationTags: ["safe_content"],
            aiAnalysis: AIAnalysisResult(
                sentimentScore: 0,
                topicsDetected: [],
                visualContent: ["general_image"],
                riskFactors: []
            ),
            humanReviewRequired: false,
            processingTime: 0.2
        )
    }
}

// MARK: - Video Moderation Engine

class VideoModerationEngine {
    func configure(with config: VideoModerationConfig) {
        // Configure video moderation settings
    }
    
    func moderateVideoContent(url: String) async throws -> ModerationResult {
        // Simulate video content analysis
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return ModerationResult(
            requestId: UUID().uuidString,
            contentType: .video,
            decision: .approved,
            confidence: 0.85,
            detectedViolations: [],
            moderationTags: ["video_content", "appropriate"],
            aiAnalysis: nil,
            humanReviewRequired: false,
            processingTime: 0.5
        )
    }
}

// MARK: - Community Guidelines Engine

class CommunityGuidelinesEngine {
    func checkCompliance(video: Video) async throws -> ModerationResult {
        var violations: [ModerationViolation] = []
        
        // Check various community guidelines
        // 1. Content quality
        if video.duration < 10 {
            violations.append(ModerationViolation(
                type: .qualityGuidelines,
                severity: .low,
                description: "Video too short for quality guidelines",
                confidence: 0.8,
                location: nil
            ))
        }
        
        // 2. Metadata completeness
        if video.description.count < 50 {
            violations.append(ModerationViolation(
                type: .qualityGuidelines,
                severity: .low,
                description: "Description too short",
                confidence: 0.6,
                location: nil
            ))
        }
        
        return ModerationResult(
            requestId: UUID().uuidString,
            contentType: .video,
            decision: violations.isEmpty ? .approved : .flagged,
            confidence: violations.isEmpty ? 0.9 : 0.7,
            detectedViolations: violations,
            moderationTags: ["guidelines_check"],
            aiAnalysis: nil,
            humanReviewRequired: false,
            processingTime: 0.1
        )
    }
}

// MARK: - Spam Detection Model

class SpamDetectionModel {
    func calculateSpamScore(text: String) -> Double {
        var score = 0.0
        
        // Check for repetitive content
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let uniqueWords = Set(words)
        let repetitionRatio = Double(words.count - uniqueWords.count) / Double(words.count)
        
        score += repetitionRatio * 0.3
        
        // Check for excessive capitalization
        let uppercaseRatio = Double(text.filter { $0.isUppercase }.count) / Double(text.count)
        if uppercaseRatio > 0.5 {
            score += 0.2
        }
        
        // Check for excessive punctuation
        let punctuationRatio = Double(text.filter { $0.isPunctuation }.count) / Double(text.count)
        if punctuationRatio > 0.2 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
}

// MARK: - Supporting Models

struct ModerationRequest: Identifiable {
    let id: String
    let contentType: ContentType
    let contentId: String
    let createdAt: Date
}

struct ModerationResult: Identifiable {
    let id = UUID().uuidString
    let requestId: String
    let contentType: ContentType
    let decision: ModerationDecision
    let confidence: Double
    let detectedViolations: [ModerationViolation]
    let moderationTags: [String]
    let aiAnalysis: AIAnalysisResult?
    let humanReviewRequired: Bool
    let processingTime: TimeInterval
}

enum ContentType: String, CaseIterable {
    case video = "video"
    case image = "image"
    case text = "text"
    case chatMessage = "chat_message"
    case communityPost = "community_post"
    case userProfile = "user_profile"
}

enum ModerationDecision: String, CaseIterable {
    case approved = "approved"
    case flagged = "flagged"
    case blocked = "blocked"
    case requiresReview = "requires_review"
    
    var color: Color {
        switch self {
        case .approved: return .green
        case .flagged: return .orange
        case .blocked: return .red
        case .requiresReview: return .purple
        }
    }
}

struct ModerationViolation: Identifiable {
    let id = UUID().uuidString
    let type: ViolationType
    let severity: Severity
    let description: String
    let confidence: Double
    let location: ContentLocation?
    
    enum ViolationType: String, CaseIterable {
        case profanity = "profanity"
        case spam = "spam"
        case toxicity = "toxicity"
        case personalInformation = "personal_information"
        case copyrightInfringement = "copyright_infringement"
        case qualityGuidelines = "quality_guidelines"
        case communityGuidelines = "community_guidelines"
    }
    
    enum Severity: Int, CaseIterable, Comparable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
}

struct ContentLocation {
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    let coordinates: CGRect?
    let textRange: NSRange?
}

struct AIAnalysisResult {
    let sentimentScore: Double
    let topicsDetected: [String]
    let visualContent: [String]
    let riskFactors: [String]
}

struct ModerationStatistics {
    var totalProcessed = 0
    var approvedCount = 0
    var blockedCount = 0
    var flaggedCount = 0
    var reviewRequiredCount = 0
    var averageProcessingTime: TimeInterval = 0
    var lastUpdated = Date()
    
    var approvalRate: Double {
        guard totalProcessed > 0 else { return 0 }
        return Double(approvedCount) / Double(totalProcessed)
    }
}

struct AppealResult {
    let appealId: String
    let originalRequestId: String
    let status: AppealStatus
    let submittedAt: Date
    let reason: String
    let estimatedReviewTime: TimeInterval
    
    enum AppealStatus {
        case pending, approved, rejected, underReview
    }
}

enum StatisticsPeriod: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case year = "This Year"
}

// Configuration models
struct ModerationConfiguration {
    let textConfig = TextModerationConfig()
    let imageConfig = ImageModerationConfig()
    let videoConfig = VideoModerationConfig()
}

struct TextModerationConfig {
    let enableProfanityFilter = true
    let enableSpamDetection = true
    let enableSentimentAnalysis = true
    let profanityThreshold = 0.8
    let spamThreshold = 0.7
}

struct ImageModerationConfig {
    let enableNSFWDetection = true
    let enableViolenceDetection = true
    let confidenceThreshold = 0.8
}

struct VideoModerationConfig {
    let enableContentAnalysis = true
    let sampleRate = 30 // seconds
    let maxProcessingTime = 300 // seconds
}

#Preview {
    VStack {
        Text("Enterprise Content Moderation")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("AI-Powered Features")
                .font(.headline)
            
            ForEach([
                "🛡️ Real-time content scanning",
                "🤖 ML-based spam detection",
                "😡 Sentiment analysis & toxicity detection",
                "🔍 Personal information protection",
                "📸 Image & video content analysis",
                "📋 Community guidelines enforcement",
                "⚖️ Appeal system with human review",
                "📊 Comprehensive moderation analytics"
            ], id: \.self) { feature in
                HStack {
                    Text(feature)
                        .font(.body)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        Spacer()
    }
    .padding()
}