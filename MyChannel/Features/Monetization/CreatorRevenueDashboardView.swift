//
//  CreatorRevenueDashboardView.swift
//  MyChannel
//
//  CREATOR REVENUE DASHBOARD
//  Real-time earnings, 90% revenue share, transparent analytics
//

import SwiftUI
import Charts

struct CreatorRevenueDashboardView: View {
    @StateObject private var viewModel = CreatorRevenueViewModel()
    @State private var selectedPeriod: TimePeriod = .month
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Total Earnings Header
                totalEarningsCard
                
                // Quick Stats
                quickStatsGrid
                
                // AI Insights
                aiInsightsCard
                
                // Revenue Breakdown
                revenueBreakdownCard
                
                // Top Performing Videos
                topVideosSection
                
                // Payout Status
                payoutStatusCard
            }
            .padding(20)
        }
        .navigationTitle("Revenue Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
    }
    
    // MARK: - Total Earnings
    
    private var totalEarningsCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Earnings")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("$\(viewModel.totalEarnings, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("This Month")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.monthGrowth >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12))
                        Text("\(abs(viewModel.monthGrowth), specifier: "%.1f")%")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(viewModel.monthGrowth >= 0 ? .green : .red)
                }
            }
            
            // Revenue Chart
            earningsChartView
            
            // Period Selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }
    
    private var earningsChartView: some View {
        Chart {
            ForEach(viewModel.earningsData) { dataPoint in
                LineMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Earnings", dataPoint.amount)
                )
                .foregroundStyle(Color.green)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Earnings", dataPoint.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green.opacity(0.3), Color.green.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text("$\(Int(amount))")
                    }
                }
            }
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("CPM", value: String(format: "$%.2f", viewModel.avgCPM), icon: "dollarsign.circle.fill", color: .blue)
            statCard("Fill Rate", value: "\(Int(viewModel.fillRate * 100))%", icon: "chart.line.uptrend.xyaxis", color: .green)
            statCard("Impressions", value: viewModel.formattedImpressions, icon: "eye.fill", color: .purple)
            statCard("Revenue Share", value: "90%", icon: "percent", color: .orange)
        }
    }
    
    private func statCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - AI Insights
    
    private var aiInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Insights")
                    .font(.system(size: 18, weight: .semibold))
            }
            
            ForEach(viewModel.aiInsights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    Text(insight)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Revenue Breakdown
    
    private var revenueBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Revenue Breakdown")
                .font(.system(size: 18, weight: .semibold))
            
            VStack(spacing: 12) {
                revenueRow("Pre-roll Ads", amount: viewModel.prerollRevenue, total: viewModel.totalEarnings)
                revenueRow("Mid-roll Ads", amount: viewModel.midrollRevenue, total: viewModel.totalEarnings)
                revenueRow("Post-roll Ads", amount: viewModel.postrollRevenue, total: viewModel.totalEarnings)
                revenueRow("Display Ads", amount: viewModel.displayRevenue, total: viewModel.totalEarnings)
                revenueRow("Native Ads", amount: viewModel.nativeRevenue, total: viewModel.totalEarnings)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }
    
    private func revenueRow(_ title: String, amount: Double, total: Double) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(amount, specifier: "%.2f")")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("\(Int((amount / total) * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geometry.size.width * (amount / total), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Top Videos
    
    private var topVideosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Performing Videos")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                Button("See All") {
                    // Navigate to full list
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
            }
            
            ForEach(viewModel.topVideos) { video in
                topVideoCard(video)
            }
        }
    }
    
    private func topVideoCard(_ video: VideoPerformance) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 68)
                .overlay(
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                )
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(video.views)", systemImage: "eye.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Label("$\(video.revenue, specifier: "%.2f")", systemImage: "dollarsign.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Payout Status
    
    private var payoutStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "banknote.fill")
                    .foregroundColor(.green)
                Text("Next Payout")
                    .font(.system(size: 18, weight: .semibold))
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("$\(viewModel.nextPayoutAmount, specifier: "%.2f")")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Date")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(viewModel.nextPayoutDate, style: .date)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            
            Button(action: {
                // Navigate to payout settings
            }) {
                Text("Payout Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        )
    }
}

// MARK: - View Model

@MainActor
class CreatorRevenueViewModel: ObservableObject {
    @Published var totalEarnings: Double = 0
    @Published var monthGrowth: Double = 0
    @Published var avgCPM: Double = 0
    @Published var fillRate: Double = 0
    @Published var impressions: Int = 0
    @Published var earningsData: [EarningsDataPoint] = []
    @Published var aiInsights: [String] = []
    @Published var prerollRevenue: Double = 0
    @Published var midrollRevenue: Double = 0
    @Published var postrollRevenue: Double = 0
    @Published var displayRevenue: Double = 0
    @Published var nativeRevenue: Double = 0
    @Published var topVideos: [VideoPerformance] = []
    @Published var nextPayoutAmount: Double = 0
    @Published var nextPayoutDate: Date = Date()
    
    var formattedImpressions: String {
        if impressions >= 1_000_000 {
            return String(format: "%.1fM", Double(impressions) / 1_000_000)
        } else if impressions >= 1_000 {
            return String(format: "%.1fK", Double(impressions) / 1_000)
        }
        return "\(impressions)"
    }
    
    func loadData() async {
        // Simulate loading real-time data
        totalEarnings = 5_247.83
        monthGrowth = 32.5
        avgCPM = 8.45
        fillRate = 0.94
        impressions = 625_000
        
        // Generate earnings data for chart
        var data: [EarningsDataPoint] = []
        let calendar = Calendar.current
        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let amount = Double.random(in: 120...250)
            data.append(EarningsDataPoint(date: date, amount: amount, source: nil))
        }
        earningsData = data.reversed()
        
        // AI Insights
        aiInsights = [
            "Upload at 6pm EST for 30% more views and higher CPMs",
            "Gaming content performing 2x better than average",
            "Your fill rate increased 15% this week - great content!"
        ]
        
        // Revenue breakdown
        prerollRevenue = 2_100.50
        midrollRevenue = 1_850.25
        postrollRevenue = 650.00
        displayRevenue = 420.58
        nativeRevenue = 226.50
        
        // Top videos
        topVideos = [
            VideoPerformance(title: "Epic Gaming Montage 2024", views: 125_000, revenue: 1_250.00),
            VideoPerformance(title: "How I Built My Channel", views: 98_000, revenue: 980.00),
            VideoPerformance(title: "Best Moments Compilation", views: 75_000, revenue: 750.00)
        ]
        
        // Next payout
        nextPayoutAmount = 5_247.83
        nextPayoutDate = calendar.date(byAdding: .day, value: 15, to: Date())!
    }
}

// MARK: - Models

struct VideoPerformance: Identifiable {
    let id = UUID()
    let title: String
    let views: Int
    let revenue: Double
}

#Preview {
    NavigationView {
        CreatorRevenueDashboardView()
    }
}

