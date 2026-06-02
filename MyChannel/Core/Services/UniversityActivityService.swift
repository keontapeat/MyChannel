//
//  UniversityActivityService.swift
//  MyChannel
//
//  Persists and fetches the user's University activity feed and the global
//  learner leaderboard from Firestore. Replaces the previously mocked
//  `recentActivity`, `topLearners`, and badge/milestone data.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class UniversityActivityService: ObservableObject {
    static let shared = UniversityActivityService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    // MARK: - Activity Feed

    /// Append an activity entry to `university_users/{userId}/activity`.
    func log(userId: String, type: LearningActivity.ActivityType, title: String, subjectId: String? = nil, duration: TimeInterval = 0) async {
        #if canImport(FirebaseFirestore)
        let id = UUID().uuidString
        var data: [String: Any] = [
            "id": id,
            "type": type.rawValue,
            "title": title,
            "timestamp": Timestamp(date: Date()),
            "duration": duration,
            "aiVerified": true
        ]
        if let subjectId { data["subjectId"] = subjectId }
        do {
            try await db.collection("university_users").document(userId)
                .collection("activity").document(id).setData(data)
        } catch {
            print("⚠️ [UniversityActivity] log failed: \(error.localizedDescription)")
        }
        #endif
    }

    /// Fetch the most recent activity entries for the user.
    func fetchActivity(userId: String, limit: Int = 25) async -> [LearningActivity] {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection("university_users").document(userId)
                .collection("activity")
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.compactMap { parseActivity($0.data()) }
        } catch {
            print("⚠️ [UniversityActivity] fetchActivity failed: \(error.localizedDescription)")
        }
        #endif
        return []
    }

    // MARK: - Global Leaderboard

    /// Fetch the top learners from `university_leaderboard`, ranked by points.
    func fetchTopLearners(limit: Int = 50) async -> [Learner] {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection("university_leaderboard")
                .order(by: "points", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snapshot.documents.enumerated().map { index, doc in
                let d = doc.data()
                return Learner(
                    id: doc.documentID,
                    name: d["name"] as? String ?? "Learner",
                    avatarURL: d["avatarURL"] as? String ?? "",
                    rank: index + 1,
                    points: d["points"] as? Int ?? 0,
                    certificates: d["certificates"] as? Int ?? 0,
                    watchHours: d["watchHours"] as? Int ?? 0,
                    currentStreak: d["currentStreak"] as? Int ?? 0
                )
            }
        } catch {
            print("⚠️ [UniversityActivity] fetchTopLearners failed: \(error.localizedDescription)")
        }
        #endif
        return []
    }

    /// Compute the user's global rank by counting how many learners have more points.
    /// Returns 0 when the user has no points yet (treated as "unranked").
    func fetchGlobalRank(userId: String, userPoints: Int) async -> Int {
        guard userPoints > 0 else { return 0 }
        #if canImport(FirebaseFirestore)
        do {
            let countQuery = db.collection("university_leaderboard")
                .whereField("points", isGreaterThan: userPoints)
                .count
            let snapshot = try await countQuery.getAggregation(source: .server)
            return snapshot.count.intValue + 1
        } catch {
            print("⚠️ [UniversityActivity] fetchGlobalRank failed: \(error.localizedDescription)")
        }
        #endif
        return 0
    }

    // MARK: - Parsing

    #if canImport(FirebaseFirestore)
    private func parseActivity(_ data: [String: Any]) -> LearningActivity? {
        guard let id = data["id"] as? String,
              let typeRaw = data["type"] as? String,
              let type = LearningActivity.ActivityType(rawValue: typeRaw),
              let title = data["title"] as? String else {
            return nil
        }
        return LearningActivity(
            id: id,
            type: type,
            title: title,
            subjectId: data["subjectId"] as? String,
            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
            duration: data["duration"] as? TimeInterval ?? 0,
            aiVerified: data["aiVerified"] as? Bool ?? true
        )
    }
    #endif
}
