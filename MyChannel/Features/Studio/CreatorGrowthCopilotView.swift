//
//  CreatorGrowthCopilotView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI

struct CreatorGrowthCopilotView: View {
    @StateObject private var copilotService = CreatorGrowthCopilotService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if copilotService.isAnalyzing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Copilot is analyzing your channel data...")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                    } else if let dashboard = copilotService.dashboardData {
                        // Health Score Card
                        VStack(spacing: 12) {
                            Text("Channel Health Score")
                                .font(.headline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(Int(dashboard.overallHealthScore * 100))")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(dashboard.overallHealthScore > 0.8 ? .green : (dashboard.overallHealthScore > 0.5 ? .yellow : .red))
                                Text("/ 100")
                                    .font(.title3)
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            
                            Text("Projected Subs (30d): +\(dashboard.projectedSubscribers30Days)")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(16)
                        
                        // Insights
                        VStack(alignment: .leading, spacing: 16) {
                            Text("AI Insights & Recommendations")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            ForEach(dashboard.insights) { insight in
                                InsightCard(insight: insight)
                            }
                        }
                    } else {
                        VStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundColor(.purple)
                                .padding(.bottom, 8)
                            Text("Ready to grow your channel?")
                                .font(.title3)
                            Text("Run the AI Copilot to discover actionable insights based on your recent analytics.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .padding(.top, 4)
                            
                            Button(action: {
                                if let uid = AuthenticationManager.shared.currentUser?.id {
                                    Task {
                                        try? await copilotService.analyzeChannel(creatorId: uid)
                                    }
                                }
                            }) {
                                Text("Analyze Channel")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.purple)
                                    .cornerRadius(12)
                            }
                            .padding(.top, 24)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 300)
                    }
                }
                .padding()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Growth Copilot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct InsightCard: View {
    let insight: CopilotInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForSeverity(insight.severity))
                    .foregroundColor(colorForSeverity(insight.severity))
                Text(insight.title)
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Text(insight.metricImpact > 0 ? "+\(insight.metricImpact, specifier: "%.1f")%" : "\(insight.metricImpact, specifier: "%.1f")%")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(insight.metricImpact > 0 ? .green : .red)
            }
            
            Text(insight.description)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Divider()
            
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Action: \(insight.suggestedAction)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
        }
        .padding()
        .background(AppTheme.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForSeverity(insight.severity).opacity(0.3), lineWidth: 1)
        )
    }
    
    func iconForSeverity(_ severity: InsightSeverity) -> String {
        switch severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    func colorForSeverity(_ severity: InsightSeverity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
}
