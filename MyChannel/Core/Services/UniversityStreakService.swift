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

    /// Points awarded when a streak milestone is reached.
    private let milestoneDays: [Int: Int] = [7: 70, 14: 150, 30: 400, 50: 750, 100: 2000, 365: 10000]

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

    /// Record a learning session. This is what actually moves the streak forward.
    /// Call this whenever the user genuinely watches University content.
    /// - Returns: the updated stats (also published on `self.stats`).
    @discardableResult
    func recordLearningActivity(userId: String, minutes: Double) async -> UniversityUserStats {
        let calendar = Calendar.current
        let now = Date()
        let todayKey = Self.dayFormatter.string(from: now)

        let s0: UniversityUserStats
        if let existing = stats { s0 = existing } else { s0 = await loadStats(userId: userId) }
        var s = s0

        var awardedMilestonePoints = 0

        if s.lastActiveDay == todayKey {
            // Already learned today — just accumulate minutes toward the daily goal.
            s.todayMinutes += minutes
        } else {
            let dayGap = dayGap(from: s.lastActiveDay, to: todayKey, calendar: calendar)

            switch dayGap {
            case 1:
                // Consecutive day → streak grows.
                s.currentStreak += 1
            case let gap where gap > 1:
                // Missed one or more days. Spend a freeze to save a single missed day,
                // otherwise the streak resets.
                if gap == 2 && s.streakFreezesAvailable > 0 {
                    s.streakFreezesAvailable -= 1
                    s.currentStreak += 1
                } else {
                    s.currentStreak = 1
                }
            default:
                // No previous activity (or same-day handled above) → first day.
                s.currentStreak = max(1, s.currentStreak == 0 ? 1 : 1)
            }

            s.lastActiveDay = todayKey
            s.todayMinutes = minutes
            s.totalLearningDays += 1

            // Maintain a rolling 30-day activity window for the calendar UI.
            var recent = s.recentActiveDays
            if !recent.contains(todayKey) { recent.append(todayKey) }
            s.recentActiveDays = Array(recent.suffix(30))

            // Milestone rewards on streak growth.
            if let bonus = milestoneDays[s.currentStreak] {
                awardedMilestonePoints = bonus
            }

            // Earn a freeze every 10-day streak (capped at 5), Duolingo-style.
            if s.currentStreak % 10 == 0 {
                s.streakFreezesAvailable = min(5, s.streakFreezesAvailable + 1)
            }
        }

        s.longestStreak = max(s.longestStreak, s.currentStreak)
        s.totalPoints += awardedMilestonePoints + basePoints(forMinutes: minutes)
        s.updatedAt = now

        stats = s
        await persist(s)

        if awardedMilestonePoints > 0 {
            HapticManager.shared.notification(type: .success)
            await UniversityActivityService.shared.log(
                userId: userId,
                type: .streakMaintained,
                title: "\(s.currentStreak)-day streak! +\(awardedMilestonePoints) points"
            )
            print("🔥 [UniversityStreak] Milestone \(s.currentStreak) days → +\(awardedMilestonePoints) pts")
        }

        return s
    }

    // MARK: - Goal

    func updateDailyGoal(userId: String, minutes: Int) async {
        let s0: UniversityUserStats
        if let existing = stats { s0 = existing } else { s0 = await loadStats(userId: userId) }
        var s = s0
        s.dailyGoalMinutes = max(5, minutes)
        s.updatedAt = Date()
        stats = s
        await persist(s)
    }

    // MARK: - Leaderboard mirror

    /// Mirror the public-facing fields into `university_leaderboard/{userId}` so a
    /// global leaderboard can be queried without exposing the private user doc.
    func syncLeaderboardEntry(
        userId: String,
        name: String,
        avatarURL: String,
        certificates: Int,
        watchHours: Int
    ) async {
        #if canImport(FirebaseFirestore)
        guard let s = stats else { return }
        let data: [String: Any] = [
            "userId": userId,
            "name": name,
            "avatarURL": avatarURL,
            "points": s.totalPoints,
            "certificates": certificates,
            "watchHours": watchHours,
            "currentStreak": s.displayStreak(),
            "longestStreak": s.longestStreak,
            "updatedAt": Timestamp(date: Date())
        ]
        do {
            try await db.collection("university_leaderboard").document(userId).setData(data, merge: true)
        } catch {
            print("⚠️ [UniversityStreak] leaderboard sync failed: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Helpers

    private func basePoints(forMinutes minutes: Double) -> Int {
        // 1 point per minute of genuine learning, capped per session.
        min(120, Int(minutes.rounded()))
    }

    private func dayGap(from: String, to: String, calendar: Calendar) -> Int {
        guard !from.isEmpty,
              let fromDate = Self.dayFormatter.date(from: from),
              let toDate = Self.dayFormatter.date(from: to) else {
            return Int.max // no prior activity
        }
        return calendar.dateComponents([.day],
                                       from: calendar.startOfDay(for: fromDate),
                                       to: calendar.startOfDay(for: toDate)).day ?? Int.max
    }

    private func persist(_ s: UniversityUserStats) async {
        #if canImport(FirebaseFirestore)
        let data: [String: Any] = [
            "userId": s.userId,
            "currentStreak": s.currentStreak,
            "longestStreak": s.longestStreak,
            "lastActiveDay": s.lastActiveDay,
            "totalLearningDays": s.totalLearningDays,
            "recentActiveDays": s.recentActiveDays,
            "streakFreezesAvailable": s.streakFreezesAvailable,
            "dailyGoalMinutes": s.dailyGoalMinutes,
            "todayMinutes": s.todayMinutes,
            "totalPoints": s.totalPoints,
            "updatedAt": Timestamp(date: s.updatedAt),
            // Preserve the seeded flag without clobbering it.
            "seeded": true
        ]
        do {
            try await db.collection("university_users").document(s.userId).setData(data, merge: true)
        } catch {
            print("⚠️ [UniversityStreak] persist failed: \(error.localizedDescription)")
        }
        #endif
    }

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
