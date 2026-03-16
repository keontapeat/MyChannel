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
    @State private var isInitialLoad = true
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.sizeCategory) var sizeCategory

    enum UniversityTab: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case learn = "Learn"
        case certificates = "Certificates"
        case stats = "Stats"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .learn: return "play.square.stack.fill"
            case .certificates: return "seal.fill"
            case .stats: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar
                Divider()

                if viewModel.isLoading && isInitialLoad {
                    ScrollView {
                        VStack(spacing: 16) {
                            HeroCardSkeleton()
                            ForEach(0..<2) { _ in CareerPathRowSkeleton() }
                        }
                        .padding(.vertical, 20)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            switch selectedTab {
                            case .dashboard: dashboardContent
                            case .learn:     learnContent
                            case .certificates: certificatesContent
                            case .stats:     statsContent
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .refreshable { await refreshContent() }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("MCU")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(UniversityTheme.Colors.accent)
                        Text("MyChannel University")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.label))
                    }
                }
            }
        }
        .onAppear {
            if isInitialLoad {
                Task {
                    await viewModel.loadUserProgress()
                    isInitialLoad = false
                }
            }
        }
    }

    // MARK: - Refresh

    private func refreshContent() async {
        await viewModel.loadUserProgress()
    }

    // MARK: - Tab Bar (underline style, no pills)

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(UniversityTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    HapticManager.shared.impact(style: .light)
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(selectedTab == tab ? Color(.label) : Color(.tertiaryLabel))
                        .padding(.top, 12)

                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selectedTab == tab ? UniversityTheme.Colors.accent : Color.clear)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            statsHeroGrid
                .padding(.top, 20)
                .padding(.horizontal, 16)

            sectionDivider

            if !viewModel.continueLearningVideos.isEmpty {
                sectionHeader(title: "Continue Watching", icon: "play.fill")
                    .padding(.horizontal, 16)
                ContinueLearningSection(videos: viewModel.continueLearningVideos) { video in
                    viewModel.playVideo(video)
                }
                sectionDivider
            }

            if !viewModel.careerPathsProgress.isEmpty {
                sectionHeader(title: "Certificate Progress", icon: "seal.fill")
                    .padding(.horizontal, 16)
                CertificateProgressGrid(
                    careerPathsProgress: viewModel.careerPathsProgress.map { ($0, $1) }
                ) { careerPath, progress in
                    viewModel.navigateToCareerPath(careerPath, progress: progress)
                }
                sectionDivider
            }

            ForEach(viewModel.careerPathsWithVideos, id: \.careerPath.id) { item in
                CareerPathVideoRow(
                    careerPath: item.careerPath,
                    progress: item.progress,
                    videos: item.videos
                ) { video in
                    viewModel.playUniversityVideo(video)
                }
                sectionDivider
            }
        }
    }

    // MARK: - Stats Hero Grid (replaces gradient hero card)

    private var statsHeroGrid: some View {
        VStack(spacing: 12) {
            // Row 1 — primary stats
            HStack(spacing: 12) {
                statTile(
                    value: "\(Int(viewModel.totalUniversityHours))",
                    unit: "hrs",
                    label: "Learning Time",
                    icon: "clock.fill",
                    iconColor: Color(.systemBlue)
                )
                statTile(
                    value: "\(viewModel.progress.videosCompleted)",
                    unit: "videos",
                    label: "Completed",
                    icon: "checkmark.circle.fill",
                    iconColor: UniversityTheme.Colors.verified
                )
            }
            // Row 2 — secondary stats
            HStack(spacing: 12) {
                statTile(
                    value: "\(viewModel.certificatesEarned)",
                    unit: viewModel.certificatesEarned == 1 ? "cert" : "certs",
                    label: "Certificates",
                    icon: "seal.fill",
                    iconColor: UniversityTheme.Colors.certificateGold
                )
                statTile(
                    value: "\(viewModel.streaksAndGoals.currentStreak)",
                    unit: "days",
                    label: "Streak",
                    icon: "flame.fill",
                    iconColor: Color(.systemOrange)
                )
            }
            // Row 3 — tertiary stats
            HStack(spacing: 12) {
                statTile(
                    value: "\(viewModel.averageAIScore)",
                    unit: "%",
                    label: "AI Score",
                    icon: "checkmark.shield.fill",
                    iconColor: UniversityTheme.Colors.accent
                )
                statTile(
                    value: "#\(viewModel.globalRank)",
                    unit: "",
                    label: "Global Rank",
                    icon: "chart.bar.fill",
                    iconColor: Color(.systemPurple)
                )
            }
        }
    }

    private func statTile(value: String, unit: String, label: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                }
                Text(label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(UniversityTheme.Colors.accent)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(.label))
            Spacer()
        }
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    // MARK: - Learn Content
    private var learnContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            learnSearchBar
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 4)

            sectionDivider

            sectionHeader(title: "Browse by Category", icon: "square.grid.2x2.fill")
                .padding(.horizontal, 16)
            browseCategoriesSection
                .padding(.horizontal, 16)

            sectionDivider

            sectionHeader(title: "Recommended for You", icon: "sparkles")
                .padding(.horizontal, 16)
            recommendedPathsSection
                .padding(.horizontal, 16)

            sectionDivider

            sectionHeader(title: "All Subjects", icon: "books.vertical.fill")
                .padding(.horizontal, 16)
            allSubjectsGrid
                .padding(.horizontal, 16)
        }
    }

    private var learnSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(.secondaryLabel))
            TextField("Search subjects, skills, topics...", text: $viewModel.searchQuery)
                .font(.system(size: 15))
                .foregroundColor(Color(.label))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var browseCategoriesSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(SubjectCategory.allCases) { category in
                NavigationLink(destination: CategorySubjectsView(category: category)) {
                    CategoryCard(category: category)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var recommendedPathsSection: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.recommendedPaths) { path in
                NavigationLink(destination: LearningPathDetailView(path: path)) {
                    RecommendedPathCard(path: path)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var allSubjectsGrid: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("\(viewModel.allSubjects.count) subjects")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(.bottom, 10)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(viewModel.allSubjects) { subject in
                    NavigationLink(destination: SubjectDetailView(subject: subject)) {
                        SubjectCard(subject: subject)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Certificates Content
    private var certificatesContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.earnedCertificates.isEmpty {
                sectionHeader(title: "Earned", icon: "checkmark.seal.fill")
                    .padding(.horizontal, 16)
                earnedCertificatesSection
                    .padding(.horizontal, 16)
                sectionDivider
            }

            sectionHeader(title: "In Progress", icon: "arrow.triangle.2.circlepath")
                .padding(.horizontal, 16)
            availableCertificatesSection
                .padding(.horizontal, 16)

            if viewModel.earnedCertificates.isEmpty {
                emptyCertificatesState
                    .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
    }

    private var emptyCertificatesState: some View {
        VStack(spacing: 20) {
            Image(systemName: "seal")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(Color(.tertiaryLabel))
                .padding(.top, 40)

            VStack(spacing: 8) {
                Text("No Certificates Yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(.label))

                Text("Watch educational videos to earn AI-verified certificates you can share with employers.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
            }

            Button {
                selectedTab = .learn
            } label: {
                Text("Start Learning")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(UniversityTheme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
    }

    private var earnedCertificatesSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.earnedCertificates) { certificate in
                NavigationLink(destination: CertificateDetailView(certificate: certificate)) {
                    EarnedCertRow(certificate: certificate)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var availableCertificatesSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.availableCertificates) { certificate in
                NavigationLink(destination: CertificateRequirementsView(certificate: certificate)) {
                    InProgressCertRow(certificate: certificate)
                }
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Stats Content
    private var statsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Overview stat row
            statsOverviewRow
                .padding(.horizontal, 16)
                .padding(.top, 20)

            sectionDivider

            sectionHeader(title: "Milestones", icon: "flag.fill")
                .padding(.horizontal, 16)
            milestonesSection
                .padding(.horizontal, 16)

            sectionDivider

            sectionHeader(title: "Badges \(viewModel.badges.count)/\(viewModel.totalBadges)", icon: "rosette")
                .padding(.horizontal, 16)
            badgesSection
                .padding(.horizontal, 16)

            sectionDivider

            sectionHeader(title: "Global Leaderboard", icon: "chart.bar.fill")
                .padding(.horizontal, 16)
            leaderboardSection
                .padding(.horizontal, 16)
        }
    }

    private var statsOverviewRow: some View {
        HStack(spacing: 12) {
            statsOverviewTile(icon: "trophy.fill", value: "\(viewModel.totalAchievements)", label: "Achievements", iconColor: UniversityTheme.Colors.certificateGold)
            statsOverviewTile(icon: "star.fill", value: "\(viewModel.totalPoints)", label: "Points", iconColor: Color(.systemPurple))
            statsOverviewTile(icon: "chart.bar.fill", value: "#\(viewModel.globalRank)", label: "Global Rank", iconColor: Color(.systemBlue))
        }
    }

    private func statsOverviewTile(icon: String, value: String, label: String, iconColor: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(iconColor)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var badgesSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(viewModel.badges) { badge in
                BadgeCard(badge: badge)
            }
        }
        .padding(.bottom, 8)
    }

    private var milestonesSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.milestones.enumerated()), id: \.element.id) { index, milestone in
                MilestoneRow(milestone: milestone, isLast: index == viewModel.milestones.count - 1)
            }
        }
        .padding(.bottom, 8)
    }

    private var leaderboardSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.topLearners.prefix(5).enumerated()), id: \.element.id) { index, learner in
                UniversityLeaderboardRow(learner: learner)
                if index < min(4, viewModel.topLearners.count - 1) {
                    Divider().padding(.leading, 58)
                }
            }

            NavigationLink(destination: GlobalLeaderboardView()) {
                HStack {
                    Text("View Full Leaderboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(UniversityTheme.Colors.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .padding(.vertical, 14)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 8)
    }
}

// MARK: - Supporting Card Views

struct LearningPathCard: View {
    let path: LearningPath

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: path.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(path.color)
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(path.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .lineLimit(1)

                Text("\(path.videosCount) videos · \(path.estimatedHours)h")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.secondaryLabel))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemFill)).frame(height: 4)
                        Capsule().fill(Color(.label).opacity(0.7))
                            .frame(width: geo.size.width * path.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            Text("\(Int(path.progress * 100))%")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(.secondaryLabel))
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct ActivityCard: View {
    let activity: LearningActivity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(.label))
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.label))

                Text(activity.timeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }
}

struct TrendingSubjectCard: View {
    let subject: UniversitySubject

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 160, height: 90)

                Image(systemName: subject.icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .lineLimit(2)

                Text("\(subject.videosCount) videos")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
        .frame(width: 160)
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct CategoryCard: View {
    let category: SubjectCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(.label))
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(category.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.label))
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct SubjectCard: View {
    let subject: UniversitySubject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 70)

                Image(systemName: subject.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
            }

            Text(subject.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.label))
                .lineLimit(2)

            Text("\(subject.videosCount) videos")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabel))
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct RecommendedPathCard: View {
    let path: LearningPath

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: path.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color(.label))
                .frame(width: 52, height: 52)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(path.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .lineLimit(1)

                Text(path.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label("\(path.videosCount) videos", systemImage: "play.circle")
                    Label("\(path.estimatedHours)h", systemImage: "clock")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

// MARK: - Certificate Row Views (clean credential cards)

struct EarnedCertRow: View {
    let certificate: Certificate

    var body: some View {
        HStack(spacing: 14) {
            // Seal icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(UniversityTheme.Colors.certificateGold)
                .frame(width: 48, height: 48)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(certificate.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(.label))

                Text("Earned \(certificate.earnedDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))

                Text("AI Score: \(certificate.aiVerificationScore)%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(UniversityTheme.Colors.verified)
            }

            Spacer()

            VStack(spacing: 6) {
                Button { } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(UniversityTheme.Colors.accent)
                }
                .buttonStyle(PlainButtonStyle())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct InProgressCertRow: View {
    let certificate: Certificate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "seal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(certificate.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(.label))

                    Text("\(Int(certificate.progress * 100))% complete · \(certificate.requiredHours)h required")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.secondaryLabel))
                }

                Spacer()

                Text("\(Int(certificate.progress * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(.label))
            }

            // Requirements checklist
            VStack(spacing: 6) {
                requirementRow(
                    text: "\(certificate.requiredVideos) videos watched",
                    done: certificate.progress >= 0.5
                )
                requirementRow(
                    text: "\(certificate.requiredHours)h total watch time",
                    done: certificate.progress >= 0.7
                )
                requirementRow(
                    text: "AI verification score ≥ 70",
                    done: certificate.aiVerificationScore >= 70
                )
            }
            .padding(.leading, 58)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemFill)).frame(height: 3)
                    Capsule()
                        .fill(Color(.label).opacity(0.6))
                        .frame(width: geo.size.width * certificate.progress, height: 3)
                }
            }
            .frame(height: 3)
            .padding(.leading, 58)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }

    private func requirementRow(text: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(done ? UniversityTheme.Colors.verified : Color(.tertiaryLabel))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(done ? Color(.label) : Color(.secondaryLabel))
            Spacer()
        }
    }
}

struct BadgeCard: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.isEarned ? badge.icon : "lock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(badge.isEarned ? Color(.label) : Color(.tertiaryLabel))
                .frame(width: 56, height: 56)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        badge.isEarned ? UniversityTheme.Colors.certificateGold.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
                )

            Text(badge.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(badge.isEarned ? Color(.label) : Color(.tertiaryLabel))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct MilestoneRow: View {
    let milestone: Milestone
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline dot
            VStack(spacing: 0) {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(milestone.isCompleted ? UniversityTheme.Colors.verified : Color(.tertiaryLabel))

                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.label))

                Text(milestone.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))

                if milestone.isCompleted {
                    Text("+\(milestone.points) pts")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(UniversityTheme.Colors.verified)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct UniversityLeaderboardRow: View {
    let learner: Learner

    var body: some View {
        HStack(spacing: 14) {
            Text(rankLabel)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 30)

            AsyncImage(url: URL(string: learner.avatarURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(Color(.secondarySystemBackground))
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(learner.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.label))

                HStack(spacing: 6) {
                    Text("\(learner.certificates) certs")
                    Text("·")
                    Text("\(learner.watchHours)h")
                    Text("·")
                    Label("\(learner.currentStreak)d", systemImage: "flame.fill")
                }
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()

            Text("\(learner.points)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var rankLabel: String {
        switch learner.rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(learner.rank)"
        }
    }

    private var rankColor: Color {
        switch learner.rank {
        case 1: return UniversityTheme.Colors.certificateGold
        case 2: return Color(.systemGray)
        case 3: return Color(red: 0.72, green: 0.45, blue: 0.2)
        default: return Color(.secondaryLabel)
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

