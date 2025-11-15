//
//  UniversityRecommendationEngine.swift
//  MyChannel
//
//  AI-Powered Recommendation Engine for University Videos
//  Suggests next best videos based on learning path, progress, and AI scoring
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 🤖 RECOMMENDATION ENGINE: AI-Powered Next Video Suggestions
/// Analyzes user progress, skill gaps, and career goals to recommend optimal next videos
@MainActor
final class UniversityRecommendationEngine: ObservableObject {
    static let shared = UniversityRecommendationEngine()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    @Published var isGenerating = false
    
    // MARK: - Main Recommendation Methods
    
    /// Get recommended next videos for a specific career path
    /// Takes into account: current progress, skill gaps, difficulty progression
    func getRecommendedVideos(
        userId: String,
        careerPathId: String,
        limit: Int = 10
    ) async throws -> [VideoRecommendation] {
        isGenerating = true
        defer { isGenerating = false }
        
        print("🤖 [Recommendations] Generating recommendations for career path: \(careerPathId)")
        
        // 1. Get user's current progress
        let progress = try await UniversityWatchTrackingService.shared.getCareerPathProgress(
            userId: userId,
            careerPathId: careerPathId
        )
        
        // 2. Get watched video IDs
        let watchedVideoIds = try await getWatchedVideoIds(userId: userId, careerPathId: careerPathId)
        
        // 3. Get available videos for this career path
        let allVideos = try await getCareerPathVideos(careerPathId: careerPathId)
        
        // 4. Filter out already watched
        let unwatchedVideos = allVideos.filter { !watchedVideoIds.contains($0.id) }
        
        // 5. Score each video based on user's current level
        let scoredVideos = scoreVideos(
            unwatchedVideos,
            userProgress: progress,
            watchedVideoIds: watchedVideoIds
        )
        
        // 6. Sort by score and return top N
        let recommendations = scoredVideos
            .sorted { $0.recommendationScore > $1.recommendationScore }
            .prefix(limit)
            .map { VideoRecommendation(video: $0, score: $0.recommendationScore, reason: $0.recommendationReason) }
        
        print("✅ [Recommendations] Generated \(recommendations.count) recommendations")
        
        return Array(recommendations)
    }
    
    /// Get "Continue Learning" recommendations across all career paths
    func getContinueLearningRecommendations(userId: String, limit: Int = 5) async throws -> [VideoRecommendation] {
        print("🤖 [Recommendations] Getting continue learning recommendations...")
        
        // Get all career paths user is active in
        let allProgress = try await UniversityWatchTrackingService.shared.fetchUserProgress(userId: userId)
        
        var allRecommendations: [VideoRecommendation] = []
        
        // Get top recommendation from each active career path
        for (careerPath, progress) in allProgress {
            let recommendations = try await getRecommendedVideos(
                userId: userId,
                careerPathId: careerPath.id,
                limit: 2 // Get top 2 from each path
            )
            allRecommendations.append(contentsOf: recommendations)
        }
        
        // Sort by score and return top N
        return Array(allRecommendations.sorted { $0.score > $1.score }.prefix(limit))
    }
    
    /// Get recommendations for discovering new career paths
    func getCareerPathDiscoveryRecommendations(userId: String) async throws -> [CareerPathRecommendation] {
        print("🤖 [Recommendations] Generating career path discovery recommendations...")
        
        // Get user's current career paths
        let currentProgress = try await UniversityWatchTrackingService.shared.fetchUserProgress(userId: userId)
        let currentPathIds = currentProgress.map { $0.0.id }
        
        // Get all available career paths
        let allPaths = CareerPath.allCareerPaths
        
        // Filter out current paths
        let unexploredPaths = allPaths.filter { !currentPathIds.contains($0.id) }
        
        // Score based on user's existing skills
        var recommendations: [CareerPathRecommendation] = []
        
        for path in unexploredPaths {
            let score = calculateCareerPathRelevanceScore(
                careerPath: path,
                userProgress: currentProgress
            )
            
            let reason = generateCareerPathRecommendationReason(
                careerPath: path,
                userProgress: currentProgress
            )
            
            recommendations.append(CareerPathRecommendation(
                careerPath: path,
                relevanceScore: score,
                reason: reason,
                estimatedTimeToComplete: path.estimatedHours
            ))
        }
        
        // Sort by relevance
        return recommendations.sorted { $0.relevanceScore > $1.relevanceScore }.prefix(5).map { $0 }
    }
    
    // MARK: - Scoring Logic
    
    private func scoreVideos(
        _ videos: [UniversityVideo],
        userProgress: (CareerPath, CareerPathProgress)?,
        watchedVideoIds: Set<String>
    ) -> [ScoredVideo] {
        guard let (_, progress) = userProgress else {
            // No progress yet - recommend beginner videos
            return videos.map { video in
                let score = video.difficultyLevel == .beginner ? 0.9 : 0.5
                return ScoredVideo(
                    video: video,
                    recommendationScore: score,
                    recommendationReason: "Great starting point for beginners"
                )
            }
        }
        
        // Determine user's current skill level
        let userLevel = determineUserSkillLevel(progress: progress)
        
        return videos.map { video in
            var score = 0.0
            var reasons: [String] = []
            
            // 1. Difficulty matching (40% weight)
            let difficultyScore = calculateDifficultyScore(
                videoLevel: video.difficultyLevel,
                userLevel: userLevel
            )
            score += difficultyScore * 0.4
            
            if difficultyScore > 0.8 {
                reasons.append("Perfect difficulty level for you")
            }
            
            // 2. AI Quality Score (30% weight)
            let qualityScore = Double(video.aiVerificationScore) / 100.0
            score += qualityScore * 0.3
            
            if video.aiVerificationScore >= 90 {
                reasons.append("High-quality educational content")
            }
            
            // 3. Certificate Eligibility (20% weight)
            if video.certificateEligible {
                score += 0.2
                reasons.append("Counts towards your certificate")
            }
            
            // 4. Skill Gap Analysis (10% weight)
            // (Simplified for now - would analyze which skills user lacks)
            score += 0.1
            
            let reason = reasons.isEmpty ? "Recommended for your learning path" : reasons.joined(separator: " • ")
            
            return ScoredVideo(
                video: video,
                recommendationScore: min(score, 1.0),
                recommendationReason: reason
            )
        }
    }
    
    private func determineUserSkillLevel(progress: CareerPathProgress) -> UniversityVideo.DifficultyLevel {
        let progressPercent = progress.progressPercentage
        
        if progressPercent < 25 {
            return .beginner
        } else if progressPercent < 50 {
            return .intermediate
        } else if progressPercent < 75 {
            return .advanced
        } else {
            return .expert
        }
    }
    
    private func calculateDifficultyScore(
        videoLevel: UniversityVideo.DifficultyLevel,
        userLevel: UniversityVideo.DifficultyLevel
    ) -> Double {
        let levels: [UniversityVideo.DifficultyLevel] = [.beginner, .intermediate, .advanced, .expert]
        
        guard let videoIndex = levels.firstIndex(of: videoLevel),
              let userIndex = levels.firstIndex(of: userLevel) else {
            return 0.5
        }
        
        let diff = abs(videoIndex - userIndex)
        
        // Perfect match = 1.0, 1 level off = 0.7, 2+ levels off = 0.3
        switch diff {
        case 0: return 1.0
        case 1: return 0.7
        default: return 0.3
        }
    }
    
    private func calculateCareerPathRelevanceScore(
        careerPath: CareerPath,
        userProgress: [(CareerPath, CareerPathProgress)]
    ) -> Double {
        // Calculate based on skill overlap with user's existing paths
        var overlapScore = 0.0
        
        for (existingPath, _) in userProgress {
            let commonSkills = Set(careerPath.skillTags).intersection(Set(existingPath.skillTags))
            let overlapRatio = Double(commonSkills.count) / Double(careerPath.skillTags.count)
            overlapScore = max(overlapScore, overlapRatio)
        }
        
        return overlapScore
    }
    
    private func generateCareerPathRecommendationReason(
        careerPath: CareerPath,
        userProgress: [(CareerPath, CareerPathProgress)]
    ) -> String {
        // Find most related existing path
        var bestOverlap = (path: "", count: 0)
        
        for (existingPath, _) in userProgress {
            let commonSkills = Set(careerPath.skillTags).intersection(Set(existingPath.skillTags))
            if commonSkills.count > bestOverlap.count {
                bestOverlap = (existingPath.name, commonSkills.count)
            }
        }
        
        if bestOverlap.count > 0 {
            return "Builds on your \(bestOverlap.path) skills"
        } else {
            return "Expand your expertise into a new field"
        }
    }
    
    // MARK: - Data Fetching
    
    private func getWatchedVideoIds(userId: String, careerPathId: String) async throws -> Set<String> {
        // TODO: Fetch from Firestore watch history
        // For now, return empty set
        return Set()
    }
    
    private func getCareerPathVideos(careerPathId: String) async throws -> [UniversityVideo] {
        // TODO: Fetch from Firestore videos collection filtered by careerPathId
        // For now, return mock data
        return []
    }
}

// MARK: - Models

/// Video with recommendation score and reason
struct VideoRecommendation: Identifiable {
    let id = UUID()
    let video: UniversityVideo
    let score: Double  // 0-1
    let reason: String
}

/// Career path recommendation for discovery
struct CareerPathRecommendation: Identifiable {
    let id = UUID()
    let careerPath: CareerPath
    let relevanceScore: Double  // 0-1
    let reason: String
    let estimatedTimeToComplete: Int  // Hours
}

/// Internal: Video with scoring data
private struct ScoredVideo {
    let video: UniversityVideo
    let recommendationScore: Double
    let recommendationReason: String
    
    var id: String { video.id }
}

