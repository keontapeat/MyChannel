//
//  UniversityViewModel.swift
//  MyChannel
//
//  ViewModel for MyChannel University with Streaks & Goals
//  Created for MyChannel by AI Assistant
//

import Foundation
import SwiftUI
import Combine

@MainActor
class UniversityViewModel: ObservableObject {
    // User Progress
    @Published var totalWatchHours: Int = 0
    @Published var certificatesEarned: Int = 0
    @Published var skillLevel: Int = 1
    @Published var subjectsStudied: Int = 0
    @Published var videosCompleted: Int = 0
    @Published var verificationScore: Int = 85
    
    // Streaks & Goals
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var activeGoals: [LearningGoal] = []
    @Published var dailyGoal: LearningGoal?
    @Published var todayProgress: Double = 0
    @Published var todayGoalMet: Bool = false
    
    // Learning Paths
    @Published var activePaths: [LearningPath] = []
    @Published var recommendedPaths: [LearningPath] = []
    
    // Activity
    @Published var recentActivity: [LearningActivity] = []
    
    // Content
    @Published var trendingSubjects: [UniversitySubject] = []
    @Published var allSubjects: [UniversitySubject] = []
    
    // Certificates
    @Published var earnedCertificates: [Certificate] = []
    @Published var availableCertificates: [Certificate] = []
    
    // Achievements
    @Published var totalAchievements: Int = 0
    @Published var totalPoints: Int = 0
    @Published var globalRank: Int = 0
    @Published var badges: [Badge] = []
    @Published var totalBadges: Int = 50
    @Published var milestones: [Milestone] = []
    @Published var topLearners: [Learner] = []
    
    // Search
    @Published var searchQuery: String = ""
    
    // User Profile
    private var userProfile: UserLearningProfile?
    
    func loadUserProgress() async {
        // Load from Firestore
        // For now, mock data
        await MainActor.run {
            totalWatchHours = 142
            certificatesEarned = 3
            skillLevel = 8
            subjectsStudied = 12
            videosCompleted = 87
            verificationScore = 92
            
            // Streaks
            currentStreak = 15
            longestStreak = 23
            todayProgress = 2.5
            todayGoalMet = true
            
            // Load active goals
            loadActiveGoals()
            
            // Load paths
            loadLearningPaths()
            
            // Load activity
            loadRecentActivity()
            
            // Load subjects
            loadSubjects()
            
            // Load certificates
            loadCertificates()
            
            // Load achievements
            loadAchievements()
        }
    }
    
    // MARK: - Streak Management
    
    func updateStreak(watchDuration: TimeInterval) async {
        let hoursWatched = watchDuration / 3600.0
        todayProgress += hoursWatched
        
        // Check if daily goal met
        if let goal = dailyGoal {
            if todayProgress >= goal.targetHours {
                todayGoalMet = true
                await maintainStreak()
            }
        }
        
        // Update Firestore
        await saveStreakProgress()
    }
    
    private func maintainStreak() async {
        currentStreak += 1
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        
        // Award streak milestone rewards
        if currentStreak % 7 == 0 {
            await awardStreakMilestone(days: currentStreak)
        }
        
        HapticManager.shared.notification(type: .success)
    }
    
    func checkStreakStatus() async {
        // Check if streak needs to be reset
        let calendar = Calendar.current
        let today = Date()
        
        // If no activity yesterday, reset streak
        if let lastActivity = recentActivity.first?.timestamp {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if !calendar.isDate(lastActivity, inSameDayAs: today) &&
               !calendar.isDate(lastActivity, inSameDayAs: yesterday) {
                currentStreak = 0
                await saveStreakProgress()
            }
        }
    }
    
    private func awardStreakMilestone(days: Int) async {
        let points = days * 10
        totalPoints += points
        
        // Create milestone activity
        let activity = LearningActivity(
            id: UUID().uuidString,
            type: .streakMaintained,
            title: "\(days)-day streak achieved! +\(points) points",
            subjectId: nil,
            timestamp: Date(),
            duration: 0,
            aiVerified: true
        )
        
        recentActivity.insert(activity, at: 0)
        
        print("🔥 Streak milestone! \(days) days - Earned \(points) points")
    }
    
    private func saveStreakProgress() async {
        // Save to Firestore
        print("💾 Saving streak progress...")
    }
    
    // MARK: - Goal Management
    
    private func loadActiveGoals() {
        // Load from Firestore
        activeGoals = [
            LearningGoal(
                id: "1",
                userId: "user1",
                title: "Master Swift Programming",
                description: "Complete 100 hours of Swift content",
                subjectId: "swift",
                category: .technology,
                targetHours: 100,
                currentHours: 45.5,
                targetDate: Calendar.current.date(byAdding: .month, value: 2, to: Date())!,
                createdDate: Date(),
                isCompleted: false,
                reward: LearningGoal.GoalReward(type: .certificate, value: 100)
            ),
            LearningGoal(
                id: "2",
                userId: "user1",
                title: "Daily Learning",
                description: "Watch 2 hours per day",
                subjectId: nil,
                category: nil,
                targetHours: 2,
                currentHours: todayProgress,
                targetDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                createdDate: Date(),
                isCompleted: todayGoalMet,
                reward: LearningGoal.GoalReward(type: .points, value: 50)
            )
        ]
        
        dailyGoal = activeGoals.first { Calendar.current.isDateInToday($0.targetDate) }
    }
    
    func createGoal(title: String, description: String, subjectId: String?, category: SubjectCategory?, targetHours: Double, targetDate: Date) async {
        let goal = LearningGoal(
            id: UUID().uuidString,
            userId: "currentUser",
            title: title,
            description: description,
            subjectId: subjectId,
            category: category,
            targetHours: targetHours,
            currentHours: 0,
            targetDate: targetDate,
            createdDate: Date(),
            isCompleted: false,
            reward: nil
        )
        
        activeGoals.append(goal)
        
        // Save to Firestore
        print("🎯 Created goal: \(title)")
    }
    
    func updateGoalProgress(goalId: String, additionalHours: Double) async {
        if let index = activeGoals.firstIndex(where: { $0.id == goalId }) {
            activeGoals[index].currentHours += additionalHours
            
            // Check if goal completed
            if activeGoals[index].progress >= 1.0 && !activeGoals[index].isCompleted {
                await completeGoal(goalId: goalId)
            }
        }
    }
    
    private func completeGoal(goalId: String) async {
        guard let index = activeGoals.firstIndex(where: { $0.id == goalId }) else { return }
        
        activeGoals[index].isCompleted = true
        let goal = activeGoals[index]
        
        // Award rewards
        if let reward = goal.reward {
            switch reward.type {
            case .points:
                totalPoints += reward.value
            case .badge, .customBadge:
                // Award badge
                break
            case .certificate:
                // Award certificate
                break
            }
        }
        
        // Create activity
        let activity = LearningActivity(
            id: UUID().uuidString,
            type: .goalAchieved,
            title: "Goal completed: \(goal.title)",
            subjectId: goal.subjectId,
            timestamp: Date(),
            duration: 0,
            aiVerified: true
        )
        
        recentActivity.insert(activity, at: 0)
        
        HapticManager.shared.notification(type: .success)
        print("🎉 Goal completed: \(goal.title)")
    }
    
    // MARK: - AI Verification
    
    func verifyWatchSession(session: WatchSession) async -> AIVerificationResult {
        // Use GPT-5 or Claude to verify the watch session
        let prompt = """
        Analyze this learning session:
        - Video ID: \(session.videoId)
        - Duration: \(session.duration)s
        - Completion: \(session.completionPercentage * 100)%
        - Interaction count: \(session.interactionCount)
        
        Verify if this was a genuine learning session or just background playing.
        Rate the quality from 0-100.
        """
        
        // Call AI service
        let aiScore = Int.random(in: 70...100) // Mock
        
        let result = AIVerificationResult(
            videoId: session.videoId,
            userId: session.userId,
            watchDuration: session.duration,
            completionPercentage: session.completionPercentage,
            contentRelevance: 0.85,
            engagementScore: 0.90,
            knowledgeRetention: 0.80,
            overallScore: aiScore,
            verified: aiScore >= 70,
            verificationTimestamp: Date(),
            aiModel: "GPT-5"
        )
        
        print("✅ AI Verification: \(aiScore)/100 - \(result.verified ? "VERIFIED" : "NOT VERIFIED")")
        
        return result
    }
    
    // MARK: - Data Loading
    
    private func loadLearningPaths() {
        activePaths = [
            LearningPath(
                id: "1",
                title: "iOS Development Mastery",
                description: "Complete path from beginner to advanced iOS developer",
                category: .technology,
                icon: "apple.logo",
                color: .blue,
                videosCount: 45,
                estimatedHours: 80,
                subjects: ["swift", "swiftui", "uikit"],
                progress: 0.35,
                difficulty: .intermediate,
                certificateId: "ios-cert"
            )
        ]
        
        recommendedPaths = [
            LearningPath(
                id: "2",
                title: "Digital Marketing Expert",
                description: "Master SEO, social media, and content marketing",
                category: .business,
                icon: "chart.line.uptrend.xyaxis",
                color: .purple,
                videosCount: 32,
                estimatedHours: 50,
                subjects: ["seo", "social-media", "content"],
                progress: 0,
                difficulty: .beginner,
                certificateId: "marketing-cert"
            )
        ]
    }
    
    private func loadRecentActivity() {
        recentActivity = [
            LearningActivity(
                id: "1",
                type: .videoWatched,
                title: "Completed: Advanced Swift Patterns",
                subjectId: "swift",
                timestamp: Date().addingTimeInterval(-3600),
                duration: 1800,
                aiVerified: true
            ),
            LearningActivity(
                id: "2",
                type: .streakMaintained,
                title: "15-day streak maintained! +150 points",
                subjectId: nil,
                timestamp: Date().addingTimeInterval(-7200),
                duration: 0,
                aiVerified: true
            )
        ]
    }
    
    private func loadSubjects() {
        trendingSubjects = [
            UniversitySubject(
                id: "1",
                title: "Swift Programming",
                description: "Learn Apple's powerful programming language",
                category: .technology,
                icon: "swift",
                color: .orange,
                videosCount: 150,
                learnerCount: 12500,
                totalHours: 200,
                difficulty: .intermediate,
                tags: ["programming", "ios", "apple"]
            ),
            UniversitySubject(
                id: "2",
                title: "Digital Marketing",
                description: "Master online marketing strategies",
                category: .business,
                icon: "megaphone.fill",
                color: .purple,
                videosCount: 120,
                learnerCount: 8900,
                totalHours: 150,
                difficulty: .beginner,
                tags: ["marketing", "seo", "social"]
            )
        ]
        
        allSubjects = trendingSubjects
    }
    
    private func loadCertificates() {
        earnedCertificates = [
            Certificate(
                id: "1",
                title: "Swift Developer",
                description: "Certified Swift Programming Expert",
                category: .technology,
                color: .orange,
                requiredHours: 50,
                requiredVideos: 30,
                requiredSubjects: ["swift"],
                progress: 1.0,
                isEarned: true,
                earnedDate: Date().addingTimeInterval(-86400 * 30),
                verificationHash: "0x1234...",
                aiVerificationScore: 95
            )
        ]
        
        availableCertificates = [
            Certificate(
                id: "2",
                title: "iOS Developer Pro",
                description: "Master iOS Development",
                category: .technology,
                color: .blue,
                requiredHours: 100,
                requiredVideos: 60,
                requiredSubjects: ["swift", "swiftui", "uikit"],
                progress: 0.45,
                isEarned: false,
                earnedDate: nil,
                verificationHash: nil,
                aiVerificationScore: 0
            )
        ]
    }
    
    private func loadAchievements() {
        totalAchievements = 24
        totalPoints = 5670
        globalRank = 1247
        
        badges = [
            Badge(
                id: "1",
                title: "Early Bird",
                description: "Watch before 8 AM",
                icon: "sunrise.fill",
                color: .orange,
                requirement: "Watch 10 videos before 8 AM",
                isEarned: true,
                earnedDate: Date(),
                points: 50
            ),
            Badge(
                id: "2",
                title: "Streak Master",
                description: "7-day streak",
                icon: "flame.fill",
                color: .red,
                requirement: "Maintain 7-day streak",
                isEarned: true,
                earnedDate: Date(),
                points: 100
            )
        ]
        
        milestones = [
            Milestone(
                id: "1",
                title: "First 10 Hours",
                description: "Complete 10 hours of learning",
                requirement: 10,
                progress: 10,
                isCompleted: true,
                points: 100,
                reward: "Early Learner Badge"
            ),
            Milestone(
                id: "2",
                title: "100 Hours Club",
                description: "Complete 100 hours of learning",
                requirement: 100,
                progress: 142,
                isCompleted: true,
                points: 500,
                reward: "Dedicated Learner Badge"
            ),
            Milestone(
                id: "3",
                title: "First Certificate",
                description: "Earn your first certificate",
                requirement: 1,
                progress: 3,
                isCompleted: true,
                points: 200,
                reward: "Certificate Master Badge"
            )
        ]
        
        topLearners = [
            Learner(
                id: "1",
                name: "Alex Chen",
                avatarURL: "",
                rank: 1,
                points: 12450,
                certificates: 15,
                watchHours: 450,
                currentStreak: 45
            ),
            Learner(
                id: "2",
                name: "Sarah Johnson",
                avatarURL: "",
                rank: 2,
                points: 11200,
                certificates: 12,
                watchHours: 420,
                currentStreak: 38
            )
        ]
    }
}

