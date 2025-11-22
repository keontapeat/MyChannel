//
//  AlertsCenterView.swift
//  MyChannel
//
//  Created by AI Assistant on 10/15/25.
//

import SwiftUI

struct AlertsCenterView: View {
    @StateObject private var analytics = AdvancedAnalyticsService.shared
    
    var body: some View {
        List {
            Section("AI Tips") {
                ForEach(analytics.contentOptimizationTips, id: \.id) { tip in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tip.title).font(.headline)
                        Text(tip.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Viral Opportunities") {
                ForEach(analytics.viralOpportunities, id: \.id) { o in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(o.trendingTopic) • \(o.contentType)").font(.subheadline).fontWeight(.semibold)
                        Text("Potential reach: \(o.expectedReach.formatted())").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Milestones") {
                milestoneRow(title: "10K views today", icon: "star.fill")
                milestoneRow(title: "+1K subscribers this week", icon: "person.2.fill")
            }
        }
        .task {
            _ = try? await analytics.getContentOptimizationTips(for: "creator-1")
            _ = try? await analytics.getViralOpportunities(for: "creator-1")
        }
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func milestoneRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.yellow)
            Text(title)
        }
    }
}

#Preview {
    NavigationStack { AlertsCenterView() }
}


