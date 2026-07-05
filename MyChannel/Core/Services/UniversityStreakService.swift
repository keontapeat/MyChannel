//
//  UniversityStreakService.swift
//  MyChannel
//
//  Real, Firestore-backed learning streak engine for MyChannel University.
//  Duolingo-style daily streaks with freeze/grace handling, longest-streak
//  tracking, milestone rewards, and a 7-day activity calendar.
//
//  Source of truth: `university_users/{userId}` document.
//  This replaces the previously hard-coded streak values in the ViewModel.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - University User Stats (aggregate dashboard model)

/// Aggregate per-user University state. Single source of truth for the
/// dashboard tiles (streak, points, goals) and the leaderboard mirror.
struct UniversityUserStats: Codable, Equatable {
    var userId: String
    var currentStreak: Int
    var longestStreak: Int
    var lastActiveDay: String           // "yyyy-MM-dd" of the last counted learning day
    var totalLearningDays: Int
    var recentActiveDays: [String]      // rolling window (last 30 days) of active "yyyy-MM-dd"
    var streakFreezesAvailable: Int     // protects the streak when a day is missed
    var dailyGoalMinutes: Int
    var todayMinutes: Double            // minutes learned during `lastActiveDay`
    var totalPoints: Int
    var updatedAt: Date

    static func empty(userId: String) -> UniversityUserStats {
        UniversityUserStats(
            userId: userId,
            currentStreak: 0,
            longestStreak: 0,
            lastActiveDay: "",
            totalLearningDays: 0,
            recentActiveDays: [],
            streakFreezesAvailable: 2,
            dailyGoalMinutes: 30,
            todayMinutes: 0,
            totalPoints: 0,
            updatedAt: Date()
        )
    }

    /// The streak that should actually be shown to the user *right now*.
    /// A stored streak only stays "alive" if the last active day was today or
    /// yesterday; otherwise it has lapsed (and will be reset on next activity).
    func displayStreak(calendar: Calendar = .current, now: Date = Date()) -> Int {
        guard !lastActiveDay.isEmpty,
              let last = UniversityStreakService.dayFormatter.date(from: lastActiveDay) else {
            return 0
        }
        let today = calendar.startOfDay(for: now)
        let lastDay = calendar.startOfDay(for: last)
        let dayGap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        // Active today or yesterday → streak is alive. Older → lapsed.
        return dayGap <= 1 ? currentStreak : 0
    }

    /// Whether today's learning goal has been met.
    func goalMetToday(calendar: Calendar = .current, now: Date = Date()) -> Bool {
        let today = UniversityStreakService.dayFormatter.string(from: now)
        guard lastActiveDay == today else { return false }
        return todayMinutes >= Double(dailyGoalMinutes)
    }

    var todayProgressFraction: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        return min(1.0, todayMinutes / Double(dailyGoalMinutes))
    }
}

// MARK: - Service

@MainActor
final class UniversityStreakService: ObservableObject {
    static let shared = UniversityStreakService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    @Published private(set) var stats: UniversityUserStats?

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    // MARK: - Load

    /// Load the user's streak/stats. Creates a starter document the first time.
    @discardableResult
    func loadStats(userId: String) async -> UniversityUserStats {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("university_users").document(userId).getDocument()
            if doc.exists, let data = doc.data() {
                let parsed = parse(data, userId: userId)
                stats = parsed
                return parsed
            }
        } catch {
            print("⚠️ [UniversityStreak] loadStats failed: \(error.localizedDescription)")
        }
        #endif
        // First-time / offline fallback
        let starter = UniversityUserStats.empty(userId: userId)
        stats = starter
        return starter
    }

    // MARK: - Record Activity
    //
    // 🔒 Streak + points are now advanced SERVER-SIDE by the onUniversityWatchEvent
    // Cloud Function (see firebase/functions/src/university.ts) from the raw watch
    // event the client emits via UniversityWatchTrackingService.recordWatchEvent.
    // The client no longer writes streak/points — those fields are locked to the
    // server in firestore.rules — so the leaderboard can't be spoofed. This service
    // now only READS stats for display and writes the user-owned daily goal.

    // MARK: - Goal

    /// Update the user's daily learning-minutes goal. This is a user-owned field
    /// (writable per firestore.rules); streak/points remain server-authoritative.
    func updateDailyGoal(userId: String, minutes: Int) async {
        let clamped = max(5, minutes)
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection("university_users").document(userId).setData([
                "dailyGoalMinutes": clamped,
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        } catch {
            print("⚠️ [UniversityStreak] updateDailyGoal failed: \(error.localizedDescription)")
        }
        #endif
        if var s = stats {
            s.dailyGoalMinutes = clamped
            stats = s
        }
    }

    // MARK: - Leaderboard mirror

    /// Persist the user's public-facing identity + credential counts into their
    /// own `university_users/{userId}` doc. The `onUniversityStatsWritten` Cloud
    /// Function mirrors these — together with the authoritative points/streak in
    /// the same doc — into the public `university_leaderboard/{userId}` entry.
    ///
    /// Clients can no longer write `university_leaderboard` directly (see
    /// firestore.rules), so the public rank doc can't be spoofed on its own.
    func syncLeaderboardEntry(
        userId: String,
        name: String,
        avatarURL: String,
        certificates: Int,
        watchHours: Int
    ) async {
        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "name": name,
            "avatarURL": avatarURL,
            "certificates": certificates,
            "watchHours": watchHours,
            "updatedAt": Timestamp(date: Date())
        ]
        do {
            try await db.collection("university_users").document(userId).setData(data, merge: true)
        } catch {
            print("⚠️ [UniversityStreak] identity sync failed: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Helpers

    #if canImport(FirebaseFirestore)
    private func parse(_ data: [String: Any], userId: String) -> UniversityUserStats {
        UniversityUserStats(
            userId: userId,
            currentStreak: data["currentStreak"] as? Int ?? 0,
            longestStreak: data["longestStreak"] as? Int ?? 0,
            lastActiveDay: data["lastActiveDay"] as? String ?? "",
            totalLearningDays: data["totalLearningDays"] as? Int ?? 0,
            recentActiveDays: data["recentActiveDays"] as? [String] ?? [],
            streakFreezesAvailable: data["streakFreezesAvailable"] as? Int ?? 2,
            dailyGoalMinutes: data["dailyGoalMinutes"] as? Int ?? 30,
            todayMinutes: data["todayMinutes"] as? Double ?? 0,
            totalPoints: data["totalPoints"] as? Int ?? 0,
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        )
    }
    #endif
}
