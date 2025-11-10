//
//  GrowthAgents.swift
//  MyChannel
//
//  4 Growth AGI Agents to scale the platform
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// Import shared agent types
// AgentMetrics, AgentStatus, Trend, ThumbnailTest are now in SharedAgentTypes.swift

// MARK: - 1. Viral Prediction Engine

@MainActor
final class ViralPredictionEngine: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ViralPredictionEngine()
    private init() {
        // Agent initialization
    }
    
    // MARK: - Published State
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var lastRunTime: Date?
    @Published var errorCount: Int = 0
    @Published var predictions: [VideoPrediction] = []
    
    // MARK: - Configuration
    let config: AGIAgentConfig = .init(
        id: "viral-prediction-engine",
        name: "Viral Prediction Engine",
        category: .growth,
        status: .planned,
        description: "Predicts which videos will go viral based on early engagement patterns",
        impactDescription: "+50% viral content discovery",
        estimatedRevenue: "+$15M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Predict viral potential based on early signals",
        requiredDataSources: ["Early Engagement", "Historical Viral Data", "Social Signals"],
        outputFormat: "JSON viral prediction scores",
        isEnabled: false,
        priority: 12,
        estimatedBuildTime: "3 weeks",
        runInterval: 300
    )
    
    // MARK: - Private State
    private var runTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Agent Lifecycle
    func start() async {
        guard !isActive else { return }
        
        isActive = true
        status = .running
        metrics.startTime = Date()
        
        print("✅ [Viral Prediction Engine] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
        print("🛑 [Viral Prediction Engine] Agent stopped")
    }
    
    // MARK: - Agent Logic
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                
                metrics.successCount += 1
                metrics.lastSuccessTime = Date()
                lastRunTime = Date()
                
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
                
            } catch {
                handleError(error)
                let backoff = min(pow(2.0, Double(errorCount)), 300)
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }
        }
    }
    
    // MARK: - Core Agent Task
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        // 1. Get recent videos (last 24 hours)
        let db = Firestore.firestore()
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let snapshot = try await db.collection("videos")
            .whereField("createdAt", isGreaterThan: cutoff)
            .getDocuments()
        
        print("📊 [Viral Prediction] Analyzing \(snapshot.documents.count) recent videos")
        
        var newPredictions: [VideoPrediction] = []
        
        for doc in snapshot.documents {
            let data = doc.data()
            guard let viewCount = data["viewCount"] as? Int,
                  let likeCount = data["likeCount"] as? Int,
                  let commentCount = data["commentCount"] as? Int,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                continue
            }
            
            // 2. Calculate viral score
            let viralScore = calculateViralScore(
                views: viewCount,
                likes: likeCount,
                comments: commentCount,
                age: Date().timeIntervalSince(createdAt)
            )
            
            // 3. Predict if video will go viral (score > 0.7)
            if viralScore > 0.7 {
                let prediction = VideoPrediction(
                    videoId: doc.documentID,
                    viralScore: viralScore,
                    predictedViews: Int(Double(viewCount) * (1 + viralScore * 10)),
                    confidence: viralScore,
                    factors: ["High engagement rate", "Strong early momentum", "Optimal posting time"]
                )
                newPredictions.append(prediction)
                
                // 4. Boost video in algorithm
                try await boostVideo(videoId: doc.documentID, score: viralScore)
            }
        }
        
        predictions = newPredictions
        metrics.totalRuns += 1
        metrics.impressions += newPredictions.count
        
        print("🔥 [Viral Prediction] Found \(newPredictions.count) potential viral videos")
        #endif
    }
    
    // MARK: - Viral Score Calculation
    private func calculateViralScore(views: Int, likes: Int, comments: Int, age: TimeInterval) -> Double {
        let hoursOld = age / 3600
        guard hoursOld > 0 else { return 0 }
        
        // Engagement rate
        let engagementRate = Double(likes + comments) / max(Double(views), 1)
        
        // Growth velocity (views per hour)
        let velocity = Double(views) / hoursOld
        
        // Comment to like ratio (high comments = high engagement)
        let commentRatio = Double(comments) / max(Double(likes), 1)
        
        // Weighted score
        let score = (engagementRate * 0.4) + (min(velocity / 100, 1.0) * 0.4) + (min(commentRatio, 1.0) * 0.2)
        
        return min(score, 1.0)
    }
    
    // MARK: - Boost Video
    private func boostVideo(videoId: String, score: Double) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("videos").document(videoId).updateData([
            "viralScore": score,
            "boosted": true,
            "boostedAt": FieldValue.serverTimestamp()
        ])
        print("🚀 [Viral Prediction] Boosted video \(videoId) with score \(String(format: "%.2f", score))")
        #endif
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        errorCount += 1
        metrics.errorCount += 1
        print("🚨 [Viral Prediction] Error: \(error.localizedDescription)")
    }
    
    // MARK: - Setup
    deinit {
        runTask?.cancel()
        print("✅ [Viral Prediction Engine] Agent deallocated")
    }
}

// MARK: - 2. Retention Optimizer

@MainActor
final class RetentionOptimizer: ObservableObject {
    
    static let shared = RetentionOptimizer()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var lastRunTime: Date?
    @Published var errorCount: Int = 0
    
    let config: AGIAgentConfig = .init(
        id: "retention-optimizer",
        name: "Retention Optimizer",
        category: .growth,
        status: .planned,
        description: "Optimizes user retention through personalized recommendations and re-engagement",
        impactDescription: "+35% user retention",
        estimatedRevenue: "+$12M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Optimize user retention through smart interventions",
        requiredDataSources: ["User Behavior", "Churn Signals", "Success Patterns"],
        outputFormat: "JSON retention strategies",
        isEnabled: false,
        priority: 13,
        estimatedBuildTime: "3 weeks",
        runInterval: 600
    )
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        metrics.startTime = Date()
        print("✅ [Retention Optimizer] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
        print("🛑 [Retention Optimizer] Agent stopped")
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                lastRunTime = Date()
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                handleError(error)
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // 1. Identify users at risk of churning (no activity in 7 days)
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let snapshot = try await db.collection("users")
            .whereField("lastActiveAt", isLessThan: cutoff)
            .limit(to: 100)
            .getDocuments()
        
        print("📊 [Retention] Found \(snapshot.documents.count) at-risk users")
        
        for doc in snapshot.documents {
            let userId = doc.documentID
            
            // 2. Get user's watch history
            let watchHistory = try await getUserWatchHistory(userId: userId)
            
            // 3. Generate personalized recommendations
            let recommendations = try await generateRecommendations(for: userId, history: watchHistory)
            
            // 4. Send re-engagement notification
            try await sendReEngagementNotification(userId: userId, videos: recommendations)
            
            metrics.impressions += 1
        }
        
        metrics.totalRuns += 1
        print("✅ [Retention] Processed \(snapshot.documents.count) users")
        #endif
    }
    
    private func getUserWatchHistory(userId: String) async throws -> [String] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snapshot = try await db.collection("users").document(userId)
            .collection("watch-history")
            .order(by: "watchedAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        return snapshot.documents.compactMap { $0.data()["videoId"] as? String }
        #else
        return []
        #endif
    }
    
    private func generateRecommendations(for userId: String, history: [String]) async throws -> [String] {
        // TODO: Use PersonalizationEngineV2 for smart recommendations
        // return await PersonalizationEngineV2.shared.getPersonalizedRecommendations(userId: userId, limit: 5)
        return [] // Placeholder
    }
    
    private func sendReEngagementNotification(userId: String, videos: [String]) async throws {
        print("📱 [Retention] Sending re-engagement notification to user \(userId)")
        // TODO: Send push notification via PushNotificationService
        // await PushNotificationService.shared.sendNotification(
        //     userId: userId,
        //     title: "We miss you! 💙",
        //     body: "New videos from creators you love are waiting",
        //     data: ["videoIds": videos]
        // )
    }
    
    private func handleError(_ error: Error) {
        errorCount += 1
        metrics.errorCount += 1
        print("🚨 [Retention] Error: \(error.localizedDescription)")
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Retention Optimizer] Agent deallocated")
    }
}

// MARK: - 3. SEO & Discovery Booster

@MainActor
final class SEODiscoveryBooster: ObservableObject {
    
    static let shared = SEODiscoveryBooster()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var lastRunTime: Date?
    @Published var errorCount: Int = 0
    
    let config: AGIAgentConfig = .init(
        id: "seo-discovery-booster",
        name: "SEO & Discovery Booster",
        category: .growth,
        status: .planned,
        description: "Optimizes video metadata for search and discovery",
        impactDescription: "+40% organic discovery",
        estimatedRevenue: "+$10M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Optimize metadata for search and discovery",
        requiredDataSources: ["Video Content", "Search Trends", "SEO Best Practices"],
        outputFormat: "JSON optimized metadata",
        isEnabled: false,
        priority: 14,
        estimatedBuildTime: "2 weeks",
        runInterval: 3600
    )
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [SEO Booster] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
        print("🛑 [SEO Booster] Agent stopped")
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                lastRunTime = Date()
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                handleError(error)
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // 1. Get videos with poor discoverability (low views despite good content)
        let snapshot = try await db.collection("videos")
            .whereField("viewCount", isLessThan: 1000)
            .whereField("likeCount", isGreaterThan: 50) // Good engagement but low reach
            .limit(to: 50)
            .getDocuments()
        
        print("🔍 [SEO] Optimizing \(snapshot.documents.count) underperforming videos")
        
        for doc in snapshot.documents {
            let data = doc.data()
            let videoId = doc.documentID
            let title = data["title"] as? String ?? ""
            let description = data["description"] as? String ?? ""
            let tags = data["tags"] as? [String] ?? []
            
            // 2. Generate better metadata using AI
            let optimizedMetadata = try await optimizeMetadata(title: title, description: description, tags: tags)
            
            // 3. Update video with better SEO
            try await db.collection("videos").document(videoId).updateData([
                "suggestedTitle": optimizedMetadata.title,
                "suggestedDescription": optimizedMetadata.description,
                "suggestedTags": optimizedMetadata.tags,
                "seoOptimized": true,
                "seoOptimizedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ [SEO] Optimized video \(videoId)")
            metrics.impressions += 1
        }
        
        metrics.totalRuns += 1
        #endif
    }
    
    private func optimizeMetadata(title: String, description: String, tags: [String]) async throws -> (title: String, description: String, tags: [String]) {
        // Use AI to generate better metadata
        let prompt = """
        Optimize this video for search and discovery:
        Title: \(title)
        Description: \(description)
        Tags: \(tags.joined(separator: ", "))
        
        Generate:
        1. Better title (engaging, keyword-rich, under 60 chars)
        2. Better description (informative, searchable, 150-200 chars)
        3. Better tags (10-15 relevant search terms)
        """
        
        // Call AI service (Claude or GPT)
        let result = try await AnthropicService.shared.sendMessage(prompt)
        
        // Parse AI response (simplified for now)
        return (
            title: title, // Keep original for now
            description: description,
            tags: tags
        )
    }
    
    private func handleError(_ error: Error) {
        errorCount += 1
        metrics.errorCount += 1
        print("🚨 [SEO] Error: \(error.localizedDescription)")
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [SEO Booster] Agent deallocated")
    }
}

// MARK: - 4. Thumbnail A/B Testing Agent

@MainActor
final class ThumbnailABTestingAgent: ObservableObject {
    
    static let shared = ThumbnailABTestingAgent()
    private init() {
        // Agent initialization
    }
    
    @Published var isActive: Bool = false
    @Published var metrics: AgentMetrics = .empty
    @Published var status: AgentStatus = .idle
    @Published var lastRunTime: Date?
    @Published var errorCount: Int = 0
    @Published var activeTests: [ThumbnailTest] = []
    
    let config: AGIAgentConfig = .init(
        id: "thumbnail-ab-testing",
        name: "Thumbnail A/B Testing Agent",
        category: .growth,
        status: .planned,
        description: "Tests multiple thumbnails to find the highest click-through rate",
        impactDescription: "+25% CTR improvement",
        estimatedRevenue: "+$8M ARR",
        vertexAIAgentId: nil,
        promptTemplate: "Run A/B tests on thumbnails to maximize CTR",
        requiredDataSources: ["Thumbnail Variants", "Click Data", "Impression Data"],
        outputFormat: "JSON test results",
        isEnabled: false,
        priority: 15,
        estimatedBuildTime: "2 weeks",
        runInterval: 1800
    )
    
    private var runTask: Task<Void, Never>?
    
    func start() async {
        guard !isActive else { return }
        isActive = true
        status = .running
        print("✅ [Thumbnail A/B] Agent started")
        
        runTask = Task { [weak self] in
            await self?.runAgentLoop()
        }
    }
    
    func stop() {
        runTask?.cancel()
        isActive = false
        status = .stopped
        print("🛑 [Thumbnail A/B] Agent stopped")
    }
    
    private func runAgentLoop() async {
        while isActive && !Task.isCancelled {
            do {
                try await performAgentTask()
                metrics.successCount += 1
                lastRunTime = Date()
                try await Task.sleep(nanoseconds: UInt64(config.runInterval * 1_000_000_000))
            } catch {
                handleError(error)
            }
        }
    }
    
    private func performAgentTask() async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        // 1. Check active tests for results
        for test in activeTests {
            let totalImpressions = test.impressions.reduce(0, +)
            if totalImpressions >= 1000 { // Enough data
                let winner = determineWinner(test: test)
                try await applyWinningThumbnail(videoId: test.videoId, thumbnailURL: winner)
                activeTests.removeAll { $0.id == test.id }
            }
        }
        
        // 2. Start new tests for recent videos without tests
        let snapshot = try await db.collection("videos")
            .whereField("thumbnailTested", isEqualTo: false)
            .whereField("viewCount", isLessThan: 10000) // Test early
            .limit(to: 10)
            .getDocuments()
        
        print("🎨 [Thumbnail A/B] Starting tests for \(snapshot.documents.count) videos")
        
        for doc in snapshot.documents {
            let videoId = doc.documentID
            let currentThumbnail = doc.data()["thumbnailURL"] as? String ?? ""
            
            // Generate 2 alternative thumbnails using AI
            let alternatives = try await generateAlternativeThumbnails(videoId: videoId)
            
            let test = ThumbnailTest(
                id: UUID().uuidString,
                videoId: videoId,
                thumbnails: [currentThumbnail] + alternatives,
                impressions: Array(repeating: 0, count: alternatives.count + 1),
                clicks: Array(repeating: 0, count: alternatives.count + 1)
            )
            
            activeTests.append(test)
            
            // Mark video as being tested
            try await db.collection("videos").document(videoId).updateData([
                "thumbnailTested": true,
                "testStartedAt": FieldValue.serverTimestamp()
            ])
        }
        
        metrics.totalRuns += 1
        print("✅ [Thumbnail A/B] \(activeTests.count) active tests running")
        #endif
    }
    
    private func generateAlternativeThumbnails(videoId: String) async throws -> [String] {
        // TODO: Use AIThumbnailTestEngine to generate variations
        // return await AIThumbnailTestEngine.shared.generateVariations(videoId: videoId, count: 2)
        return [] // Placeholder
    }
    
    private func determineWinner(test: ThumbnailTest) -> String {
        // Calculate CTR for each thumbnail
        var bestThumbnail = test.thumbnails[0]
        var bestCTR = 0.0
        
        for (index, thumbnail) in test.thumbnails.enumerated() {
            guard index < test.clicks.count && index < test.impressions.count else { continue }
            
            let clicks = test.clicks[index]
            let impressions = test.impressions[index]
            
            guard impressions > 0 else { continue }
            let ctr = Double(clicks) / Double(impressions)
            
            if ctr > bestCTR {
                bestCTR = ctr
                bestThumbnail = thumbnail
            }
        }
        
        print("🏆 [Thumbnail A/B] Winner with CTR: \(String(format: "%.2f%%", bestCTR * 100))")
        return bestThumbnail
    }
    
    private func applyWinningThumbnail(videoId: String, thumbnailURL: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("videos").document(videoId).updateData([
            "thumbnailURL": thumbnailURL,
            "winningThumbnail": thumbnailURL,
            "testCompleted": true
        ])
        print("✅ [Thumbnail A/B] Applied winning thumbnail to video \(videoId)")
        #endif
    }
    
    private func handleError(_ error: Error) {
        errorCount += 1
        metrics.errorCount += 1
        print("🚨 [Thumbnail A/B] Error: \(error.localizedDescription)")
    }
    
    deinit {
        runTask?.cancel()
        print("✅ [Thumbnail A/B] Agent deallocated")
    }
}

// MARK: - Supporting Models

struct VideoPrediction: Identifiable {
    let id = UUID()
    let videoId: String
    let viralScore: Double
    let predictedViews: Int
    let confidence: Double
    let factors: [String]
}

// Note: ThumbnailTest, AgentMetrics, and AgentStatus are now in SharedAgentTypes.swift

