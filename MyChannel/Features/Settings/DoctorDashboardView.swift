//
//  DoctorDashboardView.swift
//  MyChannel
//
//  Created by Keonta on 11/3/25.
//  🏥 MyChannel Doctor Dashboard - Real-time App Health Monitoring
//

import SwiftUI
import Charts

struct DoctorDashboardView: View {
    @StateObject private var doctor = MyChannelDoctorService.shared
    @State private var showingIssueDetail: MyChannelDoctorService.HealthIssue?
    @State private var showingRecommendationDetail: MyChannelDoctorService.Recommendation?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    doctorHeader
                    
                    // Health Score Card
                    healthScoreCard
                    
                    // Performance Metrics
                    if let metrics = doctor.performanceMetrics {
                        performanceMetricsSection(metrics)
                    }
                    
                    // Critical Issues
                    if !doctor.criticalIssues.isEmpty {
                        criticalIssuesSection
                    }
                    
                    // Recommendations
                    if !doctor.recommendations.isEmpty {
                        recommendationsSection
                    }
                    
                    // Controls
                    controlsSection
                }
                .padding()
            }
            .navigationTitle("MyChannel Doctor")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            if !doctor.isMonitoring {
                doctor.startMonitoring()
            }
        }
        .sheet(item: $showingIssueDetail) { issue in
            IssueDetailView(issue: issue)
        }
        .sheet(item: $showingRecommendationDetail) { recommendation in
            RecommendationDetailView(recommendation: recommendation)
        }
    }
    
    // MARK: - Header
    
    private var doctorHeader: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "stethoscope")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("MyChannel Doctor")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(doctor.isMonitoring ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(doctor.isMonitoring ? "Monitoring Active" : "Monitoring Paused")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastCheck = doctor.lastCheckTime {
                        Text("• \(timeAgo(from: lastCheck))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Health Score
    
    private var healthScoreCard: some View {
        VStack(spacing: 16) {
            Text("App Health Score")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                // Score circle
                Circle()
                    .trim(from: 0, to: doctor.healthScore / 100)
                    .stroke(
                        LinearGradient(
                            colors: healthScoreColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: doctor.healthScore)
                
                // Score text
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", doctor.healthScore))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(healthScoreColor)
                    
                    Text("out of 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Status row
            HStack(spacing: 20) {
                StatusBadge(
                    icon: "exclamationmark.triangle.fill",
                    count: doctor.criticalIssues.filter { $0.severity == .critical }.count,
                    color: .red,
                    label: "Critical"
                )
                
                StatusBadge(
                    icon: "exclamationmark.circle.fill",
                    count: doctor.criticalIssues.filter { $0.severity == .warning }.count,
                    color: .orange,
                    label: "Warnings"
                )
                
                StatusBadge(
                    icon: "lightbulb.fill",
                    count: doctor.recommendations.filter { !$0.implemented }.count,
                    color: .blue,
                    label: "Tips"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Performance Metrics
    
    private func performanceMetricsSection(_ metrics: MyChannelDoctorService.PerformanceMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Launch Time",
                    value: String(format: "%.2fs", metrics.appLaunchTime),
                    icon: "speedometer",
                    status: metrics.appLaunchTime < 2.0 ? .good : .warning
                )
                
                MetricCard(
                    title: "Frame Rate",
                    value: String(format: "%.0f fps", metrics.averageFrameRate),
                    icon: "waveform",
                    status: metrics.averageFrameRate >= 55 ? .good : .warning
                )
                
                MetricCard(
                    title: "Memory",
                    value: String(format: "%.0f MB", metrics.memoryUsageMB),
                    icon: "memorychip",
                    status: metrics.memoryUsageMB < 300 ? .good : .critical
                )
                
                MetricCard(
                    title: "Network",
                    value: String(format: "%.0f ms", metrics.networkLatencyMs),
                    icon: "wifi",
                    status: metrics.networkLatencyMs < 500 ? .good : .warning
                )
                
                MetricCard(
                    title: "DB Query",
                    value: String(format: "%.2fs", metrics.databaseQueryTime),
                    icon: "cylinder.fill",
                    status: metrics.databaseQueryTime < 1.0 ? .good : .warning
                )
                
                MetricCard(
                    title: "Crash-Free",
                    value: String(format: "%.1f%%", metrics.crashFreeRate),
                    icon: "checkmark.shield.fill",
                    status: metrics.crashFreeRate >= 99.0 ? .good : .critical
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Critical Issues
    
    private var criticalIssuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Critical Issues", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Spacer()
                
                Text("\(doctor.criticalIssues.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            
            ForEach(doctor.criticalIssues.prefix(5)) { issue in
                IssueRow(issue: issue)
                    .onTapGesture {
                        showingIssueDetail = issue
                    }
            }
        }
    }
    
    // MARK: - Recommendations
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Recommendations", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(doctor.recommendations.filter { !$0.implemented }.count) pending")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ForEach(doctor.recommendations.prefix(5)) { recommendation in
                RecommendationRow(recommendation: recommendation)
                    .onTapGesture {
                        showingRecommendationDetail = recommendation
                    }
            }
        }
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await doctor.performHealthCheck()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Run Health Check Now")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .fontWeight(.semibold)
            }
            
            Toggle(isOn: Binding(
                get: { doctor.isMonitoring },
                set: { isOn in
                    if isOn {
                        doctor.startMonitoring()
                    } else {
                        doctor.stopMonitoring()
                    }
                }
            )) {
                Label("24/7 Monitoring", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.subheadline)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private var healthScoreColors: [Color] {
        if doctor.healthScore >= 80 {
            return [.green, .mint]
        } else if doctor.healthScore >= 60 {
            return [.yellow, .orange]
        } else {
            return [.orange, .red]
        }
    }
    
    private var healthScoreColor: Color {
        if doctor.healthScore >= 80 {
            return .green
        } else if doctor.healthScore >= 60 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m ago"
        } else {
            return "\(Int(seconds / 3600))h ago"
        }
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let icon: String
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
            }
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let status: Status
    
    enum Status {
        case good, warning, critical
        
        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(status.color)
                Spacer()
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

struct IssueRow: View {
    let issue: MyChannelDoctorService.HealthIssue
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: issue.severity == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(issue.severity == .critical ? .red : .orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(issue.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

struct RecommendationRow: View {
    let recommendation: MyChannelDoctorService.Recommendation
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(recommendation.implemented ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: recommendation.implemented ? "checkmark" : "lightbulb.fill")
                    .foregroundColor(recommendation.implemented ? .green : .blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("Priority: \(recommendation.priority)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor(recommendation.priority))
                        .cornerRadius(4)
                }
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Label(recommendation.implementationDifficulty, systemImage: "hammer.fill")
                        .font(.caption2)
                    
                    Label(recommendation.estimatedTimeToFix, systemImage: "clock.fill")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .opacity(recommendation.implemented ? 0.6 : 1.0)
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        if priority >= 8 { return .red }
        else if priority >= 5 { return .orange }
        else { return .blue }
    }
}

// MARK: - Detail Views

struct IssueDetailView: View {
    let issue: MyChannelDoctorService.HealthIssue
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Severity Badge
                    HStack {
                        Label(issue.severity.rawValue.uppercased(), systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(issue.severity == .critical ? Color.red : Color.orange)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Text(issue.category.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(issue.description)
                            .font(.body)
                    }
                    
                    // Affected Area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Affected Area")
                            .font(.headline)
                        Text(issue.affectedArea)
                            .font(.body)
                    }
                    
                    // AI Analysis
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AI Analysis", systemImage: "brain")
                            .font(.headline)
                        Text(issue.aiAnalysis)
                            .font(.body)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    // Timestamp
                    Text("Detected: \(issue.detectedAt.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Action Button
                    Button(action: {
                        Task {
                            await MyChannelDoctorService.shared.resolveIssue(id: issue.id)
                            dismiss()
                        }
                    }) {
                        Text("Mark as Resolved")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .fontWeight(.semibold)
                    }
                }
                .padding()
            }
            .navigationTitle(issue.title)
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

struct RecommendationDetailView: View {
    let recommendation: MyChannelDoctorService.Recommendation
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Priority Badge
                    HStack {
                        Label("Priority: \(recommendation.priority)/10", systemImage: "flag.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(priorityColor)
                            .cornerRadius(8)
                        
                        Spacer()
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(recommendation.description)
                            .font(.body)
                    }
                    
                    // Expected Impact
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Expected Impact", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                        Text(recommendation.expectedImpact)
                            .font(.body)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    // Implementation Details
                    HStack(spacing: 20) {
                        DetailBadge(icon: "hammer.fill", label: "Difficulty", value: recommendation.implementationDifficulty)
                        DetailBadge(icon: "clock.fill", label: "Time", value: recommendation.estimatedTimeToFix)
                    }
                    
                    // Code Example
                    if let code = recommendation.codeExample {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Code Example", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(code)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    
                    // Action Button
                    Button(action: {
                        Task {
                            await MyChannelDoctorService.shared.markRecommendationImplemented(id: recommendation.id)
                            dismiss()
                        }
                    }) {
                        Text(recommendation.implemented ? "Implemented ✓" : "Mark as Implemented")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(recommendation.implemented ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .fontWeight(.semibold)
                    }
                    .disabled(recommendation.implemented)
                }
                .padding()
            }
            .navigationTitle(recommendation.title)
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
    
    private var priorityColor: Color {
        if recommendation.priority >= 8 { return .red }
        else if recommendation.priority >= 5 { return .orange }
        else { return .blue }
    }
}

struct DetailBadge: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    DoctorDashboardView()
}

