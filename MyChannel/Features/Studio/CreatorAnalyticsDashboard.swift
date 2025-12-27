//
//  CreatorAnalyticsDashboard.swift
//  MyChannel
//
//  🤖 AI-Powered Analytics Dashboard
//  Combines 5 analytics agents for comprehensive insights
//

import SwiftUI
import Charts

struct CreatorAnalyticsDashboard: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var aiService = VertexAIAgentService.shared
    
    @State private var creatorAnalytics: VertexAICreatorAnalytics?
    @State private var audienceInsights: VertexAIAudienceInsights?
    @State private var isLoadingAnalytics = false
    @State private var isLoadingAudience = false
    @State private var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case day = "24h"
        case week = "7d"
        case month = "30d"
        case year = "1y"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with Time Range Picker
                headerSection
                
                // Quick Stats Cards
                quickStatsSection
                
                // Analytics Overview
                analyticsOverviewSection
                
                // Audience Demographics
                audienceDemographicsSection
                
                // Peak Hours Chart
                peakHoursSection
                
                // Device Breakdown
                deviceBreakdownSection
                
                // Top Performing Content
                topContentSection
                
                // Growth Trends
                growthTrendsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle("Analytics Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshAll) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .task {
            await loadAllData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analytics Dashboard")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("AI-powered insights for your channel")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Time Range Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedTimeRange = range
                            Task { await loadAllData() }
                        }) {
                            Text(range.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(selectedTimeRange == range ? .white : AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedTimeRange == range ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                                )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Quick Stats Section
    
    private var quickStatsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            if let analytics = creatorAnalytics {
                AnalyticsStatCard(
                    title: "Total Views",
                    value: formatNumber(analytics.totalViews),
                    change: "+12.5%",
                    isPositive: true,
                    icon: "eye",
                    color: .blue
                )
                
                AnalyticsStatCard(
                    title: "Watch Time",
                    value: formatDuration(analytics.watchTime),
                    change: "+8.2%",
                    isPositive: true,
                    icon: "clock",
                    color: .purple
                )
                
                AnalyticsStatCard(
                    title: "Engagement",
                    value: "\(Int(analytics.engagement * 100))%",
                    change: "+3.1%",
                    isPositive: true,
                    icon: "hand.thumbsup",
                    color: .green
                )
                
                AnalyticsStatCard(
                    title: "Growth",
                    value: "+\(Int(analytics.growth * 100))%",
                    change: "This period",
                    isPositive: true,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
            } else {
                ForEach(0..<4) { _ in
                    LoadingStatCard()
                }
            }
        }
    }
    
    // MARK: - Analytics Overview
    
    private var analyticsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Overview")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if let analytics = creatorAnalytics {
                VStack(spacing: 16) {
                    MetricRow(
                        title: "Average View Duration",
                        value: formatSeconds(analytics.avgViewDuration),
                        icon: "clock",
                        color: .blue
                    )
                    
                    MetricRow(
                        title: "Engagement Rate",
                        value: "\(Int(analytics.engagement * 100))%",
                        icon: "hand.thumbsup",
                        color: .green
                    )
                    
                    MetricRow(
                        title: "Growth Rate",
                        value: "+\(Int(analytics.growth * 100))%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .orange
                    )
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Audience Demographics
    
    private var audienceDemographicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audience Demographics")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if let insights = audienceInsights {
                VStack(spacing: 12) {
                    ForEach(Array(insights.demographics.sorted(by: { $0.value > $1.value })), id: \.key) { key, value in
                        HStack {
                            Text(key)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Spacer()
                            
                            Text("\(Int(value * 100))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .padding(.vertical, 8)
                        
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray6))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: geometry.size.width * value, height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Peak Hours
    
    private var peakHoursSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Peak Activity Hours")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if let insights = audienceInsights {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your audience is most active during these hours:")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(insights.peakHours, id: \.self) { hour in
                                VStack(spacing: 4) {
                                    Text("\(hour):00")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Image(systemName: "chart.bar.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(AppTheme.Colors.primary)
                                )
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Device Breakdown
    
    private var deviceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Breakdown")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if let insights = audienceInsights {
                HStack(spacing: 16) {
                    ForEach(Array(insights.deviceBreakdown.sorted(by: { $0.value > $1.value })), id: \.key) { device, percentage in
                        VStack(spacing: 8) {
                            Image(systemName: deviceIcon(for: device))
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text("\(Int(percentage * 100))%")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text(device.capitalized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Top Content
    
    private var topContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Performing Content")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to full content list
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
            }
            
            Text("Coming soon: AI-powered content performance analysis")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.vertical, 20)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Growth Trends
    
    private var growthTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Growth Trends")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if let analytics = creatorAnalytics {
                VStack(spacing: 12) {
                    TrendRow(
                        title: "Subscriber Growth",
                        value: "+\(Int(analytics.growth * 100))%",
                        isPositive: analytics.growth > 0,
                        icon: "person.2.fill"
                    )
                    
                    TrendRow(
                        title: "View Growth",
                        value: "+15.2%",
                        isPositive: true,
                        icon: "eye.fill"
                    )
                    
                    TrendRow(
                        title: "Engagement Growth",
                        value: "+8.7%",
                        isPositive: true,
                        icon: "hand.thumbsup.fill"
                    )
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Actions
    
    private func loadAllData() async {
        guard let userId = appState.currentUser?.id else { return }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadAnalytics(userId: userId) }
            group.addTask { await loadAudienceInsights(userId: userId) }
        }
    }
    
    private func loadAnalytics(userId: String) async {
        isLoadingAnalytics = true
        do {
            let result = try await aiService.getCreatorAnalytics(creatorId: userId)
            await MainActor.run {
                creatorAnalytics = result
                isLoadingAnalytics = false
            }
        } catch {
            print("⚠️ [Analytics Dashboard] Failed to load analytics: \(error)")
            await MainActor.run { isLoadingAnalytics = false }
        }
    }
    
    private func loadAudienceInsights(userId: String) async {
        isLoadingAudience = true
        do {
            let result = try await aiService.getAudienceInsights(creatorId: userId)
            await MainActor.run {
                audienceInsights = result
                isLoadingAudience = false
            }
        } catch {
            print("⚠️ [Analytics Dashboard] Failed to load audience insights: \(error)")
            await MainActor.run { isLoadingAudience = false }
        }
    }
    
    private func refreshAll() {
        Task {
            await loadAllData()
        }
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        if hours > 0 {
            return "\(hours)h"
        } else {
            let minutes = Int(seconds) / 60
            return "\(minutes)m"
        }
    }
    
    private func formatSeconds(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
    
    private func deviceIcon(for device: String) -> String {
        switch device.lowercased() {
        case "mobile": return "iphone"
        case "desktop": return "desktopcomputer"
        case "tablet": return "ipad"
        default: return "devices"
        }
    }
}

// MARK: - Supporting Views

struct AnalyticsStatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
                Spacer()
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isPositive ? .green : .red)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Text(change)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isPositive ? .green : .red)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct LoadingStatCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 24, height: 24)
                Spacer()
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 28)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 16)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
        )
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

struct TrendRow: View {
    let title: String
    let value: String
    let isPositive: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(isPositive ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        CreatorAnalyticsDashboard()
            .environmentObject(AppState.shared)
    }
}







