//
//  ThumbnailABTestService.swift
//  MyChannel
//
//  Created by AI Assistant on 10/19/25.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Thumbnail A/B Testing Service (YouTube Parity)
@MainActor
class ThumbnailABTestService: ObservableObject {
    static let shared = ThumbnailABTestService()
    
    @Published var activeTests: [ABThumbnailTest] = []
    @Published var completedTests: [ABThumbnailTest] = []
    @Published var testResults: [ThumbnailTestResult] = []
    @Published var isCreatingTest = false
    
    private let networkService = NetworkService.shared
    private let analyticsService = AdvancedAnalyticsService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupTestMonitoring()
    }
    
    // MARK: - Test Creation
    
    /// Create A/B test for video thumbnails
    func createThumbnailTest(
        videoId: String,
        thumbnailVariants: [ThumbnailVariant],
        testDuration: TimeInterval = 7 * 24 * 3600, // 7 days default
        trafficSplit: [Double] = [0.5, 0.5], // Equal split default
        successMetric: TestSuccessMetric = .clickThroughRate
    ) async throws -> ABThumbnailTest {
        
        guard thumbnailVariants.count >= 2 else {
            throw ThumbnailTestError.insufficientVariants
        }
        
        guard trafficSplit.count == thumbnailVariants.count else {
            throw ThumbnailTestError.invalidTrafficSplit
        }
        
        guard abs(trafficSplit.reduce(0, +) - 1.0) < 0.001 else {
            throw ThumbnailTestError.invalidTrafficSplit
        }
        
        isCreatingTest = true
        defer { isCreatingTest = false }
        
        let test = ABThumbnailTest(
            id: UUID().uuidString,
            videoId: videoId,
            variants: thumbnailVariants,
            trafficSplit: trafficSplit,
            successMetric: successMetric,
            status: .active,
            startDate: Date(),
            endDate: Date().addingTimeInterval(testDuration),
            createdAt: Date()
        )
        
        // Save test to backend
        try await networkService.post(
            endpoint: .custom("/thumbnail-tests"),
            body: test,
            responseType: ABThumbnailTest.self
        )
        
        // Start serving variants
        await startServingVariants(test: test)
        
        // Add to active tests
        activeTests.append(test)
        
        return test
    }
    
    /// End thumbnail test early
    func endTest(_ testId: String, reason: TestEndReason = .manual) async throws {
        guard let testIndex = activeTests.firstIndex(where: { $0.id == testId }) else {
            throw ThumbnailTestError.testNotFound
        }
        
        var test = activeTests[testIndex]
        test.status = .completed
        test.endDate = Date()
        test.endReason = reason
        
        // Calculate final results
        let finalResults = try await calculateTestResults(test: test)
        test.results = finalResults
        
        // Update backend
        try await networkService.put(
            endpoint: .custom("/thumbnail-tests/\(testId)"),
            body: test,
            responseType: ABThumbnailTest.self
        )
        
        // Move to completed tests
        activeTests.remove(at: testIndex)
        completedTests.append(test)
        
        // Apply winning variant
        if let winner = finalResults.winningVariant {
            await applyWinningThumbnail(videoId: test.videoId, variant: winner)
        }
    }
    
    // MARK: - Test Analytics
    
    /// Get real-time test performance
    func getTestPerformance(_ testId: String) async throws -> ThumbnailTestPerformance {
        return try await networkService.get(
            endpoint: .custom("/thumbnail-tests/\(testId)/performance"),
            responseType: ThumbnailTestPerformance.self
        )
    }
    
    /// Get detailed test results
    func getTestResults(_ testId: String) async throws -> ThumbnailTestResult {
        guard let test = activeTests.first(where: { $0.id == testId }) ??
                         completedTests.first(where: { $0.id == testId }) else {
            throw ThumbnailTestError.testNotFound
        }
        
        return try await calculateTestResults(test: test)
    }
    
    /// Get test recommendations
    func getTestRecommendations(videoId: String) async throws -> [ThumbnailRecommendation] {
        return try await networkService.get(
            endpoint: .custom("/videos/\(videoId)/thumbnail-recommendations"),
            responseType: [ThumbnailRecommendation].self
        )
    }
    
    // MARK: - Variant Serving
    
    /// Get thumbnail variant for user
    func getThumbnailVariant(videoId: String, userId: String?) -> String? {
        guard let test = activeTests.first(where: { $0.videoId == videoId && $0.status == .active }) else {
            return nil
        }
        
        // Determine which variant to serve based on user ID and traffic split
        let variantIndex = determineVariantIndex(userId: userId, trafficSplit: test.trafficSplit)
        return test.variants[variantIndex].thumbnailURL
    }
    
    /// Track thumbnail impression
    func trackThumbnailImpression(
        videoId: String,
        variantId: String,
        userId: String?,
        context: ImpressionContext
    ) async {
        let impression = ThumbnailImpression(
            id: UUID().uuidString,
            videoId: videoId,
            variantId: variantId,
            userId: userId,
            context: context,
            timestamp: Date()
        )
        
        // Send to analytics
        try? await networkService.post(
            endpoint: .custom("/thumbnail-impressions"),
            body: impression,
            responseType: EmptyResponse.self
        )
    }
    
    /// Track thumbnail click
    func trackThumbnailClick(
        videoId: String,
        variantId: String,
        userId: String?,
        context: ImpressionContext
    ) async {
        let click = ThumbnailClick(
            id: UUID().uuidString,
            videoId: videoId,
            variantId: variantId,
            userId: userId,
            context: context,
            timestamp: Date()
        )
        
        // Send to analytics
        try? await networkService.post(
            endpoint: .custom("/thumbnail-clicks"),
            body: click,
            responseType: EmptyResponse.self
        )
    }
    
    // MARK: - Private Methods
    
    private func setupTestMonitoring() {
        // Monitor active tests for completion
        Timer.publish(every: 3600, on: .main, in: .common) // Check hourly
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkTestCompletion()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkTestCompletion() async {
        let now = Date()
        
        for test in activeTests where test.endDate <= now {
            try? await endTest(test.id, reason: .timeExpired)
        }
    }
    
    private func startServingVariants(test: ABThumbnailTest) async {
        // Configure CDN to serve different thumbnail variants
        let requestBody: [String: Any] = [
            "videoId": test.videoId,
            "variants": test.variants.map { variant in
                [
                    "id": variant.id,
                    "name": variant.name,
                    "thumbnailURL": variant.thumbnailURL,
                    "description": variant.description ?? ""
                ]
            },
            "trafficSplit": test.trafficSplit
        ]
        
        // Convert to JSON data
        let jsonData = try? JSONSerialization.data(withJSONObject: requestBody)
        
        try? await networkService.post(
            endpoint: .custom("/cdn/configure-variants"),
            body: jsonData ?? Data(),
            responseType: EmptyResponse.self
        )
    }
    
    private func calculateTestResults(test: ABThumbnailTest) async throws -> ThumbnailTestResult {
        // Get performance data for each variant
        var variantResults: [VariantResult] = []
        
        for (index, variant) in test.variants.enumerated() {
            let performance = try await getVariantPerformance(
                videoId: test.videoId,
                variantId: variant.id,
                startDate: test.startDate,
                endDate: test.endDate
            )
            
            let result = VariantResult(
                variant: variant,
                impressions: performance.impressions,
                clicks: performance.clicks,
                clickThroughRate: performance.clickThroughRate,
                averageViewDuration: performance.averageViewDuration,
                conversionRate: performance.conversionRate,
                confidenceInterval: calculateConfidenceInterval(performance)
            )
            
            variantResults.append(result)
        }
        
        // Determine statistical significance and winner
        let significance = calculateStatisticalSignificance(results: variantResults)
        let winner = determineWinner(results: variantResults, significance: significance)
        
        return ThumbnailTestResult(
            testId: test.id,
            variantResults: variantResults,
            winningVariant: winner,
            statisticalSignificance: significance,
            confidenceLevel: 0.95,
            testDuration: test.endDate.timeIntervalSince(test.startDate),
            totalImpressions: variantResults.reduce(0) { $0 + $1.impressions },
            totalClicks: variantResults.reduce(0) { $0 + $1.clicks }
        )
    }
    
    private func getVariantPerformance(
        videoId: String,
        variantId: String,
        startDate: Date,
        endDate: Date
    ) async throws -> VariantPerformance {
        // Build URL with query parameters manually
        let baseURL = "/thumbnail-tests/performance"
        let queryParams = [
            "videoId=\(videoId)",
            "variantId=\(variantId)",
            "startDate=\(ISO8601DateFormatter().string(from: startDate))",
            "endDate=\(ISO8601DateFormatter().string(from: endDate))"
        ].joined(separator: "&")
        
        let fullURL = "\(baseURL)?\(queryParams)"
        
        return try await networkService.get(
            endpoint: .custom(fullURL),
            responseType: VariantPerformance.self
        )
    }
    
    private func determineVariantIndex(userId: String?, trafficSplit: [Double]) -> Int {
        // Use consistent hashing to determine variant
        let hash = userId?.hash ?? Int.random(in: 0...Int.max)
        let normalizedHash = Double(abs(hash)) / Double(Int.max)
        
        var cumulativeWeight = 0.0
        for (index, weight) in trafficSplit.enumerated() {
            cumulativeWeight += weight
            if normalizedHash <= cumulativeWeight {
                return index
            }
        }
        
        return trafficSplit.count - 1 // Fallback to last variant
    }
    
    private func calculateConfidenceInterval(_ performance: VariantPerformance) -> ThumbnailConfidenceInterval {
        // Calculate 95% confidence interval for CTR
        let p = performance.clickThroughRate
        let n = Double(performance.impressions)
        let z = 1.96 // 95% confidence level
        
        let margin = z * sqrt((p * (1 - p)) / n)
        
        return ThumbnailConfidenceInterval(
            lower: max(0, p - margin),
            upper: min(1, p + margin)
        )
    }
    
    private func calculateStatisticalSignificance(results: [VariantResult]) -> Double {
        // Simplified chi-square test for statistical significance
        // In production, use proper statistical testing libraries
        guard results.count == 2 else { return 0.0 }
        
        let result1 = results[0]
        let result2 = results[1]
        
        // Calculate chi-square statistic
        let totalImpressions = result1.impressions + result2.impressions
        let totalClicks = result1.clicks + result2.clicks
        
        let expectedClicks1 = Double(result1.impressions * totalClicks) / Double(totalImpressions)
        let expectedClicks2 = Double(result2.impressions * totalClicks) / Double(totalImpressions)
        
        let chiSquare = pow(Double(result1.clicks) - expectedClicks1, 2) / expectedClicks1 +
                       pow(Double(result2.clicks) - expectedClicks2, 2) / expectedClicks2
        
        // Convert to p-value (simplified)
        return max(0, min(1, 1 - (chiSquare / 10))) // Simplified conversion
    }
    
    private func determineWinner(results: [VariantResult], significance: Double) -> ThumbnailVariant? {
        guard significance < 0.05 else { return nil } // Not statistically significant
        
        return results.max { $0.clickThroughRate < $1.clickThroughRate }?.variant
    }
    
    private func applyWinningThumbnail(videoId: String, variant: ThumbnailVariant) async {
        // Update video to use winning thumbnail permanently
        try? await networkService.put(
            endpoint: .custom("/videos/\(videoId)/thumbnail"),
            body: ["thumbnailURL": variant.thumbnailURL],
            responseType: EmptyResponse.self
        )
    }
}

// MARK: - Models

// Note: Renamed to avoid conflict with SharedAgentTypes.ThumbnailTest
struct ABThumbnailTest: Identifiable, Codable {
    let id: String
    let videoId: String
    let variants: [ThumbnailVariant]
    let trafficSplit: [Double]
    let successMetric: TestSuccessMetric
    var status: TestStatus
    let startDate: Date
    var endDate: Date
    let createdAt: Date
    var endReason: TestEndReason?
    var results: ThumbnailTestResult?
}

struct ThumbnailVariant: Identifiable, Codable {
    let id: String
    let name: String
    let thumbnailURL: String
    let description: String?
}

enum TestSuccessMetric: String, Codable, CaseIterable {
    case clickThroughRate = "ctr"
    case viewDuration = "view_duration"
    case engagement = "engagement"
    case retention = "retention"
    
    var displayName: String {
        switch self {
        case .clickThroughRate: return "Click-Through Rate"
        case .viewDuration: return "Average View Duration"
        case .engagement: return "Engagement Rate"
        case .retention: return "Audience Retention"
        }
    }
}

enum TestStatus: String, Codable {
    case draft, active, paused, completed, cancelled
}

enum TestEndReason: String, Codable {
    case timeExpired, manual, statisticalSignificance, insufficientData
}

struct ThumbnailTestResult: Codable {
    let testId: String
    let variantResults: [VariantResult]
    let winningVariant: ThumbnailVariant?
    let statisticalSignificance: Double
    let confidenceLevel: Double
    let testDuration: TimeInterval
    let totalImpressions: Int
    let totalClicks: Int
}

struct VariantResult: Codable {
    let variant: ThumbnailVariant
    let impressions: Int
    let clicks: Int
    let clickThroughRate: Double
    let averageViewDuration: TimeInterval
    let conversionRate: Double
    let confidenceInterval: ThumbnailConfidenceInterval
}

struct ThumbnailConfidenceInterval: Codable {
    let lower: Double
    let upper: Double
}

struct VariantPerformance: Codable {
    let impressions: Int
    let clicks: Int
    let clickThroughRate: Double
    let averageViewDuration: TimeInterval
    let conversionRate: Double
}

struct ThumbnailTestPerformance: Codable {
    let testId: String
    let isActive: Bool
    let timeRemaining: TimeInterval
    let variantPerformances: [VariantPerformance]
    let currentLeader: String?
    let statisticalSignificance: Double
}

struct ThumbnailRecommendation: Identifiable, Codable {
    let id: String
    let type: RecommendationType
    let title: String
    let description: String
    let expectedImprovement: Double
    let confidence: Double
}

enum RecommendationType: String, Codable {
    case colorScheme, composition, textOverlay, faceExpression, contrast
}

struct ThumbnailImpression: Codable {
    let id: String
    let videoId: String
    let variantId: String
    let userId: String?
    let context: ImpressionContext
    let timestamp: Date
}

struct ThumbnailClick: Codable {
    let id: String
    let videoId: String
    let variantId: String
    let userId: String?
    let context: ImpressionContext
    let timestamp: Date
}

struct ImpressionContext: Codable {
    let page: String // home, search, suggested, etc.
    let position: Int
    let deviceType: String
    let platform: String
}

enum ThumbnailTestError: Error {
    case insufficientVariants
    case invalidTrafficSplit
    case testNotFound
    case testAlreadyActive
    case insufficientData
}
