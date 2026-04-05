//
//  AnalyticsDashboardView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import UIKit
import Charts

struct AnalyticsDashboardView: View {
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    @State private var selectedPeriod: AnalyticsPeriod = .last30Days
    @State private var channelAnalytics: ChannelAnalytics?
    @State private var chartData: [AnalyticsChartData] = []
    @State private var topVideos: [VideoAnalytics] = []
    @State private var videosMap: [String: Video] = []
    @State private var selectedMetric: MetricType = .views
    
    enum MetricType: String, CaseIterable {
        case views = "Views"
        case subscribers = "Subscribers"
        case revenue = "Revenue"
        case watchTime = "Watch Time"
        
        var color: Color {
            switch self {
            case .views: return .blue
            case .subscribers: return .green
            case .revenue: return .orange
            case .watchTime: return .purple
            }
        }
        
        var iconName: String {
            switch self {
            case .views: return "eye"
            case .subscribers: return "person.2"
            case .revenue: return "dollarsign.circle"
            case .watchTime: return "clock"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    periodSelectorSection
                    
                    // Overview Cards
                    overviewCardsSection
                    
                    // Analytics Chart
                    analyticsChartSection
                    
                    // Top Performing Videos
                    topVideosSection
                    
                    // Audience Demographics
                    audienceDemographicsSection
                    
                    // Revenue Breakdown
                    revenueBreakdownSection
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { exportAnalytics(as: .csv) }) { Label("Export CSV", systemImage: "square.and.arrow.up") }
                        Button(action: { exportAnalytics(as: .json) }) { Label("Export JSON", systemImage: "curlybraces.square") }
                        Button(action: { exportAnalytics(as: .pdf) }) { Label("Export PDF", systemImage: "doc.richtext") }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .refreshable {
                await loadAnalytics()
            }
        }
        .task {
            await loadAnalytics()
        }
    }
    
    private var periodSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        selectedPeriod = period
                        Task { await loadAnalytics() }
                    }) {
                        Text(period.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedPeriod == period ? Color.blue : Color(.systemGray6))
                            .foregroundColor(selectedPeriod == period ? .white : .primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.horizontal, -16)
    }
    
    private var overviewCardsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            if let analytics = channelAnalytics {
                OverviewCard(
                    title: "Total Views",
                    value: analytics.totalViews.formatted(),
                    change: "+12.5%",
                    changePositive: true,
                    icon: "eye",
                    color: .blue
                )
                
                OverviewCard(
                    title: "Subscribers", 
                    value: analytics.totalSubscribers.formatted(),
                    change: String(format: "%+.1f%%", analytics.subscriberGrowthRate),
                    changePositive: analytics.subscriberGrowthRate > 0,
                    icon: "person.2",
                    color: .green
                )
                
                OverviewCard(
                    title: "Revenue",
                    value: String(format: "$%.2f", analytics.totalRevenue),
                    change: "+8.3%",
                    changePositive: true,
                    icon: "dollarsign.circle",
                    color: .orange
                )
                
                OverviewCard(
                    title: "Watch Time",
                    value: "\(Int(analytics.watchTimeHours))h",
                    change: "+15.2%",
                    changePositive: true,
                    icon: "clock",
                    color: .purple
                )
            } else {
                // Loading placeholders
                ForEach(0..<4, id: \.self) { _ in
                    OverviewCardPlaceholder()
                }
            }
        }
    }
    
    private var analyticsChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Performance Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.menu)
            }
            
            if !chartData.isEmpty {
                Chart(chartData) { data in
                    switch selectedMetric {
                    case .views:
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("Views", data.views)
                        )
                        .foregroundStyle(selectedMetric.color)
                        
                    case .subscribers:
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("Subscribers", data.subscribers)
                        )
                        .foregroundStyle(selectedMetric.color)
                        
                    case .revenue:
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("Revenue", data.revenue)
                        )
                        .foregroundStyle(selectedMetric.color)
                        
                    case .watchTime:
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("Watch Time", data.watchTimeHours)
                        )
                        .foregroundStyle(selectedMetric.color)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        AxisGridLine()
                        AxisTick()
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                        AxisGridLine()
                        AxisTick()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        ProgressView("Loading chart...")
                    )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var topVideosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Performing Videos")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // TODO: Navigate to detailed video analytics
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if topVideos.isEmpty {
                VStack {
                    ProgressView("Loading videos...")
                    Text("Fetching your top performing content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(topVideos.prefix(5).enumerated()), id: \.element.id) { index, analytics in
                        TopVideoRow(
                            rank: index + 1,
                            analytics: analytics,
                            video: videosMap[analytics.videoId]
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var audienceDemographicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audience Demographics")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let analytics = channelAnalytics {
                VStack(spacing: 16) {
                    // Age Demographics
                    DemographicSection(
                        title: "Age Groups",
                        data: analytics.viewsByAge,
                        icon: "person.circle"
                    )
                    
                    // Gender Demographics
                    DemographicSection(
                        title: "Gender",
                        data: analytics.viewsByGender,
                        icon: "person.2.circle"
                    )
                    
                    // Top Countries
                    DemographicSection(
                        title: "Top Countries",
                        data: analytics.viewsByCountry,
                        icon: "globe"
                    )
                }
            } else {
                ProgressView("Loading demographics...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var revenueBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Revenue Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let analytics = channelAnalytics {
                VStack(spacing: 12) {
                    ForEach(analytics.revenueBySource.sorted(by: { $0.value > $1.value }), id: \.key) { source, amount in
                        RevenueSourceRow(
                            source: source,
                            amount: amount,
                            percentage: amount / analytics.totalRevenue
                        )
                    }
                }
                
                Divider()
                
                HStack {
                    Text("Total Revenue")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("$\(analytics.totalRevenue, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                HStack {
                    Text("Est. Earnings per 1K Views")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("$\(analytics.estimatedEarningsPerThousandViews, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView("Loading revenue data...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Actions
    private func loadAnalytics() async {
        guard let creatorId = AppState.shared.currentUser?.id else { return }
        do {
            let channel = try await analyticsService.getChannelAnalytics(for: creatorId)
            let videos = try await analyticsService.getVideoPerformanceAnalytics(for: creatorId)
            let sortedVideos = videos.sorted { $0.views > $1.views }
            // Fetch real video metadata for thumbnails/titles
            let videoIds = sortedVideos.prefix(10).map { $0.videoId }
            let fetchedVideos = (try? await VideoFirestoreService.shared.fetchMultipleVideos(videoIds: videoIds)) ?? []
            var vMap: [String: Video] = [:]
            for v in fetchedVideos { vMap[v.id] = v }
            await MainActor.run {
                self.channelAnalytics = channel
                self.topVideos = sortedVideos
                self.videosMap = vMap
            }
        } catch {
            print("Error loading analytics: \(error)")
        }
    }

    // MARK: - Export
    private enum ExportFormat { case csv, json, pdf }
    private func exportAnalytics(as format: ExportFormat) {
        guard let analytics = channelAnalytics else { return }
        switch format {
        case .csv:
            let headers = ["date","views","subs","revenue","watchTimeHrs"]
            let rows: [String] = ([headers.joined(separator: ",")] + chartData.map { d in
                let watchHrs = String(format: "%.2f", d.watchTimeHours)
                return "\(d.date.formatted(.dateTime.year().month().day())),\(d.views),\(d.subscribers),\(String(format: "%.2f", d.revenue)),\(watchHrs)"
            })
            shareText(rows.joined(separator: "\n"))
        case .json:
            let payload: [String: Any] = [
                "overview": [
                    "totalViews": analytics.totalViews,
                    "totalSubscribers": analytics.totalSubscribers,
                    "totalRevenue": analytics.totalRevenue
                ],
                "series": chartData.map { [
                    "date": $0.date.timeIntervalSince1970,
                    "views": $0.views,
                    "subs": $0.subscribers,
                    "revenue": $0.revenue,
                    "watchTimeHrs": $0.watchTimeHours
                ]}
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
               let json = String(data: data, encoding: .utf8) {
                shareText(json)
            }
        case .pdf:
            Task {
                struct PDFResp: Codable { let url: String }
                if let uid = AppState.shared.currentUser?.id,
                   let pdf: PDFResp = try? await NetworkService.shared.post(
                        endpoint: .custom("/analytics/export/pdf"),
                        body: payloadForPDF(creatorId: uid),
                        responseType: PDFResp.self
                   ) {
                    shareItems([pdf.url])
                }
            }
        }
    }
    private func shareText(_ text: String) {
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.presentShareSheet(av)
    }
    private func shareItems(_ items: [Any]) {
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        UIApplication.shared.presentShareSheet(av)
    }
    private func payloadForPDF(creatorId: String) -> [String: String] {
        ["creatorId": creatorId, "period": selectedPeriod.rawValue]
    }
}

// MARK: - Supporting Views
struct OverviewCard: View {
    let title: String
    let value: String
    let change: String
    let changePositive: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: changePositive ? "arrow.up" : "arrow.down")
                        .font(.caption)
                    Text(change)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(changePositive ? .green : .red)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct OverviewCardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 24, height: 24)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 12)
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 24)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 12)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TopVideoRow: View {
    let rank: Int
    let analytics: VideoAnalytics
    let video: Video?
    
    var body: some View {
        HStack {
            // Rank
            Text("\(rank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            // Thumbnail
            AsyncImage(url: URL(string: video?.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 60, height: 34)
            .cornerRadius(6)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(video?.title ?? "Unknown Video")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text("\(analytics.views.formatted()) views")
                    Text("•")
                    Text("$\(analytics.revenue, specifier: "%.2f")")
                        .foregroundColor(.green)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(analytics.engagementRate, specifier: "%.1f")%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("engagement")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct DemographicSection: View {
    let title: String
    let data: [String: Int]
    let icon: String
    
    var sortedData: [(String, Int)] {
        data.sorted { $0.value > $1.value }
    }
    
    var total: Int {
        data.values.reduce(0, +)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            VStack(spacing: 6) {
                ForEach(sortedData.prefix(5), id: \.0) { item, count in
                    HStack {
                        Text(item)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("(\(Int(Double(count) / Double(total) * 100))%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct RevenueSourceRow: View {
    let source: String
    let amount: Double
    let percentage: Double
    
    var body: some View {
        HStack {
            Text(source)
                .font(.subheadline)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(Int(percentage * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AnalyticsDashboardView()
}