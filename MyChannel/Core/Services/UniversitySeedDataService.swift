//
//  UniversitySeedDataService.swift
//  MyChannel
//
//  Seed initial University data for new users
//  Creates sample career path progress based on watch history
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UniversitySeedDataService: ObservableObject {
    static let shared = UniversitySeedDataService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    /// Seed initial University data for a new user
    func seedUserData(userId: String) async throws {
        print("🌱 [University Seed] Seeding data for user: \(userId)")
        
        // Check if already seeded
        if await isUserSeeded(userId: userId) {
            print("✅ [University Seed] User already has University data")
            return
        }
        
        // Get user's watch history
        let watchHistory = await fetchUserWatchHistory(userId: userId)
        
        if watchHistory.isEmpty {
            print("📚 [University Seed] No watch history - creating starter career paths")
            try await createStarterCareerPaths(userId: userId)
        } else {
            print("🤖 [University Seed] Analyzing \(watchHistory.count) watched videos with AI")
            try await analyzeAndSeedFromWatchHistory(userId: userId, watchHistory: watchHistory)
        }
        
        // Mark as seeded
        try await markUserAsSeeded(userId: userId)
        
        print("✅ [University Seed] Seeding complete!")
    }
    
    // MARK: - Check if Seeded
    
    private func isUserSeeded(userId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("university_users").document(userId).getDocument()
            return doc.exists && (doc.data()?["seeded"] as? Bool == true)
        } catch {
            return false
        }
        #else
        return false
        #endif
    }
    
    private func markUserAsSeeded(userId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("university_users").document(userId).setData([
            "seeded": true,
            "seededAt": Timestamp(date: Date())
        ])
        #endif
    }
    
    // MARK: - Fetch Watch History
    
    private func fetchUserWatchHistory(userId: String) async -> [(videoId: String, title: String, duration: Double, watchTime: Double)] {
        // Fetch from HistoryService
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection("history")
                .document(userId)
                .collection("items")
                .limit(to: 100)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String else { return nil }
                
                return (
                    videoId: doc.documentID,
                    title: title,
                    duration: data["duration"] as? Double ?? 0,
                    watchTime: data["watchTime"] as? Double ?? 0
                )
            }
        } catch {
            print("⚠️ [University Seed] Failed to fetch watch history: \(error)")
            return []
        }
        #else
        return []
        #endif
    }
    
    // MARK: - Analyze Watch History
    
    private func analyzeAndSeedFromWatchHistory(
        userId: String,
        watchHistory: [(videoId: String, title: String, duration: Double, watchTime: Double)]
    ) async throws {
        // Categorize videos into career paths
        let videosData = watchHistory.map { (videoId: $0.videoId, title: $0.title, description: "", tags: [] as [String], category: nil as String?) }
        
        let categorizations = try await AICareerCategorizationService.shared.categorizeVideos(videosData)
        
        // Group by career path
        var careerPathStats: [String: (videos: Int, hours: Double, totalScore: Int, scoreCount: Int)] = [:]
        
        for (index, categorization) in categorizations.enumerated() {
            for match in categorization.careerPaths where match.confidence >= 0.7 {
                let hours = watchHistory[index].watchTime / 3600.0
                let aiScore = Int(match.confidence * 100)
                
                if var stats = careerPathStats[match.careerPathId] {
                    stats.videos += 1
                    stats.hours += hours
                    stats.totalScore += aiScore
                    stats.scoreCount += 1
                    careerPathStats[match.careerPathId] = stats
                } else {
                    careerPathStats[match.careerPathId] = (videos: 1, hours: hours, totalScore: aiScore, scoreCount: 1)
                }
            }
        }
        
        // Create career path progress for paths with significant watch time
        for (careerPathId, stats) in careerPathStats where stats.hours >= 1.0 {
            let averageScore = stats.totalScore / stats.scoreCount
            
            let progress = CareerPathProgress(
                id: "\(userId)_\(careerPathId)",
                userId: userId,
                careerPathId: careerPathId,
                totalHours: stats.hours,
                videosWatched: stats.videos,
                videoIds: [],
                lastWatchedAt: Date(),
                certificateProgress: min(1.0, (Double(stats.videos) / 300.0 + stats.hours / 250.0) / 2.0),
                certificateEarned: false,
                certificateEarnedDate: nil,
                averageAIScore: averageScore,
                skillsCovered: []
            )
            
            try await saveCareerPathProgress(progress)
            
            print("📈 [University Seed] Created progress for \(careerPathId):")
            print("   Videos: \(stats.videos) | Hours: \(Int(stats.hours)) | AI Score: \(averageScore)")
        }
    }
    
    // MARK: - Create Starter Career Paths
    
    private func createStarterCareerPaths(userId: String) async throws {
        // Create 2-3 popular starter career paths with minimal progress
        let starterPaths = [
            "software-engineering",
            "digital-marketing",
            "ui-ux-design"
        ]
        
        for pathId in starterPaths {
            let progress = CareerPathProgress(
                id: "\(userId)_\(pathId)",
                userId: userId,
                careerPathId: pathId,
                totalHours: 0,
                videosWatched: 0,
                videoIds: [],
                lastWatchedAt: Date(),
                certificateProgress: 0.0,
                certificateEarned: false,
                certificateEarnedDate: nil,
                averageAIScore: 0,
                skillsCovered: []
            )
            
            try await saveCareerPathProgress(progress)
            
            print("🎯 [University Seed] Created starter path: \(pathId)")
        }
    }
    
    // MARK: - Save Progress
    
    private func saveCareerPathProgress(_ progress: CareerPathProgress) async throws {
        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "id": progress.id,
            "userId": progress.userId,
            "careerPathId": progress.careerPathId,
            "totalHours": progress.totalHours,
            "videosWatched": progress.videosWatched,
            "videoIds": progress.videoIds,
            "lastWatchedAt": Timestamp(date: progress.lastWatchedAt),
            "certificateProgress": progress.certificateProgress,
            "certificateEarned": progress.certificateEarned,
            "averageAIScore": progress.averageAIScore,
            "skillsCovered": Array(progress.skillsCovered)
        ]
        
        try await db.collection("university_progress")
            .document(progress.userId)
            .collection("career_paths")
            .document(progress.careerPathId)
            .setData(data)
        #endif
    }
}

