import SwiftUI
import Charts

struct VideoAnalyticsView: View {
    let videoId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analyticsService = StudioAnalyticsService.shared
    @State private var analytics: StudioVideoAnalytics?
    @State private var isLoading = true
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var selectedDateRange: DateRange = .last28Days
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - Always visible
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if isLoading {
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(AppTheme.Colors.primary)
                                Text("Loading analytics...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else if hasError {
                            // Error state
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                                
                                Text("Unable to Load Analytics")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text(errorMessage.isEmpty ? "Please try again later" : errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button("Retry") {
                                    Task {
                                        await loadAnalytics()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 8)
                            }
                            .frame(maxWidth: .infinity)
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
                        } else {
                            // Empty state if no analytics - Show immediately so user sees something
                            VStack(spacing: 20) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary.opacity(0.5))
                                
                                Text("No Analytics Available")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Analytics will appear once your video starts getting views")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                // Quick stats placeholder
                                VStack(spacing: 16) {
                                    HStack(spacing: 12) {
                                        AnalyticsStatBox(title: "Views", value: "0", icon: "eye.fill", color: .blue)
                                        AnalyticsStatBox(title: "Likes", value: "0", icon: "hand.thumbsup.fill", color: .red)
                                        AnalyticsStatBox(title: "Comments", value: "0", icon: "bubble.left.fill", color: .green)
                                    }
                                    
                                    Text("Video ID: \(videoId)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                .padding(.top, 20)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Video Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        NavigationLink(destination: ComprehensiveCreatorStudioView()) {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.xaxis")
                                Text("Studio")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        
                        Picker("Range", selection: $selectedDateRange) {
                            ForEach(DateRange.allCases, id: \.self) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .labelsHidden()
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
        .onAppear {
            // Ensure analytics load if not already loaded
            if analytics == nil && !isLoading {
                Task {
                    await loadAnalytics()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshCreatorStudio"))) { _ in
            print("🔄 [VideoAnalyticsView] Received RefreshCreatorStudio notification - reloading analytics")
            Task {
                await loadAnalytics()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshProfile"))) { _ in
            print("🔄 [VideoAnalyticsView] Received RefreshProfile notification - reloading analytics")
            Task {
                await loadAnalytics()
            }
        }
    }
    
    private func loadAnalytics() async {
        await MainActor.run {
            isLoading = true
            hasError = false
            errorMessage = ""
        }
        
        // Fetch analytics with timeout protection
        let fetchedAnalytics = await withTimeout(seconds: 10) {
            await analyticsService.fetchVideoAnalytics(videoId: videoId, dateRange: selectedDateRange)
        }
        
        await MainActor.run {
            if let analytics = fetchedAnalytics {
                self.analytics = analytics
                hasError = false
            } else {
                // No analytics available - show empty state
                self.analytics = nil
                hasError = false
            }
            isLoading = false
        }
    }
}

// Helper function for timeout protection
private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T?) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask {
            await operation()
        }
        
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        
        let result = await group.next()
        group.cancelAll()
        return result ?? nil
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

struct AnalyticsStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
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
