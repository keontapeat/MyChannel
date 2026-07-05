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

    // 🔥 REAL DATA: streak freeze count + daily goal surfaced to the UI
    @Published var streakFreezesAvailable: Int = 0
    @Published var recentActiveDays: [String] = []
    @Published var earnedBadgeCount: Int = 0
    
    // Services
    private let watchTrackingService = UniversityWatchTrackingService.shared
    private let categorizationService = AICareerCategorizationService.shared
    private let seedDataService = UniversitySeedDataService.shared
    private let streakService = UniversityStreakService.shared
    private let activityService = UniversityActivityService.shared
    
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
        }

        // 🔥 REAL DATA: Load the Firestore-backed streak (replaces hard-coded 15)
        await loadStreakAndAchievements(userId: userId)

        await MainActor.run {
            // Load active goals
            loadActiveGoals()
            
            // Load paths (legacy)
            loadLearningPaths()
            
            // Load subjects
            loadSubjects()
            
            // Load certificates
            loadCertificates()
        }

        // Load real activity feed + leaderboard from Firestore
        await loadActivityAndLeaderboard(userId: userId)
    }

    // MARK: - 🔥 REAL Streak + Achievements

    private func loadStreakAndAchievements(userId: String) async {
        let userStats = await streakService.loadStats(userId: userId)
        let videosCompleted = careerPathsProgress.map { $0.1.videosWatched }.reduce(0, +)

        await MainActor.run {
            let displayStreak = userStats.displayStreak()
            streaksAndGoals = StreaksAndGoals(
                currentStreak: displayStreak,
                longestStreak: userStats.longestStreak,
                activeGoals: streaksAndGoals.activeGoals,
                dailyGoal: streaksAndGoals.dailyGoal,
                todayProgress: userStats.todayMinutes / 60.0,
                todayGoalMet: userStats.goalMetToday()
            )
            streakFreezesAvailable = userStats.streakFreezesAvailable
            recentActiveDays = userStats.recentActiveDays
            totalPoints = userStats.totalPoints

            // Derive badges + milestones from REAL metrics
            let snapshot = UniversityAchievementsEngine.snapshot(
                currentStreak: displayStreak,
                longestStreak: userStats.longestStreak,
                totalHours: totalUniversityHours,
                videosCompleted: videosCompleted,
                certificatesEarned: certificatesEarned,
                totalLearningDays: userStats.totalLearningDays,
                totalPoints: userStats.totalPoints
            )
            badges = snapshot.badges
            milestones = snapshot.milestones
            totalBadges = snapshot.totalBadges
            earnedBadgeCount = snapshot.earnedBadges
            totalAchievements = snapshot.totalAchievements
        }
    }

    private func loadActivityAndLeaderboard(userId: String) async {
        async let activity = activityService.fetchActivity(userId: userId)
        async let learners = activityService.fetchTopLearners()
        async let rank = activityService.fetchGlobalRank(userId: userId, userPoints: totalPoints)

        let (fetchedActivity, fetchedLearners, fetchedRank) = await (activity, learners, rank)

        await MainActor.run {
            if !fetchedActivity.isEmpty { recentActivity = fetchedActivity }
            if !fetchedLearners.isEmpty { topLearners = fetchedLearners }
            globalRank = fetchedRank
        }

        // Keep the public leaderboard mirror in sync with this user's stats.
        if let user = AppState.shared.currentUser {
            await streakService.syncLeaderboardEntry(
                userId: userId,
                name: user.displayName,
                avatarURL: user.profileImageURL ?? "",
                certificates: certificatesEarned,
                watchHours: Int(totalUniversityHours)
            )
        }
    }

    /// Refresh streak/points from the server. Streak advancement itself is now
    /// server-authoritative (the onUniversityWatchEvent Cloud Function updates it
    /// from the emitted watch event); the client only reads it for display.
    func recordLearningSession(minutes: Double) async {
        await checkStreakStatus()
    }
    
    // MARK: - Streak Management (server-authoritative; client reads for display)
    
    func updateStreak(watchDuration: TimeInterval) async {
        await checkStreakStatus()
    }
    
    func checkStreakStatus() async {
        // The streak service computes the live (display) streak on load,
        // automatically lapsing streaks where the last active day is too old.
        guard let userId = AppState.shared.currentUser?.id else { return }
        let stats = await streakService.loadStats(userId: userId)
        await MainActor.run {
            streaksAndGoals.currentStreak = stats.displayStreak()
            streaksAndGoals.longestStreak = stats.longestStreak
            streaksAndGoals.todayProgress = stats.todayMinutes / 60.0
            streaksAndGoals.todayGoalMet = stats.goalMetToday()
            streakFreezesAvailable = stats.streakFreezesAvailable
            totalPoints = stats.totalPoints
        }
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
        // Build certificate cards from REAL career-path progress.
        // Earned = certificate already awarded; In Progress = everything else.
        var earned: [Certificate] = []
        var inProgress: [Certificate] = []

        for (path, prog) in careerPathsProgress {
            let cert = Certificate(
                id: path.id,
                title: "\(path.name) Certificate",
                description: path.description,
                category: subjectCategory(for: path.category),
                color: path.color,
                requiredHours: Int(path.certificateRequirement.minimumHours),
                requiredVideos: path.certificateRequirement.minimumVideos,
                requiredSubjects: path.certificateRequirement.requiredSkills,
                progress: prog.certificateProgress,
                isEarned: prog.certificateEarned,
                earnedDate: prog.certificateEarnedDate,
                verificationHash: nil,
                aiVerificationScore: prog.averageAIScore
            )
            if prog.certificateEarned { earned.append(cert) } else { inProgress.append(cert) }
        }

        // If the user has no tracked paths yet, surface a few popular paths so the
        // "In Progress" tab is never empty.
        if inProgress.isEmpty && earned.isEmpty {
            inProgress = CareerPath.allCareerPaths.prefix(3).map { path in
                Certificate(
                    id: path.id,
                    title: "\(path.name) Certificate",
                    description: path.description,
                    category: subjectCategory(for: path.category),
                    color: path.color,
                    requiredHours: Int(path.certificateRequirement.minimumHours),
                    requiredVideos: path.certificateRequirement.minimumVideos,
                    requiredSubjects: path.certificateRequirement.requiredSkills,
                    progress: 0,
                    isEarned: false,
                    earnedDate: nil,
                    verificationHash: nil,
                    aiVerificationScore: 0
                )
            }
        }

        earnedCertificates = earned.sorted { ($0.earnedDate ?? .distantPast) > ($1.earnedDate ?? .distantPast) }
        availableCertificates = inProgress.sorted { $0.progress > $1.progress }
    }

    private func subjectCategory(for career: CareerCategory) -> SubjectCategory {
        switch career {
        case .business, .marketing: return .business
        case .technology, .engineering: return .technology
        case .creative: return .creative
        case .health: return .health
        case .trades: return .trades
        case .education: return .education
        case .design: return .creative
        case .science: return .science
        case .legal: return .business
        case .hospitality: return .lifestyle
        }
    }
    
    // MARK: - 🔥 NEW: Career Path Methods
    
    private func loadContinueLearningVideos(userId: String) async {
        // 🔥 REAL DATA: derive "Continue Watching" from genuinely in-progress
        // University videos (watchProgress between 5% and 95%). When there is no
        // in-progress content, the card is simply hidden — no fabricated video.
        let realVideos = await UniversityVideoService.shared.fetchUniversityVideos(limit: 40)

        let inProgress = realVideos
            .filter { $0.watchProgress > 0.05 && $0.watchProgress < 0.95 }
            .sorted { ($0.lastWatchedAt ?? .distantPast) > ($1.lastWatchedAt ?? .distantPast) }
            .prefix(5)
            .compactMap { video -> ContinueLearningVideo? in
                guard let pathId = video.careerPaths.first,
                      let path = CareerPath.getCareerPath(byId: pathId) else { return nil }
                let remaining = video.duration * (1.0 - video.watchProgress)
                return ContinueLearningVideo(
                    id: video.id,
                    video: video,
                    careerPathId: path.id,
                    careerPathName: path.name,
                    careerPathColor: path.color,
                    progressPercentage: video.watchProgress,
                    timeRemaining: remaining,
                    lastWatchedAt: video.lastWatchedAt ?? Date()
                )
            }

        await MainActor.run {
            continueLearningVideos = Array(inProgress)
        }
    }
    
    private func loadCareerPathVideos(userId: String) async {
        // 🔥 REAL DATA: pull actual University-eligible videos from Firestore and
        // group them by career path. Falls back to an empty list per path when no
        // real content matches (the UI shows the path with a "coming soon" state)
        // instead of fabricating lessons.
        let realVideos = await UniversityVideoService.shared.fetchUniversityVideos()
        let grouped = UniversityVideoService.shared.groupByCareerPath(realVideos)

        var pathsWithVideos: [(careerPath: CareerPath, progress: CareerPathProgress, videos: [UniversityVideo])] = []
        for (careerPath, progress) in careerPathsProgress {
            let videos = grouped[careerPath.id] ?? []
            // Only include paths that actually have content to show.
            if !videos.isEmpty {
                pathsWithVideos.append((careerPath: careerPath, progress: progress, videos: videos))
            }
        }

        await MainActor.run {
            careerPathsWithVideos = pathsWithVideos
        }
    }
    
    func playVideo(_ continueVideo: ContinueLearningVideo) {
        GlobalVideoPlayerManager.shared.playVideo(continueVideo.video.asVideo, showFullscreen: true)
    }
    
    func playUniversityVideo(_ video: UniversityVideo) {
        // Map UniversityVideo → Video for the player. Watch time is recorded as a
        // university_watch_events doc (AppState.trackUniversityWatch →
        // UniversityWatchTrackingService.recordWatchEvent); the server aggregates
        // progress and issues certificates.
        let playerVideo = video.asVideo
        GlobalVideoPlayerManager.shared.playVideo(playerVideo, showFullscreen: true)
    }
    
    func navigateToCareerPath(_ careerPath: CareerPath, progress: CareerPathProgress) {
        print("🎯 [UniversityVM] Navigate to career path: \(careerPath.name)")
        NotificationCenter.default.post(
            name: Notification.Name("NavigateToCareerPath"),
            object: careerPath
        )
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

