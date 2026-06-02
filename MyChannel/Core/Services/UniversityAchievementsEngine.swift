//
//  UniversityAchievementsEngine.swift
//  MyChannel
//
//  Derives badges and milestones from the user's REAL University data
//  (streak, learning hours, certificates, points). No hard-coded "earned"
//  flags — everything is computed from actual progress so the UI is always
//  consistent with the dashboard tiles.
//

import Foundation
import SwiftUI

struct UniversityAchievementsSnapshot {
    let badges: [Badge]
    let milestones: [Milestone]
    let totalBadges: Int
    let earnedBadges: Int
    let totalAchievements: Int
}

@MainActor
enum UniversityAchievementsEngine {

    /// Build the full badge + milestone set from concrete user metrics.
    static func snapshot(
        currentStreak: Int,
        longestStreak: Int,
        totalHours: Double,
        videosCompleted: Int,
        certificatesEarned: Int,
        totalLearningDays: Int,
        totalPoints: Int
    ) -> UniversityAchievementsSnapshot {

        let badges = buildBadges(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalHours: totalHours,
            videosCompleted: videosCompleted,
            certificatesEarned: certificatesEarned,
            totalLearningDays: totalLearningDays
        )

        let milestones = buildMilestones(
            totalHours: totalHours,
            videosCompleted: videosCompleted,
            certificatesEarned: certificatesEarned,
            longestStreak: longestStreak
        )

        let earned = badges.filter(\.isEarned).count
        let completedMilestones = milestones.filter(\.isCompleted).count

        return UniversityAchievementsSnapshot(
            badges: badges,
            milestones: milestones,
            totalBadges: badges.count,
            earnedBadges: earned,
            totalAchievements: earned + completedMilestones
        )
    }

    // MARK: - Badges

    private static func buildBadges(
        currentStreak: Int,
        longestStreak: Int,
        totalHours: Double,
        videosCompleted: Int,
        certificatesEarned: Int,
        totalLearningDays: Int
    ) -> [Badge] {
        [
            badge(id: "first-steps", title: "First Steps", desc: "Watch your first lesson",
                  icon: "figure.walk", color: .green,
                  requirement: "Complete 1 video", earned: videosCompleted >= 1, points: 25),

            badge(id: "streak-7", title: "On Fire", desc: "Maintain a 7-day streak",
                  icon: "flame.fill", color: .orange,
                  requirement: "7-day streak", earned: longestStreak >= 7, points: 100),

            badge(id: "streak-30", title: "Unstoppable", desc: "Maintain a 30-day streak",
                  icon: "flame.circle.fill", color: .red,
                  requirement: "30-day streak", earned: longestStreak >= 30, points: 400),

            badge(id: "streak-100", title: "Centurion", desc: "Maintain a 100-day streak",
                  icon: "crown.fill", color: UniversityTheme.Colors.certificateGold,
                  requirement: "100-day streak", earned: longestStreak >= 100, points: 2000),

            badge(id: "hours-10", title: "Dedicated", desc: "Log 10 learning hours",
                  icon: "clock.fill", color: .blue,
                  requirement: "10 hours watched", earned: totalHours >= 10, points: 100),

            badge(id: "hours-100", title: "Scholar", desc: "Log 100 learning hours",
                  icon: "book.fill", color: .indigo,
                  requirement: "100 hours watched", earned: totalHours >= 100, points: 500),

            badge(id: "videos-50", title: "Binge Learner", desc: "Complete 50 videos",
                  icon: "play.square.stack.fill", color: .purple,
                  requirement: "50 videos", earned: videosCompleted >= 50, points: 250),

            badge(id: "first-cert", title: "Certified", desc: "Earn your first certificate",
                  icon: "checkmark.seal.fill", color: UniversityTheme.Colors.certificateGold,
                  requirement: "1 certificate", earned: certificatesEarned >= 1, points: 750),

            badge(id: "cert-3", title: "Multi-Disciplinary", desc: "Earn 3 certificates",
                  icon: "rosette", color: UniversityTheme.Colors.certificateGold,
                  requirement: "3 certificates", earned: certificatesEarned >= 3, points: 2000),

            badge(id: "consistency", title: "Consistent", desc: "Learn on 30 different days",
                  icon: "calendar.badge.checkmark", color: .teal,
                  requirement: "30 active days", earned: totalLearningDays >= 30, points: 300),

            badge(id: "month-streak", title: "Monthly Master", desc: "Active streak of 14+ days right now",
                  icon: "bolt.heart.fill", color: .pink,
                  requirement: "14-day active streak", earned: currentStreak >= 14, points: 350),

            badge(id: "marathon", title: "Marathoner", desc: "Log 250 learning hours",
                  icon: "figure.run", color: .mint,
                  requirement: "250 hours watched", earned: totalHours >= 250, points: 1500)
        ]
    }

    private static func badge(id: String, title: String, desc: String, icon: String,
                              color: Color, requirement: String, earned: Bool, points: Int) -> Badge {
        Badge(
            id: id,
            title: title,
            description: desc,
            icon: icon,
            color: color,
            requirement: requirement,
            isEarned: earned,
            earnedDate: earned ? Date() : nil,
            points: points
        )
    }

    // MARK: - Milestones

    private static func buildMilestones(
        totalHours: Double,
        videosCompleted: Int,
        certificatesEarned: Int,
        longestStreak: Int
    ) -> [Milestone] {
        let hours = Int(totalHours)
        return [
            Milestone(
                id: "m-hours-10", title: "First 10 Hours",
                description: "Complete 10 hours of learning",
                requirement: 10, progress: min(hours, 10),
                isCompleted: hours >= 10, points: 100, reward: "Dedicated Badge"
            ),
            Milestone(
                id: "m-videos-50", title: "50 Videos Watched",
                description: "Complete 50 educational videos",
                requirement: 50, progress: min(videosCompleted, 50),
                isCompleted: videosCompleted >= 50, points: 250, reward: "Binge Learner Badge"
            ),
            Milestone(
                id: "m-hours-100", title: "100 Hours Club",
                description: "Complete 100 hours of learning",
                requirement: 100, progress: min(hours, 100),
                isCompleted: hours >= 100, points: 500, reward: "Scholar Badge"
            ),
            Milestone(
                id: "m-first-cert", title: "First Certificate",
                description: "Earn your first verifiable certificate",
                requirement: 1, progress: min(certificatesEarned, 1),
                isCompleted: certificatesEarned >= 1, points: 750, reward: "Certified Badge"
            ),
            Milestone(
                id: "m-streak-30", title: "30-Day Streak",
                description: "Learn every day for a month",
                requirement: 30, progress: min(longestStreak, 30),
                isCompleted: longestStreak >= 30, points: 400, reward: "Unstoppable Badge"
            )
        ]
    }
}
