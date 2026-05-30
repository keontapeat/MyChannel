import SwiftUI
import AVKit
import Combine

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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCreatorStudio"))) { _ in
            Task { await loadDashboardData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))) { _ in
            Task { await loadDashboardData() }
        }
    }
    
    private func loadDashboardData() async {
        // 🔥 REAL DATA: Load recent videos from Firestore
        guard let creatorId = AppState.shared.currentUser?.id else {
            print("⚠️ [StudioDashboardView] No current user - cannot load dashboard data")
            return
        }
        
        print("📊 [StudioDashboardView] Loading dashboard data for creator: \(creatorId)")
        
        // Load creator's videos from Firestore (sorted by upload date, limit 10)
        let fetchedVideos = await VideoFirestoreService.shared.fetchVideosByCreator(creatorId: creatorId, limit: 10)
        
        await MainActor.run {
            self.recentVideos = fetchedVideos
            print("✅ [StudioDashboardView] Loaded \(fetchedVideos.count) recent videos")
        }
        
        // Load channel analytics
        do {
            _ = try await analyticsService.getChannelAnalytics(for: creatorId, timeframe: .last30Days)
            print("✅ [StudioDashboardView] Channel analytics loaded")
        } catch {
            print("⚠️ [StudioDashboardView] Failed to load channel analytics: \(error)")
        }
        
        // Start real-time monitoring for instant analytics updates
        await analyticsService.startRealtimeMonitoring(for: creatorId)
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

    private func analyticsMetricRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
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

            VStack(spacing: 12) {
                analyticsMetricRow(
                    title: "Views",
                    value: formatNumber(analyticsService.channelAnalytics?.totalViews ?? 0),
                    icon: "eye.fill"
                )
                analyticsMetricRow(
                    title: "Subscribers",
                    value: formatNumber(analyticsService.channelAnalytics?.totalSubscribers ?? 0),
                    icon: "person.2.fill"
                )
                analyticsMetricRow(
                    title: "Revenue",
                    value: "$\(String(format: "%.2f", analyticsService.channelAnalytics?.totalRevenue ?? 0))",
                    icon: "dollarsign.circle.fill"
                )
                analyticsMetricRow(
                    title: "Recent uploads",
                    value: "\(recentVideos.count)",
                    icon: "play.rectangle.fill"
                )
            }
            .padding(16)
            .background(AppTheme.Colors.background)
            .cornerRadius(8)
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
                StudioInsightCard(
                    icon: "clock",
                    title: "Best Upload Time",
                    value: "2:00 PM EST",
                    subtitle: "78% audience active"
                )
                
                StudioInsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Growth Trend",
                    value: "+24%",
                    subtitle: "Last 30 days"
                )
                
                StudioInsightCard(
                    icon: "eye",
                    title: "Avg. View Duration",
                    value: "8:42",
                    subtitle: "12% above average"
                )
                
                StudioInsightCard(
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


struct StudioInsightCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.Colors.primary)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
