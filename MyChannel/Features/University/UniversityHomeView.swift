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
    @ObservedObject private var trackingService = UniversityWatchTrackingService.shared
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
                universityHeroHeader
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
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if isInitialLoad {
                Task {
                    await viewModel.loadUserProgress()
                    isInitialLoad = false
                }
            }
        }
        // 🎓 The certificate celebration listener runs app-wide (started/stopped by
        // AppState on login/logout, presented from SplashContainer) so it fires
        // regardless of which tab the user is on. Here we just react to a new
        // certificate to refresh this screen's data and jump to Certificates.
        .onReceive(trackingService.$newlyEarnedCertificate.compactMap { $0 }) { _ in
            selectedTab = .certificates
            Task { await viewModel.loadUserProgress() }
        }
    }

    // MARK: - Refresh

    private func refreshContent() async {
        await viewModel.loadUserProgress()
    }

    // MARK: - Tab Bar (underline style, no pills)
    
    private var universityHeroHeader: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    UniversityTheme.Colors.accent.opacity(0.08),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "laurel.leading")
                .font(.system(size: 96, weight: .thin))
                .foregroundColor(Color(.tertiaryLabel).opacity(0.12))
                .offset(x: -82, y: -2)
            Image(systemName: "laurel.trailing")
                .font(.system(size: 96, weight: .thin))
                .foregroundColor(Color(.tertiaryLabel).opacity(0.12))
                .offset(x: 82, y: -2)
            
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(UniversityTheme.Colors.accent.opacity(0.14))
                        .frame(width: 58, height: 58)
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(UniversityTheme.Colors.accent)
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(UniversityTheme.Colors.accent)
                        .offset(y: 21)
                }
                
                HStack(spacing: 7) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(UniversityTheme.Colors.accent)
                    Text("MyChannel University")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(Color(.label))
                }
                
                Text("AI-verified learning paths. Real creator credentials.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .frame(height: 118)
    }

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
                .padding(.top, 12)
                .padding(.horizontal, 16)

            streakWeekStrip
                .padding(.horizontal, 16)
                .padding(.top, 12)

            if !viewModel.continueLearningVideos.isEmpty {
                premiumContinueWatchingCard(video: viewModel.continueLearningVideos[0])
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
            
            HStack(alignment: .top, spacing: 12) {
                featuredCourseCard
                academicPathCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

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

    // MARK: - Streak Week Strip (Duolingo-style 7-day calendar)

    private var streakWeekStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = UniversityStreakService.dayFormatter
        let activeSet = Set(viewModel.recentActiveDays)
        // Last 7 days, oldest → newest
        let days: [(date: Date, key: String, label: String)] = (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let key = formatter.string(from: date)
            let symbols = calendar.shortWeekdaySymbols
            let weekdayIndex = (calendar.component(.weekday, from: date) - 1)
            let label = String(symbols[weekdayIndex].prefix(1))
            return (date, key, label)
        }

        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(.systemOrange))
                Text("\(viewModel.streaksAndGoals.currentStreak)-Day Streak")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(.label))
                Spacer()
                if viewModel.streakFreezesAvailable > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(viewModel.streakFreezesAvailable)")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color(.systemTeal))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(.systemTeal).opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 0) {
                ForEach(days, id: \.key) { day in
                    let isActive = activeSet.contains(day.key)
                    let isToday = day.key == formatter.string(from: today)
                    VStack(spacing: 6) {
                        Text(day.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(.secondaryLabel))
                        ZStack {
                            Circle()
                                .fill(isActive ? Color(.systemOrange) : Color(.secondarySystemBackground))
                                .frame(width: 34, height: 34)
                            if isActive {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            } else if isToday {
                                Circle()
                                    .stroke(Color(.systemOrange).opacity(0.6), lineWidth: 1.5)
                                    .frame(width: 34, height: 34)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(isToday ? Color(.systemOrange) : Color.clear, lineWidth: 2)
                                .frame(width: 40, height: 40)
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Daily goal progress
            if viewModel.streaksAndGoals.dailyGoal != nil || viewModel.streaksAndGoals.todayProgress > 0 {
                let goalMet = viewModel.streaksAndGoals.todayGoalMet
                HStack(spacing: 8) {
                    Image(systemName: goalMet ? "checkmark.circle.fill" : "target")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(goalMet ? UniversityTheme.Colors.verified : Color(.secondaryLabel))
                    Text(goalMet ? "Daily goal complete — streak secured today!" : "Keep learning to secure today's streak")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(.secondaryLabel))
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.55), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Stats Hero Grid (replaces gradient hero card)

    private var statsHeroGrid: some View {        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statTile(
                    value: "\(Int(viewModel.totalUniversityHours))",
                    unit: "Hours",
                    label: "Learning Hours",
                    icon: "clock.fill",
                    iconColor: Color(.systemBlue)
                )
                statTile(
                    value: "\(viewModel.progress.videosCompleted)",
                    unit: "Videos",
                    label: "Enrollment",
                    icon: "play.square.fill",
                    iconColor: Color(.systemGray2)
                )
            }
            HStack(spacing: 12) {
                statTile(
                    value: "\(viewModel.certificatesEarned)",
                    unit: "Certificates",
                    label: "Verifiable Credentials",
                    icon: "seal.fill",
                    iconColor: UniversityTheme.Colors.certificateGold
                )
                statTile(
                    value: "\(viewModel.streaksAndGoals.currentStreak)",
                    unit: "Day Streak",
                    label: viewModel.streaksAndGoals.currentStreak > 0
                        ? "Best: \(viewModel.streaksAndGoals.longestStreak) days"
                        : "Start your learning streak",
                    icon: "flame.fill",
                    iconColor: Color(.systemOrange)
                )
            }
            HStack(spacing: 12) {
                statTile(
                    value: "\(viewModel.averageAIScore)",
                    unit: "AI Score",
                    label: "AI Score",
                    icon: "chart.xyaxis.line",
                    iconColor: UniversityTheme.Colors.accent
                )
                statTile(
                    value: viewModel.globalRank > 0 ? "#\(viewModel.globalRank)" : "—",
                    unit: "",
                    label: viewModel.globalRank > 0 ? "Global Rank" : "Earn points to rank",
                    icon: "chart.bar.fill",
                    iconColor: Color(.systemPurple)
                )
            }
        }
    }

    private func statTile(value: String, unit: String, label: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(.secondaryLabel))
                            .lineLimit(1)
                    }
                }
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(.separator).opacity(0.55), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        .frame(maxWidth: .infinity)
    }
    
    private func premiumContinueWatchingCard(video: ContinueLearningVideo) -> some View {
        Button {
            viewModel.playVideo(video)
            HapticManager.shared.impact(style: .medium)
        } label: {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=1200&q=80")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    LinearGradient(colors: [.black.opacity(0.85), .gray.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                }
                
                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.58), .black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.red)
                        Text("Continue Watching")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    HStack(alignment: .bottom, spacing: 12) {
                        AsyncImage(url: URL(string: video.video.thumbnailURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.white.opacity(0.22))
                        }
                        .frame(width: 142, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.video.title)
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            Text(video.video.creatorName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.78))
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                Text(video.timeRemainingText)
                                Spacer()
                                Image(systemName: "play.fill")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.82))
                        }
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.22)).frame(height: 4)
                            Capsule()
                                .fill(Color.red)
                                .frame(width: geo.size.width * video.progressPercentage, height: 4)
                            Circle()
                                .fill(.white)
                                .frame(width: 14, height: 14)
                                .offset(x: max(0, geo.size.width * video.progressPercentage - 7))
                        }
                    }
                    .frame(height: 14)

                    HStack(spacing: 14) {
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                        Rectangle()
                            .fill(.red)
                            .frame(width: 78, height: 4)
                            .clipShape(Capsule())
                        Spacer()
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundColor(.white.opacity(0.88))
                        Text("Chapter Selection")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.45), in: Capsule())
                    }
                }
                .padding(14)
            }
            .frame(height: 205)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
    
    private var featuredCourseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Featured Course")
                .font(.system(size: 20, weight: .black, design: .rounded))
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [Color(red: 0.12, green: 0.04, blue: 0.04), Color(red: 0.42, green: 0.13, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 14) {
                    Text("CS50X: Introduction to Computer Science")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                    Text("ENROLL")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(.white, in: Capsule())
                }
                .padding(14)
            }
            .frame(height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.8)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var academicPathCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("My Academic Path")
                .font(.system(size: 20, weight: .black, design: .rounded))
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground))
                AcademicPathMiniMap()
            }
            .frame(height: 132)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(.separator).opacity(0.4), lineWidth: 0.8)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

            sectionHeader(title: "Badges \(viewModel.earnedBadgeCount)/\(viewModel.totalBadges)", icon: "rosette")
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
            statsOverviewTile(icon: "chart.bar.fill", value: viewModel.globalRank > 0 ? "#\(viewModel.globalRank)" : "—", label: "Global Rank", iconColor: Color(.systemBlue))
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
            if viewModel.topLearners.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("Be the first on the leaderboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.label))
                    Text("Earn points by learning daily and completing certificates.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
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
                    .padding(.horizontal, 14)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 8)
    }
}


// ⚡ All card/row/detail components extracted to UniversityComponents.swift
