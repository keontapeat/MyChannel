//
//  ComprehensiveCreatorStudioView.swift
//  MyChannel
//
//  Complete YouTube Studio parity with advanced features
//  Every feature YouTube Studio has + revolutionary AI enhancements
//

import SwiftUI
import Charts

struct ComprehensiveCreatorStudioView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    @StateObject private var aiCoCreator = AIVideoCoCreatorService.shared
    @StateObject private var predictiveEngine = PredictiveAnalyticsEngine.shared
    
    let videoIdToAnalyze: String? // Optional video ID to focus on when opening
    @State private var selectedTab: StudioTab = .dashboard
    @State private var showingUploadModal = false
    @State private var selectedVideoId: String? = nil
    
    init(videoId: String? = nil) {
        self.videoIdToAnalyze = videoId
    }
    
    enum StudioTab: String, CaseIterable, Hashable {
        case dashboard = "Dashboard"
        case aiStudio = "AI Studio"
        case content = "Content"
        case analytics = "Analytics"
        case earnings = "Earnings"
        case customization = "Customization"
        case community = "Community"
        case premieres = "Premieres"
        case live = "Live"
        case flicks = "Flicks"
        case playlists = "Playlists"
        case copyright = "Copyright"
        case monetization = "Monetization"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.xaxis"
            case .aiStudio: return "lightbulb"
            case .content: return "play.rectangle"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .earnings: return "dollarsign.circle"
            case .customization: return "paintbrush"
            case .community: return "person.3"
            case .premieres: return "calendar.badge.clock"
            case .live: return "dot.radiowaves.left.and.right"
            case .flicks: return "rectangle.portrait"
            case .playlists: return "list.bullet.rectangle"
            case .copyright: return "shield.checkered"
            case .monetization: return "banknote"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            // 🔥 MOBILE-FIRST CREATOR STUDIO: Always show main content on mobile
            mainContentArea
        }
        .navigationTitle("Creator Studio")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                // 🔥 MOBILE NAVIGATION: Studio sections menu
                Menu {
                    ForEach(StudioTab.allCases, id: \.self) { tab in
                        Button(action: { 
                            selectedTab = tab
                            HapticManager.shared.impact(style: .light)
                        }) {
                            Label(tab.rawValue, systemImage: tab.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selectedTab.icon)
                            .font(.system(size: 16, weight: .medium))
                        Text(selectedTab.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Upload Button
                Button(action: { showingUploadModal = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                // Notifications
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.system(size: 16))
                }
            }
        }
        .sheet(isPresented: $showingUploadModal) {
            Text("Upload Video")
                .font(.title)
                .padding()
        }
        .safeAreaInset(edge: .bottom) {
            // 🔥 MOBILE QUICK TABS: Bottom navigation for key sections
            mobileQuickTabs
        }
        .onAppear {
            // If videoId provided, navigate to content tab and select that video
            if let videoId = videoIdToAnalyze {
                selectedTab = .content
                selectedVideoId = videoId
            }
            
            // Load initial analytics data
            Task {
                if let creatorId = appState.currentUser?.id {
                    await analyticsService.startRealtimeMonitoring(for: creatorId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenVideoInStudio"))) { notification in
            if let videoId = notification.object as? String {
                selectedTab = .content
                selectedVideoId = videoId
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCreatorStudio"))) { notification in
            // 🔥 REAL-TIME ANALYTICS REFRESH: Update when new video uploaded
            Task {
                if let creatorId = appState.currentUser?.id {
                    await analyticsService.startRealtimeMonitoring(for: creatorId)
                }
                
                // Add new video to analytics tracking
                if let video = notification.object as? Video {
                    let analytics = VideoAnalytics(
                        videoId: video.id,
                        views: video.viewCount,
                        uniqueViews: video.viewCount,
                        likes: video.likeCount,
                        dislikes: video.dislikeCount,
                        comments: video.commentCount,
                        shares: 0,
                        watchTime: 0,
                        averageWatchTime: 0,
                        clickThroughRate: 0,
                        engagementRate: 0,
                        revenue: 0
                    )
                    await analyticsService.addVideoAnalytics(analytics)
                }
            }
        }
    }
    
    // MARK: - Sidebar Navigation
    
    private var sidebarNavigation: some View {
        List(StudioTab.allCases, id: \.self) { tab in
            NavigationLink(destination: destinationView(for: tab)) {
                HStack(spacing: 12) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 20)
                    
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    // Badge for notifications
                    if tab == .community && hasNewComments {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                    }
                    
                    if tab == .copyright && hasCopyrightClaims {
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 4)
            }
            .simultaneousGesture(TapGesture().onEnded {
                selectedTab = tab
                HapticManager.shared.impact(style: .light)
            })
        }
        .listStyle(.sidebar)
        .navigationTitle("Studio")
    }
    
    // MARK: - Navigation Destination
    
    @ViewBuilder
    private func destinationView(for tab: StudioTab) -> some View {
        switch tab {
        case .dashboard:
            StudioDashboardView()
                .navigationTitle("Dashboard")
        case .aiStudio:
            AICreatorStudioView()
                .navigationTitle("AI Studio")
        case .content:
            ContentManagementView()
                .navigationTitle("Content")
        case .analytics:
            AdvancedAnalyticsView()
                .navigationTitle("Analytics")
        case .earnings:
            EarningsManagementView()
                .navigationTitle("Earnings")
        case .customization:
            ChannelCustomizationView()
                .navigationTitle("Customization")
        case .community:
            CommunityManagementView()
                .navigationTitle("Community")
        case .premieres:
            PremieresManagementView()
                .navigationTitle("Premieres")
        case .live:
            LiveStreamingStudioView()
                .navigationTitle("Live")
        case .flicks:
            FlicksStudioView()
                .navigationTitle("Flicks")
        case .playlists:
            PlaylistManagementView()
                .navigationTitle("Playlists")
        case .copyright:
            CopyrightManagementView()
                .navigationTitle("Copyright")
        case .monetization:
            MonetizationStudioView()
                .navigationTitle("Monetization")
        case .settings:
            StudioSettingsView()
                .navigationTitle("Settings")
        }
    }
    
    // MARK: - Main Content Area
    
    @ViewBuilder
    private var mainContentArea: some View {
        switch selectedTab {
        case .dashboard:
            StudioDashboardView()
        case .aiStudio:
            AICreatorStudioView()
        case .content:
            ContentManagementView()
        case .analytics:
            AdvancedAnalyticsView()
        case .earnings:
            EarningsManagementView()
        case .customization:
            ChannelCustomizationView()
        case .community:
            CommunityManagementView()
        case .premieres:
            PremieresManagementView()
        case .live:
            LiveStreamingStudioView()
        case .flicks:
            FlicksStudioView()
        case .playlists:
            PlaylistManagementView()
        case .copyright:
            CopyrightManagementView()
        case .monetization:
            MonetizationStudioView()
        case .settings:
            StudioSettingsView()
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasNewComments: Bool {
        // Check for new comments requiring moderation
        return true // Placeholder
    }
    
    private var hasCopyrightClaims: Bool {
        // Check for active copyright claims
        return false // Placeholder
    }
}

// MARK: - Studio Dashboard View

struct StudioDashboardView: View {
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    @StateObject private var predictiveEngine = PredictiveAnalyticsEngine.shared
    @State private var selectedMetric: AnalyticsMetric = .views
    @State private var recentVideos: [Video] = []
    @State private var latestComments: [StudioComment] = []
    
    enum AnalyticsMetric: String, CaseIterable {
        case views = "Views"
        case watchTime = "Watch Time"
        case subscribers = "Subscribers"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Channel Analytics Summary
                channelAnalyticsSummary
                
                // Recent Videos
                recentVideosSection
                
                // Latest Comments
                latestCommentsSection
                
                // Analytics Graph
                analyticsGraphSection
                
                // Studio Insights
                studioInsightsSection
                
                // Revenue Overview
                revenueOverviewSection
                
                // Quick Actions
                quickActionsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadDashboardData()
        }
    }
    
    private func loadDashboardData() async {
        // Load recent videos and comments
        // This would fetch from VideoFirestoreService and CommentService
    }
    
    private var channelAnalyticsSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StudioStatCard(
                    title: "Views",
                    value: formatNumber(analyticsService.channelAnalytics?.totalViews ?? 0),
                    change: "+12.5%",
                    isPositive: true
                )
                .frame(width: 160)
                
                StudioStatCard(
                    title: "Subscribers",
                    value: formatNumber(analyticsService.channelAnalytics?.totalSubscribers ?? 0),
                    change: "+8.3%",
                    isPositive: true
                )
                .frame(width: 160)
                
                StudioStatCard(
                    title: "Watch Time",
                    value: "2.4K hrs",
                    change: "+15.2%",
                    isPositive: true
                )
                .frame(width: 160)
                
                StudioStatCard(
                    title: "Revenue",
                    value: "$\(String(format: "%.0f", analyticsService.channelAnalytics?.totalRevenue ?? 0.0))",
                    change: "+18.7%",
                    isPositive: true
                )
                .frame(width: 160)
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
    
    private var recentVideosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Videos")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Button(action: {}) {
                    Text("View All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if recentVideos.isEmpty {
                Text("No recent videos")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(recentVideos.prefix(6)) { video in
                        RecentVideoCard(video: video)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var latestCommentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Latest Comments")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Button(action: {}) {
                    Text("View All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if latestComments.isEmpty {
                Text("No recent comments")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(latestComments.prefix(5)) { comment in
                        StudioCommentCard(comment: comment)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var analyticsGraphSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Channel Performance")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(AnalyticsMetric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            // Placeholder for chart
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.Colors.background)
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("Analytics graph will display here")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                )
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var studioInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("Studio Insights")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                InsightCard(
                    icon: "clock",
                    title: "Best Upload Time",
                    value: "2:00 PM EST",
                    subtitle: "78% audience active"
                )
                
                InsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Growth Trend",
                    value: "+24%",
                    subtitle: "Last 30 days"
                )
                
                InsightCard(
                    icon: "eye",
                    title: "Avg. View Duration",
                    value: "8:42",
                    subtitle: "12% above average"
                )
                
                InsightCard(
                    icon: "person.2",
                    title: "Engagement Rate",
                    value: "6.8%",
                    subtitle: "High engagement"
                )
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var revenueOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Revenue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Button(action: {}) {
                    Text("View Details")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Estimated Revenue")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("$\(String(format: "%.2f", analyticsService.estimatedRevenue))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .medium))
                        Text("+18.7% vs last month")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.green)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            VStack(spacing: 8) {
                StudioStudioQuickActionButton(title: "Upload Video", icon: "arrow.up.circle") {}
                StudioStudioQuickActionButton(title: "Go Live", icon: "dot.radiowaves.left.and.right") {}
                StudioStudioQuickActionButton(title: "Create Post", icon: "square.and.pencil") {}
                StudioStudioQuickActionButton(title: "View Analytics", icon: "chart.xyaxis.line") {}
            }
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct StudioStatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.system(size: 11, weight: .medium))
                Text(change)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isPositive ? .green : .red)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon with neutral background
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Recent Video Card

struct RecentVideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.background)
            }
            .frame(height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(video.formattedViewCount) views")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Studio Comment Model & Card

struct StudioComment: Identifiable {
    let id: String
    let username: String
    let userAvatarURL: String
    let text: String
    let videoTitle: String
    let timestamp: Date
    
    var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

struct StudioCommentCard: View {
    let comment: StudioComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // User avatar
            AsyncImage(url: URL(string: comment.userAvatarURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.background)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(comment.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("•")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(comment.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(3)
                
                Text("on \(comment.videoTitle)")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .background(AppTheme.Colors.background)
        .cornerRadius(8)
    }
}

// MARK: - Studio Quick Action Button

struct StudioStudioQuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Complete Views Now in Separate Files
// All views have been moved to MyChannel/Features/Studio/Views/
// - ContentManagementView.swift
// - AdvancedAnalyticsView.swift  
// - EarningsManagementView.swift
// - ChannelCustomizationView.swift
// - CommunityManagementView.swift
// - LiveStreamingStudioView.swift
// - FlicksStudioView.swift
// - PlaylistManagementView.swift
// - CopyrightManagementView.swift
// - StudioSettingsView.swift

// MARK: - Premieres Management View
struct PremieresManagementView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var premieresService = ScheduledPremieresService.shared
    @State private var showingScheduleView = false
    @State private var selectedFilter: PremiereFilter = .all
    
    enum PremiereFilter: String, CaseIterable {
        case all = "All"
        case scheduled = "Scheduled"
        case live = "Live Now"
        case completed = "Completed"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Video Premieres")
                                .font(.system(size: 22, weight: .bold))
                            Text("Build hype and watch together with your audience")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { showingScheduleView = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                Text("Schedule")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(PremiereFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Stats Overview
                HStack(spacing: 12) {
                    StatBox(
                        title: "Scheduled",
                        value: "\(filteredPremieres.filter { $0.status == .scheduled }.count)",
                        icon: "calendar.badge.clock",
                        color: .blue
                    )
                    StatBox(
                        title: "Live Now",
                        value: "\(filteredPremieres.filter { $0.status == .live }.count)",
                        icon: "dot.radiowaves.left.and.right",
                        color: .red
                    )
                    StatBox(
                        title: "Completed",
                        value: "\(filteredPremieres.filter { $0.status == .completed }.count)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
                .padding(.horizontal)
                
                // Premieres List
                if filteredPremieres.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No Premieres Yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Schedule your first premiere to build anticipation")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(action: { showingScheduleView = true }) {
                            Text("Schedule Premiere")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppTheme.Colors.primary)
                                .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredPremieres) { premiere in
                            PremiereCard(premiere: premiere)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Help Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("💡 Premiere Tips")
                        .font(.system(size: 18, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        TipRow(
                            icon: "calendar.badge.clock",
                            text: "Schedule at least 24 hours in advance for maximum reach"
                        )
                        TipRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            text: "Enable chat to interact with viewers during the premiere"
                        )
                        TipRow(
                            icon: "bell.fill",
                            text: "Your subscribers will get notifications when it starts"
                        )
                        TipRow(
                            icon: "sparkles",
                            text: "Use countdown timer to build anticipation"
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
            if let creatorId = appState.currentUser?.id {
                premieresService.listenToPremieres(creatorId: creatorId)
            }
        }
        .onDisappear {
            premieresService.stopListening()
        }
        .sheet(isPresented: $showingScheduleView) {
            if let creatorId = appState.currentUser?.id {
                SchedulePremiereView(creatorId: creatorId)
            }
        }
    }
    
    private var filteredPremieres: [ScheduledPremiere] {
        switch selectedFilter {
        case .all:
            return premieresService.premieres
        case .scheduled:
            return premieresService.premieres.filter { $0.status == .scheduled }
        case .live:
            return premieresService.premieres.filter { $0.status == .live }
        case .completed:
            return premieresService.premieres.filter { $0.status == .completed }
        }
    }
}

struct PremiereCard: View {
    let premiere: ScheduledPremiere
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: premiere.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.7))
                    )
            }
            .frame(width: 120, height: 68)
            .cornerRadius(8)
            .overlay(
                // Status Badge
                HStack {
                    Circle()
                        .fill(premiere.status == .live ? Color.red : premiere.status == .scheduled ? Color.blue : Color.green)
                        .frame(width: 8, height: 8)
                    Text(premiere.status.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.8))
                .cornerRadius(6)
                .padding(6),
                alignment: .topLeading
            )
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(premiere.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(formatDate(premiere.scheduledAt))
                        .font(.system(size: 13))
                }
                .foregroundColor(.secondary)
                
                if premiere.status == .live, let viewerCount = premiere.viewerCount {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12))
                        Text("\(viewerCount) watching")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.red)
                }
                
                if premiere.chatEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 11))
                        Text("Chat enabled")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 16))
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}

struct MonetizationStudioView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    @State private var selectedTab: MonetizationTab = .overview
    @State private var globalMonetizationEnabled = true
    @State private var adSettings = AdSettings()
    @State private var membershipSettings = MembershipSettings()
    @State private var merchandiseSettings = MerchandiseSettings()
    
    enum MonetizationTab: String, CaseIterable {
        case overview = "Overview"
        case ads = "Ads"
        case memberships = "Memberships"
        case merchandise = "Merchandise"
        case donations = "Super Chat"
        case analytics = "Revenue Analytics"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .ads: return "play.rectangle.fill"
            case .memberships: return "person.badge.plus.fill"
            case .merchandise: return "bag.fill"
            case .donations: return "heart.fill"
            case .analytics: return "dollarsign.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Tab Selector
            VStack(spacing: 12) {
                // Tab Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MonetizationTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
                                HapticManager.shared.impact(style: .light)
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                    Text(tab.rawValue)
                                        .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                                        .foregroundColor(selectedTab == tab ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                                }
                                .frame(minWidth: 90)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                                .background(AppTheme.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.1), lineWidth: selectedTab == tab ? 2 : 1)
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            // Main Content
            Group {
                switch selectedTab {
                case .overview:
                    MonetizationOverviewView()
                case .ads:
                    AdMonetizationView(settings: $adSettings)
                case .memberships:
                    MembershipMonetizationView(settings: $membershipSettings)
                case .merchandise:
                    MerchandiseMonetizationView(settings: $merchandiseSettings)
                case .donations:
                    DonationMonetizationView()
                case .analytics:
                    RevenueAnalyticsView()
                }
            }
        }
        .onAppear {
            loadMonetizationSettings()
        }
    }
    
    private func loadMonetizationSettings() {
        // Load settings from backend or UserDefaults
        globalMonetizationEnabled = UserDefaults.standard.bool(forKey: "monetization_enabled")
        adSettings = AdSettings.load()
        membershipSettings = MembershipSettings.load()
        merchandiseSettings = MerchandiseSettings.load()
    }
}

// MARK: - Monetization Overview
struct MonetizationOverviewView: View {
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Revenue Summary Cards
                HStack(spacing: 16) {
                    RevenueCard(
                        title: "Total Revenue",
                        amount: analyticsService.estimatedRevenue,
                        change: analyticsService.revenueGrowth,
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                    
                    RevenueCard(
                        title: "This Month",
                        amount: analyticsService.estimatedRevenue * 0.3,
                        change: 12.5,
                        icon: "calendar.circle.fill",
                        color: .blue
                    )
                }
                
                // Revenue Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Revenue Sources")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    let revenueBreakdown = analyticsService.getRevenueBreakdown(for: "current_user")
                    
                    ForEach(Array(revenueBreakdown.keys.sorted()), id: \.self) { source in
                        HStack {
                            Image(systemName: iconForRevenueSource(source))
                                .foregroundColor(colorForRevenueSource(source))
                            Text(source.capitalized)
                            Spacer()
                            Text("$\(String(format: "%.2f", revenueBreakdown[source] ?? 0))")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Quick Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        StudioQuickActionButton(
                            title: "Enable Ads",
                            subtitle: "Start earning from video ads",
                            icon: "play.rectangle.fill",
                            color: Color.red
                        ) {
                            // Enable ads action
                        }
                        
                        StudioQuickActionButton(
                            title: "Set Up Memberships",
                            subtitle: "Create membership tiers",
                            icon: "person.badge.plus.fill",
                            color: Color.purple
                        ) {
                            // Set up memberships action
                        }
                        
                        StudioQuickActionButton(
                            title: "Add Merchandise",
                            subtitle: "Sell your products",
                            icon: "bag.fill",
                            color: Color.orange
                        ) {
                            // Add merchandise action
                        }
                        
                        StudioQuickActionButton(
                            title: "Super Chat",
                            subtitle: "Enable donations",
                            icon: "heart.fill",
                            color: Color.pink
                        ) {
                            // Enable super chat action
                        }
                    }
                }
                .padding()
            }
            .padding()
        }
    }
    
    private func iconForRevenueSource(_ source: String) -> String {
        switch source.lowercased() {
        case "ads": return "play.rectangle.fill"
        case "memberships": return "person.badge.plus.fill"
        case "donations": return "heart.fill"
        default: return "dollarsign.circle.fill"
        }
    }
    
    private func colorForRevenueSource(_ source: String) -> Color {
        switch source.lowercased() {
        case "ads": return .red
        case "memberships": return .purple
        case "donations": return .pink
        default: return .blue
        }
    }
}

// MARK: - Ad Monetization View
struct AdMonetizationView: View {
    @Binding var settings: AdSettings
    @State private var showingAdPreview = false
    
    var body: some View {
        Form {
            Section("Ad Settings") {
                Toggle("Enable Ads on Videos", isOn: $settings.adsEnabled)
                
                if settings.adsEnabled {
                    Toggle("Pre-roll Ads", isOn: $settings.prerollEnabled)
                    Toggle("Mid-roll Ads", isOn: $settings.midrollEnabled)
                    Toggle("Post-roll Ads", isOn: $settings.postrollEnabled)
                    
                    Picker("Ad Frequency", selection: $settings.adFrequency) {
                        Text("Low").tag(AdFrequency.low)
                        Text("Medium").tag(AdFrequency.medium)
                        Text("High").tag(AdFrequency.high)
                    }
                    
                    Toggle("Skippable Ads", isOn: $settings.skippableAds)
                    Toggle("Personalized Ads", isOn: $settings.personalizedAds)
                }
            }
            
            Section("Revenue Share") {
                HStack {
                    Text("Creator Share")
                    Spacer()
                    Text("55%")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Platform Share")
                    Spacer()
                    Text("45%")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
            Section("Ad Performance") {
                HStack {
                    Text("Average CPM")
                    Spacer()
                    Text("$2.50")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Fill Rate")
                    Spacer()
                    Text("85%")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Viewability Rate")
                    Spacer()
                    Text("92%")
                        .fontWeight(.semibold)
                }
            }
            
            if settings.adsEnabled {
                Section {
                    Button("Preview Ad Experience") {
                        showingAdPreview = true
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingAdPreview) {
            AdPreviewView()
        }
        .onChange(of: settings) { newSettings in
            newSettings.save()
        }
    }
}

// MARK: - Supporting Views and Models
struct RevenueCard: View {
    let title: String
    let amount: Double
    let change: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text("$\(String(format: "%.2f", amount))")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                    .foregroundColor(change >= 0 ? .green : .red)
                Text("\(String(format: "%.1f", abs(change)))%")
                    .foregroundColor(change >= 0 ? .green : .red)
                Text("vs last month")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


// MARK: - Settings Models
struct AdSettings: Equatable {
    var adsEnabled: Bool = false
    var prerollEnabled: Bool = true
    var midrollEnabled: Bool = true
    var postrollEnabled: Bool = false
    var adFrequency: AdFrequency = .medium
    var skippableAds: Bool = true
    var personalizedAds: Bool = true
    
    static func load() -> AdSettings {
        // Load from UserDefaults or backend
        return AdSettings()
    }
    
    func save() {
        // Save to UserDefaults or backend
        UserDefaults.standard.set(adsEnabled, forKey: "ads_enabled")
        UserDefaults.standard.set(prerollEnabled, forKey: "preroll_enabled")
        UserDefaults.standard.set(midrollEnabled, forKey: "midroll_enabled")
        UserDefaults.standard.set(postrollEnabled, forKey: "postroll_enabled")
        UserDefaults.standard.set(skippableAds, forKey: "skippable_ads")
        UserDefaults.standard.set(personalizedAds, forKey: "personalized_ads")
    }
}

enum AdFrequency: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct MembershipSettings {
    var membershipEnabled: Bool = false
    var tiers: [MembershipTier] = []
    
    static func load() -> MembershipSettings {
        return MembershipSettings()
    }
    
    func save() {
        // Save to backend
    }
}

struct MerchandiseSettings {
    var merchandiseEnabled: Bool = false
    var products: [MerchandiseProduct] = []
    
    static func load() -> MerchandiseSettings {
        return MerchandiseSettings()
    }
    
    func save() {
        // Save to backend
    }
}

struct MerchandiseProduct {
    let id: String
    let name: String
    let price: Double
    let imageURL: String
}

// MARK: - Placeholder Views
struct MembershipMonetizationView: View {
    @Binding var settings: MembershipSettings
    @State private var membershipEnabled = true
    @State private var showingAddTier = false
    @State private var tiers: [MonetizationMembershipTier] = [
        MonetizationMembershipTier(name: "Bronze", price: 4.99, perks: ["Early access to videos", "Custom badge"], color: .orange),
        MonetizationMembershipTier(name: "Silver", price: 9.99, perks: ["Everything in Bronze", "Members-only content", "Priority replies"], color: .gray),
        MonetizationMembershipTier(name: "Gold", price: 24.99, perks: ["Everything in Silver", "Monthly Q&A", "Exclusive merch discount"], color: .yellow)
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Channel Memberships")
                            .font(.system(size: 22, weight: .bold))
                        Text("Offer exclusive perks to your biggest supporters")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $membershipEnabled)
                        .labelsHidden()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Stats Overview
                HStack(spacing: 12) {
                    StatBox(title: "Members", value: "1,234", icon: "person.3.fill", color: .blue)
                    StatBox(title: "Monthly", value: "$12.4K", icon: "dollarsign.circle.fill", color: .green)
                    StatBox(title: "Retention", value: "94%", icon: "chart.line.uptrend.xyaxis", color: .purple)
                }
                
                // Membership Tiers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Membership Tiers")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button(action: { showingAddTier = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Tier")
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    
                    ForEach(tiers) { tier in
                        MembershipTierCard(tier: tier)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Revenue Share Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Revenue Share")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You keep")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("90%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("MyChannel takes")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("10%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Better revenue share than YouTube's 70/30 split")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Memberships")
    }
}

struct MonetizationMembershipTier: Identifiable {
    let id = UUID()
    var name: String
    var price: Double
    var perks: [String]
    var color: Color
}

struct MembershipTierCard: View {
    let tier: MonetizationMembershipTier
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(tier.color.gradient)
                    .frame(width: 12, height: 12)
                
                Text(tier.name)
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text("$\(String(format: "%.2f", tier.price))/mo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tier.perks, id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(tier.color)
                            .font(.system(size: 14))
                        Text(perk)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MerchandiseMonetizationView: View {
    @Binding var settings: MerchandiseSettings
    @State private var merchEnabled = true
    @State private var showingAddProduct = false
    @State private var products: [MerchProduct] = [
        MerchProduct(name: "Limited Edition Hoodie", price: 59.99, stock: 42, image: "tshirt", category: "Apparel"),
        MerchProduct(name: "Signature Hat", price: 29.99, stock: 128, image: "sun.haze", category: "Accessories"),
        MerchProduct(name: "Phone Case", price: 19.99, stock: 87, image: "iphone", category: "Tech")
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Merchandise Store")
                            .font(.system(size: 22, weight: .bold))
                        Text("Sell your own branded products")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $merchEnabled)
                        .labelsHidden()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Stats Overview
                HStack(spacing: 12) {
                    StatBox(title: "Products", value: "\(products.count)", icon: "bag.fill", color: .orange)
                    StatBox(title: "Orders", value: "342", icon: "shippingbox.fill", color: .blue)
                    StatBox(title: "Revenue", value: "$8.2K", icon: "dollarsign.circle.fill", color: .green)
                }
                
                // Products List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your Products")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button(action: { showingAddProduct = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Product")
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    
                    ForEach(products) { product in
                        MerchProductCard(product: product)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Integration Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Powered by MyChannel Merch")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("We handle everything:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "printer.fill", text: "Print on demand manufacturing")
                        FeatureRow(icon: "shippingbox.fill", text: "Worldwide shipping & fulfillment")
                        FeatureRow(icon: "creditcard.fill", text: "Secure payment processing")
                        FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Easy returns & exchanges")
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Merchandise")
    }
}

struct MerchProduct: Identifiable {
    let id = UUID()
    var name: String
    var price: Double
    var stock: Int
    var image: String
    var category: String
}

struct MerchProductCard: View {
    let product: MerchProduct
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: product.image)
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .frame(width: 60, height: 60)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 12) {
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(product.stock) in stock")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Text(product.category)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}

struct DonationMonetizationView: View {
    @State private var superChatEnabled = true
    @State private var minDonation = 1.0
    @State private var recentDonations: [Donation] = [
        Donation(username: "BigFan123", amount: 50.00, message: "Love your content! Keep it up! 🔥", timestamp: Date()),
        Donation(username: "CreatorSupport", amount: 100.00, message: "You're inspiring!", timestamp: Date().addingTimeInterval(-3600)),
        Donation(username: "TrueFan", amount: 25.00, message: "Been watching since day 1!", timestamp: Date().addingTimeInterval(-7200))
    ]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Super Chat & Tips")
                            .font(.system(size: 22, weight: .bold))
                        Text("Let viewers support you during live streams")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $superChatEnabled)
                        .labelsHidden()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Stats Overview
                HStack(spacing: 12) {
                    StatBox(title: "Today", value: "$425", icon: "heart.fill", color: .pink)
                    StatBox(title: "This Week", value: "$2.1K", icon: "calendar", color: .blue)
                    StatBox(title: "All Time", value: "$18.5K", icon: "chart.line.uptrend.xyaxis", color: .green)
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Minimum Donation")
                                .font(.system(size: 14, weight: .medium))
                            Text("Set the minimum amount viewers can donate")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("Amount", value: $minDonation, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Recent Donations
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Super Chats")
                        .font(.system(size: 18, weight: .semibold))
                    
                    ForEach(recentDonations) { donation in
                        DonationCard(donation: donation)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Revenue Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("💵 Your Cut")
                        .font(.system(size: 18, weight: .bold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You keep")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("90%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.pink)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("MyChannel + Processing")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("10%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Best revenue share in the industry")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Super Chat")
    }
}

struct Donation: Identifiable {
    let id = UUID()
    var username: String
    var amount: Double
    var message: String
    var timestamp: Date
}

struct DonationCard: View {
    let donation: Donation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(amountColor(for: donation.amount).gradient)
                    .frame(width: 8, height: 8)
                
                Text(donation.username)
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                Text("$\(String(format: "%.2f", donation.amount))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(amountColor(for: donation.amount))
            }
            
            Text(donation.message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text(timeAgo(from: donation.timestamp))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(amountColor(for: donation.amount).opacity(0.1))
        )
    }
    
    private func amountColor(for amount: Double) -> Color {
        if amount >= 100 { return .purple }
        else if amount >= 50 { return .pink }
        else if amount >= 10 { return .orange }
        else { return .blue }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

struct RevenueAnalyticsView: View {
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    @State private var selectedPeriod: RevenuePeriod = .month
    
    enum RevenuePeriod: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case year = "12 Months"
        case allTime = "All Time"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Period Selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(RevenuePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Total Revenue Card
                VStack(spacing: 12) {
                    Text("Total Revenue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("$\(String(format: "%.2f", analyticsService.estimatedRevenue))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("+\(String(format: "%.1f", analyticsService.revenueGrowth))% from last period")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Revenue Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("Revenue by Source")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal)
                    
                    let breakdown = getRevenueBreakdown()
                    
                    ForEach(breakdown, id: \.source) { item in
                        MonetizationRevenueSourceRow(
                            icon: item.icon,
                            source: item.source,
                            amount: item.amount,
                            percentage: item.percentage,
                            color: item.color
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Top Performing Videos
                VStack(alignment: .leading, spacing: 16) {
                    Text("Top Earning Videos")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal)
                    
                    ForEach(0..<3, id: \.self) { index in
                        MonetizationTopEarningVideoRow(
                            rank: index + 1,
                            title: "Video Title \(index + 1)",
                            revenue: Double.random(in: 100...1000),
                            views: Int.random(in: 10000...100000)
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Payout Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("💳 Next Payout")
                        .font(.system(size: 18, weight: .bold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Balance")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("$2,847.50")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Payout Date")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("Dec 15")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {}) {
                        Text("Request Early Payout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue.gradient)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Revenue Analytics")
    }
    
    private func getRevenueBreakdown() -> [RevenueBreakdownItem] {
        return [
            RevenueBreakdownItem(source: "Ads", amount: 1234.56, percentage: 45, icon: "play.rectangle.fill", color: .red),
            RevenueBreakdownItem(source: "Memberships", amount: 987.50, percentage: 35, icon: "person.badge.plus.fill", color: .blue),
            RevenueBreakdownItem(source: "Super Chat", amount: 425.00, percentage: 15, icon: "heart.fill", color: .pink),
            RevenueBreakdownItem(source: "Merchandise", amount: 200.44, percentage: 5, icon: "bag.fill", color: .orange)
        ]
    }
}

struct RevenueBreakdownItem {
    let source: String
    let amount: Double
    let percentage: Int
    let icon: String
    let color: Color
}

struct MonetizationRevenueSourceRow: View {
    let icon: String
    let source: String
    let amount: Double
    let percentage: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source)
                    .font(.system(size: 16, weight: .semibold))
                
                ProgressView(value: Double(percentage), total: 100)
                    .tint(color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", amount))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                
                Text("\(percentage)%")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MonetizationTopEarningVideoRow: View {
    let rank: Int
    let title: String
    let revenue: Double
    let views: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                
                Text("\(views.formatted()) views")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(String(format: "%.2f", revenue))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

struct AdPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Ad Preview")
                    .font(.title)
                
                Text("This is how ads will appear in your videos")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Ad Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// StudioSettingsView now in separate file: MyChannel/Features/Studio/Views/StudioSettingsView.swift

struct AIToolsStudioView: View {
    var body: some View {
        AICoCreatorView()
            .navigationTitle("AI Tools")
    }
}

// MARK: - Mobile Quick Tabs Extension
extension ComprehensiveCreatorStudioView {
    // 🔥 MOBILE QUICK TABS: Bottom navigation for most important sections
    private var mobileQuickTabs: some View {
        HStack(spacing: 0) {
            // Dashboard
            Button(action: { 
                selectedTab = .dashboard
                HapticManager.shared.impact(style: .light)
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == .dashboard ? "chart.bar.fill" : "chart.bar")
                        .font(.system(size: 20, weight: .medium))
                    Text("Dashboard")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(selectedTab == .dashboard ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
            
            // Analytics
            Button(action: { 
                selectedTab = .analytics
                HapticManager.shared.impact(style: .light)
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == .analytics ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20, weight: .medium))
                    Text("Analytics")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(selectedTab == .analytics ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
            
            // Content
            Button(action: { 
                selectedTab = .content
                HapticManager.shared.impact(style: .light)
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == .content ? "play.rectangle.fill" : "play.rectangle")
                        .font(.system(size: 20, weight: .medium))
                    Text("Content")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(selectedTab == .content ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
            
            // Earnings
            Button(action: { 
                selectedTab = .earnings
                HapticManager.shared.impact(style: .light)
            }) {
                VStack(spacing: 4) {
                    Image(systemName: selectedTab == .earnings ? "dollarsign.circle.fill" : "dollarsign.circle")
                        .font(.system(size: 20, weight: .medium))
                    Text("Earnings")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(selectedTab == .earnings ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
            
            // More (Menu)
            Menu {
                ForEach([StudioTab.customization, .community, .premieres, .live, .flicks, .playlists, .copyright, .monetization, .settings], id: \.self) { tab in
                    Button(action: { 
                        selectedTab = tab
                        HapticManager.shared.impact(style: .light)
                    }) {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                    Text("More")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
        .overlay(
            Rectangle()
                .fill(AppTheme.Colors.divider.opacity(0.3))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

// MARK: - StudioQuickActionButton Component

struct StudioQuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ComprehensiveCreatorStudioView()
        .environmentObject(AppState())
}
