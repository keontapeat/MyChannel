//
//  CompetitorAnalyzerView.swift
//  MyChannel
//
//  AI COMPETITOR ANALYZER - Know exactly what's working for your competitors
//  Stay ahead of the competition with AI insights
//  Created for MyChannel by AI Assistant
//

import SwiftUI

struct CompetitorAnalyzerView: View {
    @StateObject private var viewModel = CompetitorAnalyzerViewModel()
    @State private var searchText = ""
    @State private var selectedCompetitor: CompetitorChannel?
    @State private var showAddCompetitor = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        analyzerHero
                        
                        // Your Performance vs Competitors
                        performanceComparisonSection
                        
                        // Tracked Competitors
                        trackedCompetitorsSection
                        
                        // Trending Strategies
                        trendingStrategiesSection
                        
                        // Content Gap Analysis
                        contentGapSection
                        
                        // AI Insights
                        aiInsightsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Competitor Analyzer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddCompetitor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddCompetitor) {
            AddCompetitorSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedCompetitor) { competitor in
            CompetitorDetailSheet(competitor: competitor)
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
    }
    
    // MARK: - Hero Section
    private var analyzerHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.5, blue: 0.9),
                            Color(red: 0.3, green: 0.2, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 30, weight: .bold))
                    Text("Competitor Intel")
                        .font(.system(size: 26, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Know what's working for your competition")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "brain.head.profile", text: "AI Insights")
                    featureBadge(icon: "chart.line.uptrend.xyaxis", text: "Real-Time")
                    featureBadge(icon: "target", text: "Actionable")
                }
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - Performance Comparison
    private var performanceComparisonSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Performance vs Competition")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 14) {
                PerformanceMetricRow(
                    label: "Avg Views per Video",
                    yourValue: viewModel.metrics.yourAvgViews,
                    competitorAvg: viewModel.metrics.competitorAvgViews,
                    isHigherBetter: true
                )
                
                PerformanceMetricRow(
                    label: "Engagement Rate",
                    yourValue: viewModel.metrics.yourEngagementRate,
                    competitorAvg: viewModel.metrics.competitorEngagementRate,
                    isHigherBetter: true
                )
                
                PerformanceMetricRow(
                    label: "Upload Frequency",
                    yourValue: viewModel.metrics.yourUploadFreq,
                    competitorAvg: viewModel.metrics.competitorUploadFreq,
                    isHigherBetter: true
                )
                
                PerformanceMetricRow(
                    label: "Subscriber Growth",
                    yourValue: viewModel.metrics.yourSubGrowth,
                    competitorAvg: viewModel.metrics.competitorSubGrowth,
                    isHigherBetter: true
                )
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Tracked Competitors
    private var trackedCompetitorsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Tracked Competitors")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.competitors.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            if viewModel.competitors.isEmpty {
                EmptyCompetitorsView()
            } else {
                ForEach(viewModel.competitors) { competitor in
                    CompetitorCard(competitor: competitor) {
                        selectedCompetitor = competitor
                    }
                }
            }
        }
    }
    
    // MARK: - Trending Strategies
    private var trendingStrategiesSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text("What's Working Right Now")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ForEach(viewModel.trendingStrategies, id: \.title) { strategy in
                StrategyCard(strategy: strategy)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Content Gap Analysis
    private var contentGapSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Content Opportunities")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            Text("Topics your competitors are covering that you're not")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(viewModel.contentGaps, id: \.topic) { gap in
                ContentGapCard(gap: gap)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - AI Insights
    private var aiInsightsSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.purple)
                    
                    Text("AI Recommendations")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ForEach(viewModel.aiInsights, id: \.title) { insight in
                AIInsightCard(insight: insight)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct PerformanceMetricRow: View {
    let label: String
    let yourValue: String
    let competitorAvg: String
    let isHigherBetter: Bool
    
    var isWinning: Bool {
        // Simple comparison - in real app, parse numbers properly
        return (yourValue > competitorAvg) == isHigherBetter
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(yourValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isWinning ? .green : .orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: isWinning ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isWinning ? .green : .orange)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Competitors")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(competitorAvg)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CompetitorCard: View {
    let competitor: CompetitorChannel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                AsyncImage(url: URL(string: competitor.avatarURL)) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(AppTheme.Colors.cardBackground)
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(competitor.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11))
                            Text(competitor.subscribers)
                                .font(.system(size: 13))
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                            Text(competitor.growth)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(competitor.growth.hasPrefix("+") ? .green : .red)
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(competitor.recentVideos)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("videos/week")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(14)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct EmptyCompetitorsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No competitors tracked")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Add competitors to get AI insights on what's working")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct StrategyCard: View {
    let strategy: TrendingStrategy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                
                Text(strategy.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("+\(strategy.avgGrowth)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Text(strategy.description)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            HStack {
                Text("\(strategy.competitorsUsing) competitors using this")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Button {
                    // Try this strategy
                } label: {
                    Text("Try This")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ContentGapCard: View {
    let gap: ContentGap
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(gap.topic)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("\(gap.competitorsCovering) competitors covering this")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 11))
                    Text("Est. \(gap.potentialViews) views")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.green)
            }
            
            Spacer()
            
            Button {
                // Create content
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AIInsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.purple)
                
                Text(insight.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(insight.priority.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(priorityColor(insight.priority))
                    .clipShape(Capsule())
            }
            
            Text(insight.description)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            if !insight.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Action Items:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    ForEach(insight.actionItems, id: \.self) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .blue
        default: return .gray
        }
    }
}

// MARK: - Add Competitor Sheet
struct AddCompetitorSheet: View {
    @ObservedObject var viewModel: CompetitorAnalyzerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Search for a channel to track")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                TextField("Channel name or URL", text: $searchText)
                    .font(.system(size: 16))
                    .padding(14)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding(24)
            .background(AppTheme.Colors.background)
            .navigationTitle("Add Competitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        dismiss()
                    }
                    .disabled(searchText.isEmpty)
                }
            }
        }
    }
}

// MARK: - Competitor Detail Sheet
struct CompetitorDetailSheet: View {
    let competitor: CompetitorChannel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Detailed analytics for \(competitor.name)")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    // Full analytics will go here
                }
                .padding(24)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(competitor.name)
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

#Preview {
    CompetitorAnalyzerView()
}

