//
//  UniversityHomeView.swift
//  MyChannel
//
//  MyChannel University - AI-Verified Learning & Certificates
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct UniversityHomeView: View {
    @StateObject private var viewModel = UniversityViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: UniversityTab = .dashboard
    
    enum UniversityTab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case learn = "Learn"
        case certificates = "Certificates"
        case achievements = "Achievements"
        
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .learn: return "book.fill"
            case .certificates: return "medal.fill"
            case .achievements: return "trophy.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab Selector
                    tabSelector
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            switch selectedTab {
                            case .dashboard:
                                dashboardContent
                            case .learn:
                                learnContent
                            case .certificates:
                                certificatesContent
                            case .achievements:
                                achievementsContent
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("MyChannel University")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            Task {
                await viewModel.loadUserProgress()
            }
        }
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(UniversityTab.allCases) { tab in
                    TabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Dashboard Content
    private var dashboardContent: some View {
        VStack(spacing: 24) {
            // Hero Card
            universityHeroCard
            
            // Learning Stats
            learningStatsCard
            
            // Active Learning Paths
            if !viewModel.activePaths.isEmpty {
                activeLearningPaths
            }
            
            // Recent Activity
            recentActivitySection
            
            // Trending Subjects
            trendingSubjects
        }
    }
    
    private var universityHeroCard: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.4, blue: 0.9),
                            Color(red: 0.1, green: 0.2, blue: 0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 28, weight: .bold))
                    Text("MyChannel University")
                        .font(.system(size: 26, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("AI-Verified Learning Platform")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                HStack(spacing: 16) {
                    statBadge(icon: "clock.fill", value: "\(viewModel.progress.totalWatchHours)h", label: "Watched")
                    statBadge(icon: "medal.fill", value: "\(viewModel.progress.certificatesEarned)", label: "Certificates")
                    statBadge(icon: "chart.line.uptrend.xyaxis", value: "\(viewModel.progress.skillLevel)", label: "Level")
                }
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(value)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var learningStatsCard: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Learning Journey")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Keep learning to unlock certificates")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Progress Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                progressCard(
                    title: "Watch Time",
                    value: "\(viewModel.progress.totalWatchHours)",
                    suffix: "hours",
                    icon: "play.circle.fill",
                    color: .blue,
                    progress: Double(viewModel.progress.totalWatchHours) / 1000.0
                )
                
                progressCard(
                    title: "Subjects Studied",
                    value: "\(viewModel.progress.subjectsStudied)",
                    suffix: "topics",
                    icon: "books.vertical.fill",
                    color: .purple,
                    progress: Double(viewModel.progress.subjectsStudied) / 50.0
                )
                
                progressCard(
                    title: "Videos Completed",
                    value: "\(viewModel.progress.videosCompleted)",
                    suffix: "videos",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    progress: Double(viewModel.progress.videosCompleted) / 500.0
                )
                
                progressCard(
                    title: "AI Verification",
                    value: "\(viewModel.progress.verificationScore)",
                    suffix: "%",
                    icon: "checkmark.shield.fill",
                    color: .orange,
                    progress: Double(viewModel.progress.verificationScore) / 100.0
                )
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func progressCard(title: String, value: String, suffix: String, icon: String, color: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(suffix)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * min(progress, 1.0), height: 6)
                        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var activeLearningPaths: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Active Learning Paths")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: AllLearningPathsView()) {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ForEach(viewModel.activePaths) { path in
                NavigationLink(destination: LearningPathDetailView(path: path)) {
                    LearningPathCard(path: path)
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(viewModel.recentActivity) { activity in
                    ActivityCard(activity: activity)
                }
            }
        }
    }
    
    private var trendingSubjects: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Trending Subjects")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.trendingSubjects) { subject in
                        NavigationLink(destination: SubjectDetailView(subject: subject)) {
                            TrendingSubjectCard(subject: subject)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Learn Content
    private var learnContent: some View {
        VStack(spacing: 24) {
            // Search Bar
            searchBar
            
            // Browse by Category
            browseCategoriesSection
            
            // Recommended Paths
            recommendedPathsSection
            
            // All Subjects
            allSubjectsGrid
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            TextField("Search subjects, skills, topics...", text: $viewModel.searchQuery)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var browseCategoriesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Browse by Category")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(SubjectCategory.allCases) { category in
                    NavigationLink(destination: CategorySubjectsView(category: category)) {
                        CategoryCard(category: category)
                    }
                }
            }
        }
    }
    
    private var recommendedPathsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recommended for You")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)
                
                Spacer()
            }
            
            ForEach(viewModel.recommendedPaths) { path in
                NavigationLink(destination: LearningPathDetailView(path: path)) {
                    RecommendedPathCard(path: path)
                }
            }
        }
    }
    
    private var allSubjectsGrid: some View {
        VStack(spacing: 16) {
            HStack {
                Text("All Subjects")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.allSubjects.count) subjects")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.allSubjects) { subject in
                    NavigationLink(destination: SubjectDetailView(subject: subject)) {
                        SubjectCard(subject: subject)
                    }
                }
            }
        }
    }
    
    // MARK: - Certificates Content
    private var certificatesContent: some View {
        VStack(spacing: 24) {
            if viewModel.earnedCertificates.isEmpty {
                emptyCertificatesState
            } else {
                earnedCertificatesSection
            }
            
            // Available Certificates
            availableCertificatesSection
        }
    }
    
    private var emptyCertificatesState: some View {
        VStack(spacing: 24) {
            Image(systemName: "medal.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            VStack(spacing: 12) {
                Text("No Certificates Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Complete learning paths to earn AI-verified certificates")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                selectedTab = .learn
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Start Learning")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
    
    private var earnedCertificatesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Certificates")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.earnedCertificates.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.primary)
                    .clipShape(Capsule())
            }
            
            ForEach(viewModel.earnedCertificates) { certificate in
                NavigationLink(destination: CertificateDetailView(certificate: certificate)) {
                    CertificateCard(certificate: certificate)
                }
            }
        }
    }
    
    private var availableCertificatesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Available Certificates")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ForEach(viewModel.availableCertificates) { certificate in
                NavigationLink(destination: CertificateRequirementsView(certificate: certificate)) {
                    AvailableCertificateCard(certificate: certificate)
                }
            }
        }
    }
    
    // MARK: - Achievements Content
    private var achievementsContent: some View {
        VStack(spacing: 24) {
            // Achievements Overview
            achievementsOverview
            
            // Badges Earned
            badgesSection
            
            // Milestones
            milestonesSection
            
            // Leaderboard
            leaderboardSection
        }
    }
    
    private var achievementsOverview: some View {
        HStack(spacing: 16) {
            achievementStat(
                icon: "trophy.fill",
                value: "\(viewModel.totalAchievements)",
                label: "Total",
                color: .yellow
            )
            
            achievementStat(
                icon: "star.fill",
                value: "\(viewModel.totalPoints)",
                label: "Points",
                color: .purple
            )
            
            achievementStat(
                icon: "chart.bar.fill",
                value: "#\(viewModel.globalRank)",
                label: "Rank",
                color: .blue
            )
        }
    }
    
    private func achievementStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var badgesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Badges")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.badges.count)/\(viewModel.totalBadges)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.badges) { badge in
                    BadgeCard(badge: badge)
                }
            }
        }
    }
    
    private var milestonesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Milestones")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ForEach(viewModel.milestones) { milestone in
                MilestoneCard(milestone: milestone)
            }
        }
    }
    
    private var leaderboardSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Global Leaderboard")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                NavigationLink(destination: GlobalLeaderboardView()) {
                    Text("View All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            VStack(spacing: 12) {
                ForEach(viewModel.topLearners.prefix(5)) { learner in
                    UniversityLeaderboardRow(learner: learner)
                }
            }
        }
    }
}

// MARK: - Supporting Card Views

struct LearningPathCard: View {
    let path: LearningPath
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(path.color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: path.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(path.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(path.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                
                Text("\(path.videosCount) videos • \(path.estimatedHours)h")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                // Progress
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.Colors.cardBackground)
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(path.color)
                            .frame(width: geometry.size.width * path.progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            // Progress %
            Text("\(Int(path.progress * 100))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(path.color)
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ActivityCard: View {
    let activity: LearningActivity
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(activity.color)
                .frame(width: 36, height: 36)
                .background(activity.color.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(activity.timeAgo)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TrendingSubjectCard: View {
    let subject: UniversitySubject
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(subject.color.opacity(0.15))
                    .frame(width: 160, height: 100)
                
                Image(systemName: subject.icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(subject.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(subject.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                        Text("\(subject.learnerCount)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("•")
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("\(subject.videosCount) videos")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .frame(width: 160)
        .padding(12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
}

struct CategoryCard: View {
    let category: SubjectCategory
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(category.color)
            }
            
            Text(category.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SubjectCard: View {
    let subject: UniversitySubject
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(subject.color.opacity(0.15))
                    .frame(height: 80)
                
                Image(systemName: subject.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(subject.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(subject.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(subject.videosCount) videos")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
}

struct RecommendedPathCard: View {
    let path: LearningPath
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(path.color.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: path.icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(path.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(path.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text(path.description)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(path.videosCount)", systemImage: "play.circle")
                    Label("\(path.estimatedHours)h", systemImage: "clock")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(path.color)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(path.color.opacity(0.3), lineWidth: 1.5)
        )
    }
}

struct CertificateCard: View {
    let certificate: Certificate
    
    var body: some View {
        VStack(spacing: 16) {
            // Certificate Visual
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [certificate.color, certificate.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)
                
                VStack(spacing: 12) {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(certificate.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Verified by AI")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(20)
            }
            
            VStack(spacing: 8) {
                Text("Earned on \(certificate.earnedDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 16) {
                    Button {
                        // Share certificate
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                    
                    Button {
                        // Download certificate
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                            Text("Download")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: certificate.color.opacity(0.2), radius: 15, x: 0, y: 8)
    }
}

struct AvailableCertificateCard: View {
    let certificate: Certificate
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(certificate.color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "medal.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(certificate.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(certificate.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("\(certificate.requiredHours)h watch time required")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppTheme.Colors.cardBackground)
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(certificate.color)
                            .frame(width: geometry.size.width * certificate.progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("\(Int(certificate.progress * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(certificate.color)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
}

struct BadgeCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(badge.color.opacity(0.15))
                    .frame(width: 70, height: 70)
                
                Image(systemName: badge.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(badge.color)
            }
            
            Text(badge.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct MilestoneCard: View {
    let milestone: Milestone
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(milestone.isCompleted ? .green : AppTheme.Colors.textTertiary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(milestone.description)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            if milestone.isCompleted {
                Text("+\(milestone.points)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(milestone.isCompleted ? Color.green.opacity(0.08) : AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(milestone.isCompleted ? Color.green.opacity(0.3) : AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
}

struct UniversityLeaderboardRow: View {
    let learner: Learner
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank Badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Text("#\(learner.rank)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(rankColor)
            }
            
            // Avatar
            AsyncImage(url: URL(string: learner.avatarURL)) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(learner.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("\(learner.certificates) certificates")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Points
            Text("\(learner.points)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
        }
        .padding(14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var rankColor: Color {
        switch learner.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return AppTheme.Colors.primary
        }
    }
}

// MARK: - Placeholder Detail Views
struct LearningPathDetailView: View {
    let path: LearningPath
    var body: some View {
        Text("Path: \(path.title)")
            .navigationTitle(path.title)
    }
}

struct SubjectDetailView: View {
    let subject: UniversitySubject
    var body: some View {
        Text("Subject: \(subject.title)")
            .navigationTitle(subject.title)
    }
}

struct CertificateDetailView: View {
    let certificate: Certificate
    var body: some View {
        Text("Certificate: \(certificate.title)")
            .navigationTitle(certificate.title)
    }
}

struct CertificateRequirementsView: View {
    let certificate: Certificate
    var body: some View {
        Text("Requirements for: \(certificate.title)")
            .navigationTitle(certificate.title)
    }
}

struct AllLearningPathsView: View {
    var body: some View {
        Text("All Learning Paths")
            .navigationTitle("Learning Paths")
    }
}

struct CategorySubjectsView: View {
    let category: SubjectCategory
    var body: some View {
        Text("Category: \(category.rawValue)")
            .navigationTitle(category.rawValue)
    }
}

struct GlobalLeaderboardView: View {
    var body: some View {
        Text("Global Leaderboard")
            .navigationTitle("Leaderboard")
    }
}

#Preview {
    UniversityHomeView()
        .environmentObject(AppState())
}

