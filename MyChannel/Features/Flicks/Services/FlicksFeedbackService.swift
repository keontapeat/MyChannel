//
//  FlicksFeedbackService.swift
//  MyChannel
//
//  Persists user feedback (reports, "not interested") to Firestore so the
//  recommendation engine can tune the feed and moderation can review content.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class FlicksFeedbackService: ObservableObject {
    static let shared = FlicksFeedbackService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    enum ReportReason: String, CaseIterable, Identifiable {
        case spam = "Spam or misleading"
        case sexualContent = "Sexual content"
        case violence = "Violent or repulsive"
        case hatefulOrAbusive = "Hateful or abusive"
        case harmfulActs = "Harmful or dangerous acts"
        case misinformation = "Misinformation"
        case childSafety = "Child safety"
        case other = "Other"

        var id: String { rawValue }
    }

    /// Files a content report against a flick.
    func report(flickId: String, reason: ReportReason, details: String? = nil) async {
        #if canImport(FirebaseFirestore)
        let userId = AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id ?? "anonymous"
        do {
            try await db.collection("flickReports").document().setData([
                "flickId": flickId,
                "userId": userId,
                "reason": reason.rawValue,
                "details": details as Any?,
                "status": "pending",
                "createdAt": FieldValue.serverTimestamp(),
                "platform": "iOS"
            ].compactMapValues { $0 })

            // Increment a per-flick report counter for fast moderation triage.
            try await db.collection("flicks").document(flickId).setData([
                "reportCount": FieldValue.increment(Int64(1))
            ], merge: true)
            print("🚨 [FlicksFeedback] Reported \(flickId) for \(reason.rawValue)")
        } catch {
            print("⚠️ [FlicksFeedback] Failed to file report: \(error)")
        }
        #endif
    }

    /// Records a "not interested" signal used to down-rank similar content.
    func notInterested(flickId: String, creatorId: String?, tags: [String]) async {
        #if canImport(FirebaseFirestore)
        guard let userId = AuthenticationManager.shared.currentUser?.id ?? AppState.shared.currentUser?.id else { return }
        do {
            try await db.collection("users").document(userId)
                .collection("feedSignals").document()
                .setData([
                    "type": "not_interested",
                    "flickId": flickId,
                    "creatorId": creatorId as Any?,
                    "tags": tags,
                    "createdAt": FieldValue.serverTimestamp()
                ].compactMapValues { $0 })
            print("👎 [FlicksFeedback] Recorded not-interested for \(flickId)")
        } catch {
            print("⚠️ [FlicksFeedback] Failed to record not-interested: \(error)")
        }
        #endif
    }
}
