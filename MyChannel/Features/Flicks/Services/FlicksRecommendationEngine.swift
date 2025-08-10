//
//  FlicksRecommendationEngine.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import SwiftUI
import Foundation

// MARK: - 🤖 AI-Powered Recommendation Engine for Flicks
@MainActor
class FlicksRecommendationEngine: ObservableObject {
    @Published var isLearning = false
    @Published var recommendationAccuracy: Double = 0.85
    @Published var userInterestCategories: [String: Double] = [:]
    
    private var userViewingPatterns: [String: Any] = [:]
    private var sessionData: [String: Any] = [:]
    
    func updateUserPreferences(for video: Video) {
        // Analyze video content and update user preferences
        analyzeVideoEngagement(video)
        updateCategoryInterests(video)
        trackViewingPattern(video)
    }
    
    func getRecommendations(
        based history: [FlicksViewEvent], 
        preferences: FlicksUserPreferences
    ) async -> [Video] {
        isLearning = true
        
        // Simulate AI processing time
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Analyze user behavior patterns
        let behaviorAnalysis = analyzeBehaviorPatterns(history)
        
        // Get content-based recommendations
        let contentRecommendations = getContentBasedRecommendations(preferences)
        
        // Get collaborative filtering recommendations
        let collaborativeRecommendations = getCollaborativeRecommendations(behaviorAnalysis)
        
        // Combine and rank recommendations
        let finalRecommendations = combineRecommendations(
            contentBased: contentRecommendations,
            collaborative: collaborativeRecommendations,
            userHistory: history
        )
        
        isLearning = false
        
        return finalRecommendations
    }
    
    private func analyzeVideoEngagement(_ video: Video) {
        // Track engagement metrics for this video type/category
        let category = video.category.rawValue
        let currentInterest = userInterestCategories[category] ?? 0.5
        
        // Increase interest based on engagement (simplified)
        userInterestCategories[category] = min(1.0, currentInterest + 0.1)
    }
    
    private func updateCategoryInterests(_ video: Video) {
        // Update user's category preferences based on viewed content
        let category = video.category.rawValue
        let currentWeight = userInterestCategories[category] ?? 0.0
        userInterestCategories[category] = min(1.0, currentWeight + 0.05)
        
        // Update creator preferences
        let creatorId = video.creator.id
        let creatorWeight = userInterestCategories["creator_\(creatorId)"] ?? 0.0
        userInterestCategories["creator_\(creatorId)"] = min(1.0, creatorWeight + 0.03)
    }
    
    private func trackViewingPattern(_ video: Video) {
        // Track when user typically watches content
        let hour = Calendar.current.component(.hour, from: Date())
        let timeSlot = "\(hour)h"
        
        var timePreferences = userViewingPatterns["timePreferences"] as? [String: Int] ?? [:]
        timePreferences[timeSlot] = (timePreferences[timeSlot] ?? 0) + 1
        userViewingPatterns["timePreferences"] = timePreferences
        
        // Track video length preferences
        let duration = video.duration
        var durationPreferences = userViewingPatterns["durationPreferences"] as? [String: Int] ?? [:]
        let durationBucket = getDurationBucket(duration)
        durationPreferences[durationBucket] = (durationPreferences[durationBucket] ?? 0) + 1
        userViewingPatterns["durationPreferences"] = durationPreferences
    }
    
    private func getDurationBucket(_ duration: TimeInterval) -> String {
        if duration < 30 {
            return "short" // < 30 seconds
        } else if duration < 120 {
            return "medium" // 30s - 2 minutes
        } else {
            return "long" // > 2 minutes
        }
    }
    
    private func analyzeBehaviorPatterns(_ history: [FlicksViewEvent]) -> [String: Any] {
        var patterns: [String: Any] = [:]
        
        // Analyze engagement patterns
        let totalEvents = history.count
        let likeEvents = history.filter { $0.action == .like }.count
        let shareEvents = history.filter { $0.action == .share }.count
        let commentEvents = history.filter { $0.action == .comment }.count
        
        patterns["engagementRate"] = totalEvents > 0 ? Double(likeEvents + shareEvents + commentEvents) / Double(totalEvents) : 0.0
        patterns["likeRate"] = totalEvents > 0 ? Double(likeEvents) / Double(totalEvents) : 0.0
        patterns["shareRate"] = totalEvents > 0 ? Double(shareEvents) / Double(totalEvents) : 0.0
        
        // Analyze viewing time patterns
        let watchTimeEvents = history.filter { $0.action == .watchTime }
        let averageWatchTime = watchTimeEvents.isEmpty ? 0.0 : 
            watchTimeEvents.map { $0.duration }.reduce(0, +) / Double(watchTimeEvents.count)
        patterns["averageWatchTime"] = averageWatchTime
        
        // Analyze completion patterns
        let completionEvents = history.filter { $0.action == .completion }
        patterns["completionRate"] = totalEvents > 0 ? Double(completionEvents.count) / Double(totalEvents) : 0.0
        
        return patterns
    }
    
    private func getContentBasedRecommendations(_ preferences: FlicksUserPreferences) -> [Video] {
        var recommendations: [Video] = []
        
        // Filter videos based on user's preferred categories
        let preferredCategories = Set(preferences.preferredCategories)
        let categoryFilteredVideos = Video.sampleVideos.filter { video in
            return preferredCategories.contains(video.category.rawValue)
        }
        
        // Add category-based recommendations
        recommendations.append(contentsOf: Array(categoryFilteredVideos.shuffled().prefix(3)))
        
        // Filter videos from preferred creators
        let preferredCreators = Set(preferences.preferredCreators)
        let creatorFilteredVideos = Video.sampleVideos.filter { video in
            return preferredCreators.contains(video.creator.id)
        }
        
        // Add creator-based recommendations
        recommendations.append(contentsOf: Array(creatorFilteredVideos.shuffled().prefix(2)))
        
        // Fill remaining slots with popular content
        let remainingSlots = max(0, 6 - recommendations.count)
        let popularVideos = Video.sampleVideos
            .sorted { $0.viewCount > $1.viewCount }
            .filter { !recommendations.contains($0) }
        
        recommendations.append(contentsOf: Array(popularVideos.prefix(remainingSlots)))
        
        return Array(recommendations.prefix(6))
    }
    
    private func getCollaborativeRecommendations(_ behaviorAnalysis: [String: Any]) -> [Video] {
        // Simulate collaborative filtering based on similar users
        // In real implementation, this would query your recommendation service
        
        let engagementRate = behaviorAnalysis["engagementRate"] as? Double ?? 0.0
        let likeRate = behaviorAnalysis["likeRate"] as? Double ?? 0.0
        
        var recommendations: [Video] = []
        
        if engagementRate > 0.7 {
            // High engagement users - recommend trending content
            let trendingVideos = Video.sampleVideos
                .filter { $0.isSponsored != true }
                .sorted { $0.viewCount > $1.viewCount }
            recommendations.append(contentsOf: Array(trendingVideos.prefix(3)))
        }
        
        if likeRate > 0.5 {
            // Users who like content - recommend similar content
            let similarVideos = Video.sampleVideos
                .filter { $0.likeCount > 1000 }
                .shuffled()
            recommendations.append(contentsOf: Array(similarVideos.prefix(3)))
        }
        
        return Array(recommendations.prefix(6))
    }
    
    private func combineRecommendations(
        contentBased: [Video],
        collaborative: [Video],
        userHistory: [FlicksViewEvent]
    ) -> [Video] {
        var finalRecommendations: [Video] = []
        var usedVideoIds: Set<String> = []
        
        // Get videos user has already seen
        let viewedVideoIds = Set(userHistory.map { $0.videoId })
        
        // Combine recommendations with weighted priority
        // 60% content-based, 40% collaborative
        let contentBasedWeight = 0.6
        let collaborativeWeight = 0.4
        
        let contentCount = Int(Double(6) * contentBasedWeight)
        let collaborativeCount = Int(Double(6) * collaborativeWeight)
        
        // Add content-based recommendations
        for video in contentBased.prefix(contentCount) {
            if !viewedVideoIds.contains(video.id) && !usedVideoIds.contains(video.id) {
                finalRecommendations.append(video)
                usedVideoIds.insert(video.id)
            }
        }
        
        // Add collaborative recommendations
        for video in collaborative.prefix(collaborativeCount) {
            if !viewedVideoIds.contains(video.id) && 
               !usedVideoIds.contains(video.id) && 
               finalRecommendations.count < 6 {
                finalRecommendations.append(video)
                usedVideoIds.insert(video.id)
            }
        }
        
        // Fill remaining slots with fresh content
        if finalRecommendations.count < 6 {
            let freshVideos = Video.sampleVideos
                .filter { !viewedVideoIds.contains($0.id) && !usedVideoIds.contains($0.id) }
                .shuffled()
            
            let remainingSlots = 6 - finalRecommendations.count
            finalRecommendations.append(contentsOf: Array(freshVideos.prefix(remainingSlots)))
        }
        
        // Update recommendation accuracy based on performance
        updateRecommendationAccuracy(finalRecommendations.count)
        
        return finalRecommendations
    }
    
    private func updateRecommendationAccuracy(_ recommendationCount: Int) {
        // Simulate recommendation accuracy improvement over time
        if recommendationCount >= 6 {
            recommendationAccuracy = min(0.95, recommendationAccuracy + 0.01)
        } else {
            recommendationAccuracy = max(0.75, recommendationAccuracy - 0.005)
        }
    }
    
    func getRecommendationInsights() -> [String] {
        var insights: [String] = []
        
        insights.append("Recommendation accuracy: \(String(format: "%.1f", recommendationAccuracy * 100))%")
        
        if let topCategory = userInterestCategories.max(by: { $0.value < $1.value }) {
            insights.append("Top interest: \(topCategory.key.capitalized)")
        }
        
        insights.append("Learning from \(userInterestCategories.count) data points")
        
        return insights
    }
    
    func resetLearning() {
        userInterestCategories.removeAll()
        userViewingPatterns.removeAll()
        sessionData.removeAll()
        recommendationAccuracy = 0.85
    }
}

#Preview {
    @StateObject var recommendationEngine = FlicksRecommendationEngine()
    @State var recommendations: [Video] = []
    @State var isLoading = false
    
    VStack(spacing: 20) {
        Text("AI Recommendation Engine")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        // Engine stats
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("AI Engine Status")
                        .font(.headline)
                    Text(recommendationEngine.isLearning ? "Learning..." : "Ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if recommendationEngine.isLearning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Accuracy indicator
            HStack {
                Text("Accuracy")
                    .font(.caption)
                Spacer()
                Text("\(recommendationEngine.recommendationAccuracy * 100, specifier: "%.1f")%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            ProgressView(value: recommendationEngine.recommendationAccuracy, total: 1.0)
                .tint(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        // Test recommendations
        Button(isLoading ? "Loading..." : "Get Recommendations") {
            isLoading = true
            Task {
                let history: [FlicksViewEvent] = [
                    FlicksViewEvent(videoId: "1", action: .like, timestamp: Date(), duration: 0),
                    FlicksViewEvent(videoId: "2", action: .share, timestamp: Date(), duration: 30),
                    FlicksViewEvent(videoId: "3", action: .watchTime, timestamp: Date(), duration: 45)
                ]
                
                let preferences = FlicksUserPreferences(
                    preferredCategories: ["entertainment", "music"],
                    preferredCreators: ["creator1", "creator2"],
                    avgWatchTime: 35.0,
                    interactionPatterns: ["like": 0.8, "share": 0.3]
                )
                
                recommendations = await recommendationEngine.getRecommendations(
                    based: history,
                    preferences: preferences
                )
                isLoading = false
            }
        }
        .disabled(isLoading)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(12)
        
        // Show recommendations
        if !recommendations.isEmpty {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text("Recommended Videos")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(recommendations) { video in
                        HStack {
                            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.title)
                                    .font(.caption)
                                    .lineLimit(2)
                                
                                Text(video.creator.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
        }
        
        // Insights
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Insights")
                .font(.headline)
            
            ForEach(recommendationEngine.getRecommendationInsights(), id: \.self) { insight in
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text(insight)
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        Spacer()
    }
    .padding()
    .environmentObject(recommendationEngine)
}