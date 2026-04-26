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
    // 🔥 LOADING STATE: Track loading for shimmer effects
    @Published var isLoading = false
    
    // ⚡ PERFORMANCE: Combine related progress metrics into single state
    @Published var progress: UserProgress = .empty
    
    struct UserProgress {
        var totalWatchHours: Int = 0
        var certificatesEarned: Int = 0
        var skillLevel: Int = 1
        var subjectsStudied: Int = 0
        var videosCompleted: Int = 0
        var verificationScore: Int = 85
        
        static let empty = UserProgress()
    }
    
    // ⚡ PERFORMANCE: Combine streaks & goals into single state
    @Published var streaksAndGoals: StreaksAndGoals = .empty
    
    struct StreaksAndGoals {
        var currentStreak: Int = 0
        var longestStreak: Int = 0
        var activeGoals: [LearningGoal] = []
        var dailyGoal: LearningGoal?
        var todayProgress: Double = 0
        var todayGoalMet: Bool = false
        
        static let empty = StreaksAndGoals()
    }
    
    // 🔥 NEW: Career Paths & Progress
    @Published var totalUniversityHours: Double = 0
    @Published var certificatesEarned: Int = 0
    @Published var activeCareerPathsCount: Int = 0
    @Published var averageAIScore: Int = 0
    @Published var careerPathsProgress: [(CareerPath, CareerPathProgress)] = []
    @Published var continueLearningVideos: [ContinueLearningVideo] = []
    @Published var careerPathsWithVideos: [(careerPath: CareerPath, progress: CareerPathProgress, videos: [UniversityVideo])] = []
    
    // Learning Paths (Legacy - Keep for other tabs)
    @Published var activePaths: [LearningPath] = []
    @Published var recommendedPaths: [LearningPath] = []
    
    // Activity
    @Published var recentActivity: [LearningActivity] = []
    
    // Content
    @Published var trendingSubjects: [UniversitySubject] = []
    @Published var allSubjects: [UniversitySubject] = []
    
    // Certificates (Legacy - Keep for other tabs)
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
    
    // Services
    private let watchTrackingService = UniversityWatchTrackingService.shared
    private let categorizationService = AICareerCategorizationService.shared
    private let seedDataService = UniversitySeedDataService.shared
    
    func loadUserProgress() async {
        isLoading = true
        defer { isLoading = false }
        
        print("🎓 [UniversityVM] Loading user progress...")
        
        // Get current user
        guard let userId = AppState.shared.currentUser?.id else {
            print("⚠️ [UniversityVM] No user logged in")
            return
        }
        
        // 🌱 Seed initial data if first time
        do {
            try await seedDataService.seedUserData(userId: userId)
        } catch {
            print("⚠️ [UniversityVM] Failed to seed data: \(error)")
        }
        
        // 🔥 NEW: Load Career Path Progress with Cache
        do {
            // Try cache first for instant loading
            let cachedProgress = await loadProgressFromCache(userId: userId)
            if !cachedProgress.isEmpty {
                await updateProgressUI(progressList: cachedProgress)
                print("✅ [UniversityVM] Loaded from cache: \(cachedProgress.count) paths")
            }
            
            // Then fetch fresh data
            let progressList = try await watchTrackingService.fetchUserProgress(userId: userId)
            
            // Cache fresh data
            await cacheProgressData(progressList, userId: userId)
            
            // Update UI with fresh data
            await updateProgressUI(progressList: progressList)
            
            print("✅ [UniversityVM] Loaded \(progressList.count) career paths")
            print("   Total Hours: \(Int(totalUniversityHours))")
            print("   Certificates: \(certificatesEarned)")
            print("   Average AI Score: \(averageAIScore)")
            
            // Load Continue Learning Videos
            await loadContinueLearningVideos(userId: userId)
            
            // Load Career Path Videos
            await loadCareerPathVideos(userId: userId)
            
        } catch {
            print("🚨 [UniversityVM] Failed to load progress: \(error)")
        }
        
        // ⚡ PERFORMANCE: Update legacy combined state structures
        await MainActor.run {
            progress = UserProgress(
                totalWatchHours: Int(totalUniversityHours),
                certificatesEarned: certificatesEarned,
                skillLevel: min(10, Int(totalUniversityHours / 50) + 1),
                subjectsStudied: activeCareerPathsCount,
                videosCompleted: careerPathsProgress.map { $0.1.videosWatched }.reduce(0, +),
                verificationScore: averageAIScore
            )
            
            // Streaks (keep existing logic)
            streaksAndGoals = StreaksAndGoals(
                currentStreak: 15,
                longestStreak: 23,
                activeGoals: [],
                dailyGoal: nil,
                todayProgress: 2.5,
                todayGoalMet: true
            )
            
            // Load active goals
            loadActiveGoals()
            
            // Load paths (legacy)
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
        streaksAndGoals.todayProgress += hoursWatched
        
        // Check if daily goal met
        if let goal = streaksAndGoals.dailyGoal {
            if streaksAndGoals.todayProgress >= goal.targetHours {
                streaksAndGoals.todayGoalMet = true
                await maintainStreak()
            }
        }
        
        // Update Firestore
        await saveStreakProgress()
    }
    
    private func maintainStreak() async {
        streaksAndGoals.currentStreak += 1
        if streaksAndGoals.currentStreak > streaksAndGoals.longestStreak {
            streaksAndGoals.longestStreak = streaksAndGoals.currentStreak
        }
        
        // Award streak milestone rewards
        if streaksAndGoals.currentStreak % 7 == 0 {
            await awardStreakMilestone(days: streaksAndGoals.currentStreak)
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
                streaksAndGoals.currentStreak = 0
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
        streaksAndGoals.activeGoals = [
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
                currentHours: streaksAndGoals.todayProgress,
                targetDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                createdDate: Date(),
                isCompleted: streaksAndGoals.todayGoalMet,
                reward: LearningGoal.GoalReward(type: .points, value: 50)
            )
        ]
        
        streaksAndGoals.dailyGoal = streaksAndGoals.activeGoals.first { Calendar.current.isDateInToday($0.targetDate) }
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
        
        streaksAndGoals.activeGoals.append(goal)
        
        // Save to Firestore
        print("🎯 Created goal: \(title)")
    }
    
    func updateGoalProgress(goalId: String, additionalHours: Double) async {
        if let index = streaksAndGoals.activeGoals.firstIndex(where: { $0.id == goalId }) {
            streaksAndGoals.activeGoals[index].currentHours += additionalHours
            
            // Check if goal completed
            if streaksAndGoals.activeGoals[index].progress >= 1.0 && !streaksAndGoals.activeGoals[index].isCompleted {
                await completeGoal(goalId: goalId)
            }
        }
    }
    
    private func completeGoal(goalId: String) async {
        guard let index = streaksAndGoals.activeGoals.firstIndex(where: { $0.id == goalId }) else { return }
        
        streaksAndGoals.activeGoals[index].isCompleted = true
        let goal = streaksAndGoals.activeGoals[index]
        
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
    
    func verifyWatchSession(session: UniversityWatchSession) async -> AIVerificationResult {
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
    
    // MARK: - 🔥 NEW: Career Path Methods
    
    private func loadContinueLearningVideos(userId: String) async {
        // Load incomplete videos from watch history
        // For now, use mock data
        let mockVideos = [
            ContinueLearningVideo(
                id: "1",
                video: UniversityVideo(
                    id: "1",
                    videoId: "vid1",
                    title: "Advanced Swift Patterns: Protocol-Oriented Programming",
                    thumbnailURL: "https://picsum.photos/400/225",
                    duration: 2400,
                    creatorId: "creator1",
                    creatorName: "iOS Academy",
                    creatorAvatarURL: "https://picsum.photos/100/100",
                    careerPaths: ["ios-development"],
                    skillTags: ["Swift", "Protocols"],
                    difficultyLevel: .advanced,
                    isUniversityContent: true,
                    certificateEligible: true,
                    aiCategorizationScore: 0.95,
                    watchProgress: 0.65,
                    lastWatchedAt: Date(),
                    aiVerificationScore: 92,
                    completed: false
                ),
                careerPathId: "ios-development",
                careerPathName: "iOS Development",
                careerPathColor: Color(red: 0.0, green: 0.5, blue: 0.9),
                progressPercentage: 0.65,
                timeRemaining: 840,
                lastWatchedAt: Date().addingTimeInterval(-3600)
            )
        ]
        
        await MainActor.run {
            continueLearningVideos = mockVideos
        }
    }
    
    private func loadCareerPathVideos(userId: String) async {
        // Load videos for each active career path
        // For now, use mock data
        var mockCareerPathVideos: [(careerPath: CareerPath, progress: CareerPathProgress, videos: [UniversityVideo])] = []
        
        for (careerPath, progress) in careerPathsProgress {
            var mockVideos: [UniversityVideo] = []
            
            for index in 0..<10 {
                let globalIndex = index
                let videoId = "vid\(globalIndex)"
                let videoTitle = "\(careerPath.name): Lesson \(globalIndex + 1)"
                let thumbnailURL = "https://picsum.photos/400/\(225 + globalIndex)"
                let duration = TimeInterval(1200 + globalIndex * 300)
                let creatorId = "creator\(globalIndex)"
                let creatorName = "Expert Teacher \(globalIndex + 1)"
                let creatorAvatarURL = "https://picsum.photos/\(100 + globalIndex)/100"
                let careerPathsArray = [careerPath.id]
                let skillTagsArray = Array(careerPath.skillTags.prefix(3))
                let difficultyLevels: [UniversityVideo.DifficultyLevel] = [.beginner, .intermediate, .advanced, .expert]
                let difficultyLevel = difficultyLevels.randomElement() ?? .intermediate
                let aiCategorizationScore = Double.random(in: 0.8...0.99)
                let watchProgress = globalIndex < 3 ? Double.random(in: 0.1...0.7) : 0.0
                let lastWatchedAt = globalIndex < 3 ? Date().addingTimeInterval(-Double(globalIndex) * 3600) : nil
                let aiVerificationScore = Int.random(in: 75...95)
                let completed = globalIndex < 2
                
                let video = UniversityVideo(
                    id: "\(careerPath.id)_\(globalIndex)",
                    videoId: videoId,
                    title: videoTitle,
                    thumbnailURL: thumbnailURL,
                    duration: duration,
                    creatorId: creatorId,
                    creatorName: creatorName,
                    creatorAvatarURL: creatorAvatarURL,
                    careerPaths: careerPathsArray,
                    skillTags: skillTagsArray,
                    difficultyLevel: difficultyLevel,
                    isUniversityContent: true,
                    certificateEligible: true,
                    aiCategorizationScore: aiCategorizationScore,
                    watchProgress: watchProgress,
                    lastWatchedAt: lastWatchedAt,
                    aiVerificationScore: aiVerificationScore,
                    completed: completed
                )
                
                mockVideos.append(video)
            }
            
            mockCareerPathVideos.append((careerPath: careerPath, progress: progress, videos: mockVideos))
        }
        
        await MainActor.run {
            careerPathsWithVideos = mockCareerPathVideos
        }
    }
    
    func playVideo(_ continueVideo: ContinueLearningVideo) {
        print("▶️ [UniversityVM] Playing video: \(continueVideo.video.title)")
        print("   Resuming from: \(Int(continueVideo.progressPercentage * 100))%")
        
        // TODO: Integrate with GlobalVideoPlayerManager
        // GlobalVideoPlayerManager.shared.playVideo(video, startAt: continueVideo.progressPercentage)
    }
    
    func playUniversityVideo(_ video: UniversityVideo) {
        print("▶️ [UniversityVM] Playing University video: \(video.title)")
        
        // TODO: Integrate with GlobalVideoPlayerManager
        // Also track with UniversityWatchTrackingService
    }
    
    func navigateToCareerPath(_ careerPath: CareerPath, progress: CareerPathProgress) {
        print("🎯 [UniversityVM] Navigate to career path: \(careerPath.name)")
        print("   Progress: \(progress.progressPercentage)%")
        
        // TODO: Navigate to CareerPathDetailView
    }
    
    // MARK: - 🔥 CACHING METHODS
    
    private func loadProgressFromCache(userId: String) async -> [CareerPathProgress] {
        // Try to load all career paths progress from cache
        let allCareerPaths = CareerPath.allCareerPaths
        let cachedProgress = allCareerPaths.compactMap { path in
            UniversityCacheService.shared.getCachedProgress(userId: userId, careerPathId: path.id)
        }
        return cachedProgress
    }
    
    private func cacheProgressData(_ progressList: [CareerPathProgress], userId: String) async {
        for progress in progressList {
            UniversityCacheService.shared.cacheProgress(progress)
        }
        print("💾 [UniversityVM] Cached \(progressList.count) progress items")
    }
    
    private func updateProgressUI(progressList: [CareerPathProgress]) async {
        await MainActor.run {
            // Calculate totals
            totalUniversityHours = progressList.map(\.totalHours).reduce(0, +)
            certificatesEarned = progressList.filter(\.certificateEarned).count
            activeCareerPathsCount = progressList.count
            
            // Calculate average AI score
            if !progressList.isEmpty {
                let totalScore = progressList.map(\.averageAIScore).reduce(0, +)
                averageAIScore = totalScore / progressList.count
            } else {
                averageAIScore = 0
            }
            
            // Build career paths progress list
            careerPathsProgress = progressList.compactMap { progress in
                guard let careerPath = CareerPath.getCareerPath(byId: progress.careerPathId) else {
                    return nil
                }
                return (careerPath, progress)
            }
        }
    }
}

