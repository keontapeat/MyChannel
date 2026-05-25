//
//  ContentModerationAIReviewService.swift
//  MyChannel
//
//  Content Moderation AI Review - Batch review, AI confidence, performance metrics
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class ContentModerationAIReviewService: ObservableObject {
    static let shared = ContentModerationAIReviewService()
    
    @Published private(set) var pendingReviews: [ModerationReview] = []
    @Published private(set) var completedReviews: [ModerationReview] = []
    @Published private(set) var aiPerformance: AIPerformanceMetrics?
    
    struct ModerationReview: Identifiable, Codable {
        let id: String
        let contentId: String
        let contentType: String
        let aiConfidence: Double
        let aiVerdict: String
        let humanVerdict: String?
        let flaggedAt: Date
        let reviewedAt: Date?
        let reviewedBy: String?
        let isCorrect: Bool?
    }
    
    struct AIPerformanceMetrics: Codable {
        let totalReviewed: Int
        let accuracy: Double
        let precision: Double
        let recall: Double
        let f1Score: Double
        let falsePositiveRate: Double
        let falseNegativeRate: Double
    }
    
    private init() {
        Task { await loadPendingReviews() }
        Task { await loadAIPerformance() }
    }
    
    func loadPendingReviews() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let snapshot = try? await db.collection("moderationReviews")
            .order(by: "flaggedAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        let decoder = ISO8601DateFormatter()
        pendingReviews = snapshot?.documents.compactMap { doc -> ModerationReview? in
            let data = doc.data()
            guard data["humanVerdict"] == nil else { return nil }
            guard let contentId = data["contentId"] as? String,
                  let contentType = data["contentType"] as? String,
                  let aiConfidence = data["aiConfidence"] as? Double,
                  let aiVerdict = data["aiVerdict"] as? String,
                  let flaggedAt = (data["flaggedAt"] as? Timestamp)?.dateValue() else { return nil }
            
            return ModerationReview(
                id: doc.documentID,
                contentId: contentId,
                contentType: contentType,
                aiConfidence: aiConfidence,
                aiVerdict: aiVerdict,
                humanVerdict: data["humanVerdict"] as? String,
                flaggedAt: flaggedAt,
                reviewedAt: (data["reviewedAt"] as? Timestamp)?.dateValue(),
                reviewedBy: data["reviewedBy"] as? String,
                isCorrect: data["isCorrect"] as? Bool
            )
        } ?? []
        #endif
    }
    
    func loadAIPerformance() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        let doc = try? await db.collection("moderationMetrics").document("aiPerformance").getDocument()
        let data = doc?.data()
        
        aiPerformance = data != nil ? AIPerformanceMetrics(
            totalReviewed: data?["totalReviewed"] as? Int ?? 0,
            accuracy: data?["accuracy"] as? Double ?? 0,
            precision: data?["precision"] as? Double ?? 0,
            recall: data?["recall"] as? Double ?? 0,
            f1Score: data?["f1Score"] as? Double ?? 0,
            falsePositiveRate: data?["falsePositiveRate"] as? Double ?? 0,
            falseNegativeRate: data?["falseNegativeRate"] as? Double ?? 0
        ) : nil
        #endif
    }
    
    func batchReview(reviewIds: [String], verdict: String, reviewerId: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let batch = db.batch()
        
        for reviewId in reviewIds {
            let docRef = db.collection("moderationReviews").document(reviewId)
            batch.updateData([
                "humanVerdict": verdict,
                "reviewedAt": FieldValue.serverTimestamp(),
                "reviewedBy": reviewerId
            ], forDocument: docRef)
        }
        
        try await batch.commit()
        await loadPendingReviews()
        await loadAIPerformance()
        #endif
    }
    
    func singleReview(reviewId: String, verdict: String, reviewerId: String, isCorrect: Bool?) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        
        var updates: [String: Any] = [
            "humanVerdict": verdict,
            "reviewedAt": FieldValue.serverTimestamp(),
            "reviewedBy": reviewerId
        ]
        
        if let correct = isCorrect {
            updates["isCorrect"] = correct
        }
        
        try await db.collection("moderationReviews").document(reviewId).updateData(updates)
        await loadPendingReviews()
        await loadAIPerformance()
        #endif
    }
}
