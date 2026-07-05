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
        
        // Create zero-progress starter career paths so the dashboard has paths to
        // show. Real progress is derived exclusively from watch events by the
        // server (onUniversityWatchEvent) and written via the Admin SDK; the
        // client never seeds non-zero progress (locked by firestore.rules).
        try await createStarterCareerPaths(userId: userId)
        
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
        // merge:true so we never clobber streak/points/goal fields that
        // UniversityStreakService writes to the same university_users/{userId} doc.
        try await db.collection("university_users").document(userId).setData([
            "seeded": true,
            "seededAt": Timestamp(date: Date())
        ], merge: true)
        #endif
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

