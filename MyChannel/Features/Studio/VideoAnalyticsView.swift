import SwiftUI
import Charts

struct VideoAnalyticsView: View {
    let videoId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analyticsService = StudioAnalyticsService.shared
    @State private var analytics: StudioVideoAnalytics?
    @State private var isLoading = true
    @State private var selectedDateRange: DateRange = .last28Days
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Loading analytics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if let analytics = analytics {
                    LazyVStack(spacing: 24) {
                        // Overview metrics
                        OverviewMetricsSection(analytics: analytics)
                        
                        // Retention curve
                        RetentionCurveSection(analytics: analytics)
                        
                        // Traffic sources
                        TrafficSourcesSection(analytics: analytics)
                        
                        // Demographics
                        DemographicsSection(analytics: analytics)
                    }
                    .padding()
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Range", selection: $selectedDateRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                }
            }
        }
        .task {
            await loadAnalytics()
        }
        .onChange(of: selectedDateRange) { _ in
            Task { await loadAnalytics() }
        }
    }
    
    private func loadAnalytics() async {
        isLoading = true
        analytics = await analyticsService.fetchVideoAnalytics(videoId: videoId, dateRange: selectedDateRange)
        isLoading = false
    }
}

struct OverviewMetricsSection: View {
    let analytics: StudioVideoAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.title2.weight(.semibold))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                MetricCard(title: "Views", value: "\(analytics.views)", change: "+12.3%")
                MetricCard(title: "Impressions", value: "\(analytics.impressions)", change: "+5.7%")
                MetricCard(title: "CTR", value: String(format: "%.1f%%", analytics.ctr * 100), change: "-0.2%")
                MetricCard(title: "RPM", value: String(format: "$%.2f", analytics.rpm), change: "+8.1%")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let change: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2.weight(.semibold))
            
            Text(change)
                .font(.caption)
                .foregroundColor(change.hasPrefix("+") ? .green : .red)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}

struct RetentionCurveSection: View {
    let analytics: StudioVideoAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audience Retention")
                .font(.title2.weight(.semibold))
            
            if #available(iOS 16.0, *) {
                Chart(analytics.retentionCurve, id: \.timePercent) { point in
                    LineMark(
                        x: .value("Time", point.timePercent * 100),
                        y: .value("Retention", point.retentionPercent * 100)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("\(Int(intValue))%")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("\(Int(intValue))%")
                            }
                        }
                    }
                }
                .frame(height: 200)
            } else {
                Text("Retention curve visualization requires iOS 16+")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TrafficSourcesSection: View {
    let analytics: StudioVideoAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Traffic Sources")
                .font(.title2.weight(.semibold))
            
            ForEach(analytics.trafficSources.sorted { $0.value > $1.value }, id: \.key) { source, views in
                HStack {
                    Text(source)
                        .font(.subheadline)
                    Spacer()
                    Text("\(views) views")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DemographicsSection: View {
    let analytics: StudioVideoAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Demographics")
                .font(.title2.weight(.semibold))
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                DemoCard(title: "Age", data: analytics.demographics.ageGroups)
                DemoCard(title: "Gender", data: analytics.demographics.genders)
                DemoCard(title: "Countries", data: analytics.demographics.countries)
                DemoCard(title: "Devices", data: analytics.demographics.devices)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DemoCard: View {
    let title: String
    let data: [String: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            
            ForEach(data.sorted { $0.value > $1.value }.prefix(3), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .font(.caption)
                    Spacer()
                    Text("\(value)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}
