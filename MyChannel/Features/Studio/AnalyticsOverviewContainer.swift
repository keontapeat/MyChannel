//
//  AnalyticsOverviewContainer.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

struct AnalyticsOverviewContainer: View {
    @StateObject private var service = AdvancedAnalyticsService.shared
    @EnvironmentObject private var appState: AppState
    @State private var creatorId: String = User.sampleUsers.first?.id ?? ""
    
    var body: some View {
        VStack(spacing: 0) {
            realtimePanel
            Divider()
            AnalyticsDashboardView()
        }
        .task {
            if let id = appState.currentUser?.id { creatorId = id }
            await service.startRealtimeMonitoring(for: creatorId)
        }
    }
    
    private var realtimePanel: some View {
        HStack(spacing: 16) {
            metric(icon: "dot.radiowaves.left.and.right", title: "Live Viewers", value: "\(service.liveViewerCount)")
            metric(icon: "bolt.heart", title: "Engagement", value: String(format: "%.1f%%", service.liveEngagementRate))
            metric(icon: "flame", title: "Trend", value: String(format: "%.0f", service.currentTrendingScore))
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private func metric(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Analytics Overview Container") {
    AnalyticsOverviewContainer()
        .environmentObject(AppState())
}


