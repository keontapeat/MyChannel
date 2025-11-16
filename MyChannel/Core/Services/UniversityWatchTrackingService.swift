//
//  UniversityWatchTrackingService.swift
//  MyChannel
//
//  Track watch time per career path and certificate progress
//  Integration with AI verification and real-time tracking
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UniversityWatchTrackingService: ObservableObject {
    static let shared = UniversityWatchTrackingService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    @Published var currentCareerPaths: [String: CareerPathProgress] = [:]
    @Published var totalUniversityHours: Double = 0
    
    // MARK: - Watch Tracking
    
    /// Track a video watch session for University
    func trackVideoWatch(
        userId: String,
        videoId: String,
        title: String,
        duration: TimeInterval,
        watchTime: TimeInterval,
        completionPercentage: Double,
        aiVerificationScore: Int?
    ) async throws {
        print("📊 [University Tracking] Video watched: \(title)")
        print("   Duration: \(Int(watchTime/60))m | Completion: \(Int(completionPercentage*100))%")
        
        // Only track if quality watch (>= 70% completion or >= 70 AI score)
        guard completionPercentage >= 0.7 || (aiVerificationScore ?? 0) >= 70 else {
            print("⚠️ [University Tracking] Low quality watch - not counting toward certificate")
            return
        }
        
        // Categorize video into career paths
        let categorization = try await AICareerCategorizationService.shared.categorizeVideo(
            videoId: videoId,
            title: title,
            description: "", // Will fetch from video model in production
            tags: [],
            category: nil
        )
        
        // Only track if confidence is high enough
        guard categorization.confidence >= 0.7 else {
            print("⚠️ [University Tracking] Low confidence categorization - not tracking")
            return
        }
        
        // Update progress for each career path
        for match in categorization.careerPaths where match.confidence >= 0.7 {
            try await updateCareerPathProgress(
                userId: userId,
                careerPathId: match.careerPathId,
                videoId: videoId,
                watchHours: watchTime / 3600.0,
                aiScore: aiVerificationScore,
                skillTags: categorization.skillTags
            )
        }
        
        // Update total University hours
        totalUniversityHours += watchTime / 3600.0
        
        print("✅ [University Tracking] Updated progress for \(categorization.careerPaths.count) career paths")
    }
    
    /// Update progress for a specific career path
    private func updateCareerPathProgress(
        userId: String,
        careerPathId: String,
        videoId: String,
        watchHours: Double,
        aiScore: Int?,
        skillTags: [String]
    ) async throws {
        #if canImport(FirebaseFirestore)
        let docRef = db.collection("university_progress").document(userId).collection("career_paths").document(careerPathId)
        
        // Get current progress
        let doc = try await docRef.getDocument()
        
        var progress: CareerPathProgress
        
        if doc.exists, let data = doc.data() {
            // Update existing progress
            progress = try parseCareerPathProgress(from: data, careerPathId: careerPathId, userId: userId)
            
            // Add new video if not already tracked
            if !progress.videoIds.contains(videoId) {
                progress.videoIds.append(videoId)
                progress.videosWatched += 1
            }
            
            // Add hours
            progress.totalHours += watchHours
            
            // Update AI score average
            if let aiScore = aiScore {
                let totalScore = Double(progress.averageAIScore * (progress.videosWatched - 1) + aiScore)
                progress.averageAIScore = Int(totalScore / Double(progress.videosWatched))
            }
            
            // Add new skills
            for skill in skillTags {
                progress.skillsCovered.insert(skill)
            }
            
            // Update last watched
            progress.lastWatchedAt = Date()
            
        } else {
            // Create new progress
            progress = CareerPathProgress(
                id: "\(userId)_\(careerPathId)",
                userId: userId,
                careerPathId: careerPathId,
                totalHours: watchHours,
                videosWatched: 1,
                videoIds: [videoId],
                lastWatchedAt: Date(),
                certificateProgress: 0.0,
                certificateEarned: false,
                certificateEarnedDate: nil,
                averageAIScore: aiScore ?? 0,
                skillsCovered: Set(skillTags)
            )
        }
        
        // Calculate certificate progress
        let careerPath = CareerPath.getCareerPath(byId: careerPathId)
        let videoProgress = Double(progress.videosWatched) / Double(careerPath?.certificateRequirement.minimumVideos ?? 300)
        let hoursProgress = progress.totalHours / (careerPath?.certificateRequirement.minimumHours ?? 250)
        progress.certificateProgress = min(1.0, (videoProgress + hoursProgress) / 2.0)
        
        // Check if certificate earned
        if !progress.certificateEarned &&
           progress.videosWatched >= (careerPath?.certificateRequirement.minimumVideos ?? 300) &&
           progress.totalHours >= (careerPath?.certificateRequirement.minimumHours ?? 250) &&
           progress.averageAIScore >= (careerPath?.certificateRequirement.minimumAIScore ?? 70) {
            
            // Award certificate!
            try await awardCertificate(userId: userId, careerPathId: careerPathId, progress: progress)
            
            progress.certificateEarned = true
            progress.certificateEarnedDate = Date()
            progress.certificateProgress = 1.0
        }
        
        // Save to Firestore
        try await docRef.setData(careerPathProgressToDict(progress))
        
        // Update local cache
        currentCareerPaths[careerPathId] = progress
        
        print("💾 [University Tracking] Saved progress for career path: \(careerPathId)")
        print("   Videos: \(progress.videosWatched) | Hours: \(Int(progress.totalHours)) | Progress: \(Int(progress.certificateProgress*100))%")
        
        #endif
    }
    
    // MARK: - Certificate Award
    
    private func awardCertificate(userId: String, careerPathId: String, progress: CareerPathProgress) async throws {
        #if canImport(FirebaseFirestore)
        guard let careerPath = CareerPath.getCareerPath(byId: careerPathId) else { return }
        
        // Get user info
        let userName = AppState.shared.currentUser?.displayName ?? "MyChannel Student"
        
        // Generate certificate
        let certificate = UniversityCertificate(
            id: UUID().uuidString,
            userId: userId,
            userName: userName,
            careerPathId: careerPathId,
            careerPathName: careerPath.name,
            totalHours: progress.totalHours,
            videosCompleted: progress.videosWatched,
            averageAIScore: progress.averageAIScore,
            earnedDate: Date(),
            verificationHash: nil, // Blockchain verification (future)
            certificateNumber: generateCertificateNumber(),
            skillsAcquired: Array(progress.skillsCovered)
        )
        
        // Save certificate
        try await db.collection("university_certificates")
            .document(certificate.id)
            .setData(certificateToDict(certificate))
        
        print("🎓 [University] CERTIFICATE EARNED!")
        print("   Career: \(careerPath.name)")
        print("   Hours: \(Int(progress.totalHours)) | Videos: \(progress.videosWatched)")
        print("   AI Score: \(progress.averageAIScore)/100")
        print("   Certificate Code: \(certificate.certificateCode)")
        
        // Show celebration UI
        HapticManager.shared.notification(type: .success)
        
        // TODO: Show certificate earned modal
        // TODO: Send notification
        // TODO: Post achievement to feed
        
        #endif
    }
    
    private func generateCertificateNumber() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 1000...9999)
        return "\(timestamp)\(random)"
    }
    
    // MARK: - Fetch Progress
    
    func fetchUserProgress(userId: String) async throws -> [CareerPathProgress] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("university_progress")
            .document(userId)
            .collection("career_paths")
            .getDocuments()
        
        var progressList: [CareerPathProgress] = []
        
        for doc in snapshot.documents {
            if let progress = try? parseCareerPathProgress(
                from: doc.data(),
                careerPathId: doc.documentID,
                userId: userId
            ) {
                progressList.append(progress)
            }
        }
        
        // Update local cache
        currentCareerPaths = Dictionary(uniqueKeysWithValues: progressList.map { ($0.careerPathId, $0) })
        
        // Calculate total hours
        totalUniversityHours = progressList.map(\.totalHours).reduce(0, +)
        
        print("✅ [University Tracking] Loaded progress for \(progressList.count) career paths")
        print("   Total University Hours: \(Int(totalUniversityHours))")
        
        return progressList.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
        #else
        return []
        #endif
    }
    
    func fetchCareerPathProgress(userId: String, careerPathId: String) async throws -> CareerPathProgress? {
        #if canImport(FirebaseFirestore)
        let doc = try await db.collection("university_progress")
            .document(userId)
            .collection("career_paths")
            .document(careerPathId)
            .getDocument()
        
        if doc.exists, let data = doc.data() {
            return try parseCareerPathProgress(from: data, careerPathId: careerPathId, userId: userId)
        }
        #endif
        
        return nil
    }
    
    // MARK: - Fetch Certificates
    
    func fetchUserCertificates(userId: String) async throws -> [UniversityCertificate] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("university_certificates")
            .whereField("userId", isEqualTo: userId)
            .order(by: "earnedDate", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? parseCertificate(from: doc.data())
        }
        #else
        return []
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func parseCareerPathProgress(from data: [String: Any], careerPathId: String, userId: String) throws -> CareerPathProgress {
        CareerPathProgress(
            id: data["id"] as? String ?? "\(userId)_\(careerPathId)",
            userId: userId,
            careerPathId: careerPathId,
            totalHours: data["totalHours"] as? Double ?? 0,
            videosWatched: data["videosWatched"] as? Int ?? 0,
            videoIds: data["videoIds"] as? [String] ?? [],
            lastWatchedAt: (data["lastWatchedAt"] as? Timestamp)?.dateValue() ?? Date(),
            certificateProgress: data["certificateProgress"] as? Double ?? 0,
            certificateEarned: data["certificateEarned"] as? Bool ?? false,
            certificateEarnedDate: (data["certificateEarnedDate"] as? Timestamp)?.dateValue(),
            averageAIScore: data["averageAIScore"] as? Int ?? 0,
            skillsCovered: Set(data["skillsCovered"] as? [String] ?? [])
        )
    }
    
    private func careerPathProgressToDict(_ progress: CareerPathProgress) -> [String: Any] {
        var dict: [String: Any] = [
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
        
        if let earnedDate = progress.certificateEarnedDate {
            dict["certificateEarnedDate"] = Timestamp(date: earnedDate)
        }
        
        return dict
    }
    
    private func parseCertificate(from data: [String: Any]) throws -> UniversityCertificate {
        UniversityCertificate(
            id: data["id"] as? String ?? UUID().uuidString,
            userId: data["userId"] as? String ?? "",
            userName: data["userName"] as? String ?? "",
            careerPathId: data["careerPathId"] as? String ?? "",
            careerPathName: data["careerPathName"] as? String ?? "",
            totalHours: data["totalHours"] as? Double ?? 0,
            videosCompleted: data["videosCompleted"] as? Int ?? 0,
            averageAIScore: data["averageAIScore"] as? Int ?? 0,
            earnedDate: (data["earnedDate"] as? Timestamp)?.dateValue() ?? Date(),
            verificationHash: data["verificationHash"] as? String,
            certificateNumber: data["certificateNumber"] as? String ?? "",
            skillsAcquired: data["skillsAcquired"] as? [String] ?? []
        )
    }
    
    private func certificateToDict(_ certificate: UniversityCertificate) -> [String: Any] {
        var dict: [String: Any] = [
            "id": certificate.id,
            "userId": certificate.userId,
            "userName": certificate.userName,
            "careerPathId": certificate.careerPathId,
            "careerPathName": certificate.careerPathName,
            "totalHours": certificate.totalHours,
            "videosCompleted": certificate.videosCompleted,
            "averageAIScore": certificate.averageAIScore,
            "earnedDate": Timestamp(date: certificate.earnedDate),
            "certificateNumber": certificate.certificateNumber,
            "skillsAcquired": certificate.skillsAcquired
        ]
        
        if let hash = certificate.verificationHash {
            dict["verificationHash"] = hash
        }
        
        return dict
    }
}

