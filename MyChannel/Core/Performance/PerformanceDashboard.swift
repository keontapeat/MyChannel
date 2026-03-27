//
//  PerformanceDashboard.swift
//  MyChannel
//
//  📊 COMPREHENSIVE PERFORMANCE MONITORING DASHBOARD
//  Real-time metrics, analytics, and optimization insights
//

import SwiftUI
import Charts

// MARK: - Performance Dashboard View

struct PerformanceDashboard: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    @StateObject private var memoryManager = DynamicMemoryManager.shared
    @StateObject private var scrollOptimizer = AdvancedScrollOptimizer.shared
    @StateObject private var startupTracker = StartupPerformanceTracker.shared
    @StateObject private var lazyServiceManager = LazyServiceManager.shared
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Metrics", selection: $selectedTab) {
                    Text("Overview").tag(0)
                    Text("Startup").tag(1)
                    Text("Memory").tag(2)
                    Text("Network").tag(3)
                    Text("Video").tag(4)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    OverviewTab(monitor: monitor, memoryManager: memoryManager, scrollOptimizer: scrollOptimizer)
                        .tag(0)
                    
                    StartupTab(tracker: startupTracker, serviceManager: lazyServiceManager)
                        .tag(1)
                    
                    MemoryTab(memoryManager: memoryManager)
                        .tag(2)
                    
                    NetworkTab(monitor: monitor)
                        .tag(3)
                    
                    VideoTab()
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Performance Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    @ObservedObject var monitor: PerformanceMonitor
    @ObservedObject var memoryManager: DynamicMemoryManager
    @ObservedObject var scrollOptimizer: AdvancedScrollOptimizer
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Performance Score
                PerformanceScoreCard(
                    fps: scrollOptimizer.currentFPS,
                    memory: memoryManager.currentMemoryUsage,
                    cacheHitRate: monitor.metrics.cacheHitRate
                )
                
                // Quick Stats
                HStack(spacing: 15) {
                    PerformanceQuickStatCard(
                        title: "FPS",
                        value: "\(Int(scrollOptimizer.currentFPS))",
                        subtitle: "Current",
                        color: scrollOptimizer.currentFPS >= 58 ? .green : .orange
                    )
                    
                    PerformanceQuickStatCard(
                        title: "Memory",
                        value: "\(memoryManager.currentMemoryUsage / 1_000_000)MB",
                        subtitle: memoryManager.memoryTier.description,
                        color: memoryManager.memoryPressureLevel == .normal ? .green : .red
                    )
                    
                    PerformanceQuickStatCard(
                        title: "Cache",
                        value: "\(Int(monitor.metrics.cacheHitRate * 100))%",
                        subtitle: "Hit Rate",
                        color: monitor.metrics.cacheHitRate > 0.8 ? .green : .orange
                    )
                }
                
                // Recent Alerts
                if !monitor.alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent Alerts")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(monitor.alerts.prefix(5)) { alert in
                            AlertRow(alert: alert)
                        }
                    }
                }
                
                // Metrics Summary
                MetricsSummaryCard(metrics: monitor.metrics)
            }
            .padding()
        }
    }
}

// MARK: - Startup Tab

struct StartupTab: View {
    @ObservedObject var tracker: StartupPerformanceTracker
    @ObservedObject var serviceManager: LazyServiceManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Startup Time Card
                VStack(alignment: .leading, spacing: 15) {
                    Text("Startup Performance")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Cold Start")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(tracker.metrics.coldStartTime * 1000))ms")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        Image(systemName: tracker.metrics.coldStartTime < 2.0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundColor(tracker.metrics.coldStartTime < 2.0 ? .green : .orange)
                    }
                    
                    Divider()
                    
                    HStack {
                        MetricRow(label: "First Frame", value: "\(Int(tracker.metrics.timeToFirstFrame * 1000))ms")
                        Spacer()
                        MetricRow(label: "Interactive", value: "\(Int(tracker.metrics.timeToInteractive * 1000))ms")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Service Loading Progress
                VStack(alignment: .leading, spacing: 15) {
                    Text("Service Initialization")
                        .font(.headline)
                    
                    ProgressView(value: serviceManager.initializationProgress)
                        .progressViewStyle(.linear)
                    
                    Text("\(Int(serviceManager.initializationProgress * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !serviceManager.currentlyInitializing.isEmpty {
                        Text("Loading: \(serviceManager.currentlyInitializing)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .padding()
        }
    }
}

// MARK: - Memory Tab

struct MemoryTab: View {
    @ObservedObject var memoryManager: DynamicMemoryManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Memory Usage Card
                VStack(alignment: .leading, spacing: 15) {
                    Text("Memory Usage")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(memoryManager.currentMemoryUsage / 1_000_000)MB")
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                            
                            Text("Current Usage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(memoryManager.memoryPressureLevel.description)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(memoryManager.memoryPressureLevel.color)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Memory Tier Info
                VStack(alignment: .leading, spacing: 10) {
                    Text("Device Configuration")
                        .font(.headline)
                    
                    HStack {
                        Text("Memory Tier:")
                        Spacer()
                        Text(memoryManager.memoryTier.description)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Image Cache:")
                        Spacer()
                        Text("\(memoryManager.memoryTier.imageCacheSize / 1024 / 1024)MB")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("URL Cache:")
                        Spacer()
                        Text("\(memoryManager.memoryTier.urlCacheMemory / 1024 / 1024)MB")
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .padding()
        }
    }
}

// MARK: - Network Tab

struct NetworkTab: View {
    @ObservedObject var monitor: PerformanceMonitor
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Network Stats
                VStack(alignment: .leading, spacing: 15) {
                    Text("Network Performance")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(Int(monitor.metrics.avgNetworkRequestTime * 1000))ms")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Avg Request Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("\(monitor.metrics.totalNetworkRequests)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Total Requests")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Slow Requests:")
                        Spacer()
                        Text("\(monitor.metrics.slowNetworkRequests)")
                            .fontWeight(.semibold)
                            .foregroundColor(monitor.metrics.slowNetworkRequests > 10 ? .red : .green)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .padding()
        }
    }
}

// MARK: - Video Tab

struct VideoTab: View {
    @StateObject private var playerPool = VideoPlayerPool.shared
    @StateObject private var performanceTracker = VideoPerformanceTracker.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Player Pool Stats
                VStack(alignment: .leading, spacing: 15) {
                    Text("Video Player Pool")
                        .font(.headline)
                    
                    HStack {
                        Text("Active Players:")
                        Spacer()
                        Text("\(playerPool.activePlayerCount)")
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .padding()
        }
    }
}

// MARK: - Supporting Components

struct PerformanceScoreCard: View {
    let fps: Double
    let memory: Int64
    let cacheHitRate: Double
    
    var performanceScore: Int {
        var score = 100
        
        // FPS penalty
        if fps < 60 { score -= Int((60 - fps) * 2) }
        
        // Memory penalty
        let memoryMB = memory / 1_000_000
        if memoryMB > 200 { score -= Int((memoryMB - 200) / 10) }
        
        // Cache penalty
        if cacheHitRate < 0.8 { score -= Int((0.8 - cacheHitRate) * 50) }
        
        return max(0, min(100, score))
    }
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Performance Score")
                .font(.headline)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: CGFloat(performanceScore) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(performanceScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            
            Text(scoreDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    var scoreColor: Color {
        if performanceScore >= 90 { return .green }
        if performanceScore >= 70 { return .orange }
        return .red
    }
    
    var scoreDescription: String {
        if performanceScore >= 90 { return "Excellent - YouTube Parity Achieved!" }
        if performanceScore >= 70 { return "Good - Minor optimizations needed" }
        return "Needs Improvement - Check metrics below"
    }
}

struct PerformanceQuickStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct AlertRow: View {
    let alert: PerformanceMonitor.PerformanceAlert
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading) {
                Text(alert.message)
                    .font(.caption)
                
                Text(alert.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    var iconName: String {
        switch alert.type {
        case .slowImage: return "photo"
        case .slowNetwork: return "network"
        case .droppedFrame: return "film"
        case .memoryWarning: return "memorychip"
        case .lowCacheHit: return "externaldrive"
        }
    }
    
    var iconColor: Color {
        switch alert.type {
        case .memoryWarning: return .red
        default: return .orange
        }
    }
}

struct MetricsSummaryCard: View {
    let metrics: PerformanceMonitor.PerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Detailed Metrics")
                .font(.headline)
            
            MetricRow(label: "Avg Image Load", value: "\(Int(metrics.avgImageLoadTime * 1000))ms")
            MetricRow(label: "Avg Network", value: "\(Int(metrics.avgNetworkRequestTime * 1000))ms")
            MetricRow(label: "Avg Render", value: "\(Int(metrics.avgViewRenderTime * 1000))ms")
            MetricRow(label: "Cache Hit Rate", value: "\(Int(metrics.cacheHitRate * 100))%")
            MetricRow(label: "Dropped Frames", value: "\(metrics.droppedFrames)")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Extensions

extension MemoryTier {
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .ultra: return "Ultra"
        }
    }
}

extension DynamicMemoryManager.MemoryPressureLevel {
    var description: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PerformanceDashboard_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDashboard()
    }
}
#endif
