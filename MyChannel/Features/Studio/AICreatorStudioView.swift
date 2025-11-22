//
//  AICreatorStudioView.swift
//  MyChannel
//
//  🤖 AI Creator Studio - Your AI-powered content assistant
//  Combines Viral Predictor, Creator Coach, and Analytics AI
//

import SwiftUI

struct AICreatorStudioView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var aiService = VertexAIAgentService.shared
    
    @State private var viralPrediction: VertexAIViralPrediction?
    @State private var creatorCoaching: CoachingResponse?
    @State private var analytics: VertexAICreatorAnalytics?
    @State private var audienceInsights: VertexAIAudienceInsights?
    
    @State private var isLoadingViral = false
    @State private var isLoadingCoach = false
    @State private var isLoadingAnalytics = false
    @State private var isLoadingAudience = false
    
    @State private var videoTitle = ""
    @State private var videoCategory = "Entertainment"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Viral Predictor Section
                viralPredictorSection
                
                // Creator Coach Section
                creatorCoachSection
                
                // Analytics Insights Section
                analyticsSection
                
                // Audience Insights Section
                audienceInsightsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle("AI Creator Studio")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadInitialData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Creator Studio")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Your AI-powered content assistant")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            Text("Get AI-powered insights to optimize your content, grow your audience, and increase engagement.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(3)
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
    
    // MARK: - Viral Predictor Section
    
    private var viralPredictorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.purple)
                
                Text("Viral Predictor")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            // Input section
            VStack(spacing: 12) {
                TextField("Video title", text: $videoTitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                
                HStack(spacing: 12) {
                    Text("Category:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Picker("Category", selection: $videoCategory) {
                        Text("Entertainment").tag("Entertainment")
                        Text("Gaming").tag("Gaming")
                        Text("Music").tag("Music")
                        Text("Education").tag("Education")
                        Text("Tech").tag("Tech")
                    }
                    .pickerStyle(.menu)
                    
                    Spacer()
                }
                
                Button(action: predictViral) {
                    HStack(spacing: 8) {
                        if isLoadingViral {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isLoadingViral ? "Predicting..." : "Predict Viral Score")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primary)
                    )
                }
                .disabled(videoTitle.isEmpty || isLoadingViral)
            }
            
            // Viral Prediction Result (use ViralPredictorCard if available)
            if let prediction = viralPrediction {
                ViralPredictorCard(
                    videoTitle: "My Video",
                    videoCategory: "Gaming",
                    creatorStats: CreatorStats(
                        avgViews: 10000,
                        avgWatchTime: 0.65,
                        bestPostingTime: "6 PM"
                    )
                )
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
    
    // MARK: - Creator Coach Section
    
    private var creatorCoachSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.badge.shield.checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.green)
                
                Text("Creator Coach")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: loadCreatorCoaching) {
                    HStack(spacing: 4) {
                        if isLoadingCoach {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoadingCoach ? "Loading..." : "Refresh")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if let coaching = creatorCoaching {
                VStack(spacing: 12) {
                    ForEach(coaching.tips.prefix(3), id: \.self) { tip in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.yellow)
                            
                            Text(tip)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Spacer()
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.5))
                    
                    Text("Get personalized coaching tips")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("Tap refresh to load AI-powered coaching")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
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
    
    // MARK: - Analytics Section
    
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("Analytics Insights")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: loadAnalytics) {
                    HStack(spacing: 4) {
                        if isLoadingAnalytics {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoadingAnalytics ? "Loading..." : "Refresh")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if let analytics = analytics {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    AnalyticsStatCard(
                        title: "Total Views",
                        value: formatNumber(analytics.totalViews),
                        icon: "eye",
                        color: .blue
                    )
                    
                    AnalyticsStatCard(
                        title: "Watch Time",
                        value: formatDuration(analytics.watchTime),
                        icon: "clock",
                        color: .purple
                    )
                    
                    AnalyticsStatCard(
                        title: "Engagement",
                        value: "\(Int(analytics.engagement * 100))%",
                        icon: "hand.thumbsup",
                        color: .green
                    )
                    
                    AnalyticsStatCard(
                        title: "Growth",
                        value: "+\(Int(analytics.growth * 100))%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .orange
                    )
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.5))
                    
                    Text("Loading analytics insights...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
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
    
    // MARK: - Audience Insights Section
    
    private var audienceInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.indigo)
                
                Text("Audience Insights")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Button(action: loadAudienceInsights) {
                    HStack(spacing: 4) {
                        if isLoadingAudience {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoadingAudience ? "Loading..." : "Refresh")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            if let insights = audienceInsights {
                VStack(spacing: 16) {
                    // Top Countries
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Countries")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: 8) {
                            ForEach(insights.topCountries.prefix(3), id: \.self) { country in
                                Text(country)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray6))
                                    )
                            }
                        }
                    }
                    
                    // Peak Hours
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Peak Hours")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: 8) {
                            ForEach(insights.peakHours.prefix(3), id: \.self) { hour in
                                Text("\(hour):00")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray6))
                                    )
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.5))
                    
                    Text("Loading audience insights...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
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
    
    private func loadInitialData() async {
        guard let userId = appState.currentUser?.id else { return }
        
        await loadAnalytics()
        await loadAudienceInsights()
        await loadCreatorCoaching()
    }
    
    private func predictViral() {
        guard !videoTitle.isEmpty else { return }
        
        isLoadingViral = true
        Task {
            do {
                let prediction = try await aiService.predictViralScore(
                    videoTitle: videoTitle,
                    category: videoCategory
                )
                await MainActor.run {
                    viralPrediction = prediction
                    isLoadingViral = false
                }
            } catch {
                print("⚠️ [AI Creator Studio] Viral prediction failed: \(error)")
                await MainActor.run {
                    isLoadingViral = false
                }
            }
        }
    }
    
    private func loadCreatorCoaching() {
        guard let userId = appState.currentUser?.id else { return }
        
        isLoadingCoach = true
        Task {
            do {
                let metadata = VertexVideoMetadata(
                    title: "Sample Video",
                    description: "Sample description",
                    category: "Gaming",
                    duration: 300
                )
                
                let stats = CreatorStats(
                    avgViews: 10000,
                    avgWatchTime: 0.65,
                    bestPostingTime: "6 PM"
                )
                
                let coaching = try await aiService.getCreatorCoaching(
                    for: userId,
                    videoMetadata: metadata,
                    pastPerformance: stats
                )
                await MainActor.run {
                    creatorCoaching = coaching
                    isLoadingCoach = false
                }
            } catch {
                print("⚠️ [AI Creator Studio] Creator coaching failed: \(error)")
                await MainActor.run {
                    isLoadingCoach = false
                }
            }
        }
    }
    
    private func loadAnalytics() {
        guard let userId = appState.currentUser?.id else { return }
        
        isLoadingAnalytics = true
        Task {
            do {
                let result = try await aiService.getCreatorAnalytics(creatorId: userId)
                await MainActor.run {
                    analytics = result
                    isLoadingAnalytics = false
                }
            } catch {
                print("⚠️ [AI Creator Studio] Analytics failed: \(error)")
                await MainActor.run {
                    isLoadingAnalytics = false
                }
            }
        }
    }
    
    private func loadAudienceInsights() {
        guard let userId = appState.currentUser?.id else { return }
        
        isLoadingAudience = true
        Task {
            do {
                let result = try await aiService.getAudienceInsights(creatorId: userId)
                await MainActor.run {
                    audienceInsights = result
                    isLoadingAudience = false
                }
            } catch {
                print("⚠️ [AI Creator Studio] Audience insights failed: \(error)")
                await MainActor.run {
                    isLoadingAudience = false
                }
            }
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
}

// MARK: - Analytics Stat Card

struct AnalyticsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    NavigationStack {
        AICreatorStudioView()
            .environmentObject(AppState.shared)
    }
}

