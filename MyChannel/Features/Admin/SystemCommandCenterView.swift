//
//  SystemCommandCenterView.swift
//  MyChannel
//
//  Phase 267 & 279: System Health & Infrastructure Tab
//

import SwiftUI

struct SystemCommandCenterView: View {
    @StateObject private var health = SystemHealthTelemetryService.shared
    @StateObject private var cost = InfrastructureCostOptimizationService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // System Health
                VStack(spacing: 10) {
                    Text("SYSTEM HEALTH")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(health.systemStatus.rawValue)")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(health.systemStatus == .healthy ? .green : health.systemStatus == .degraded ? .orange : .red)
                            Text("Status").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(Int(health.avgLatency))ms")
                                .font(.system(size: 20, weight: .black)).foregroundColor(.cyan)
                            Text("Latency").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(health.uptime, specifier: "%.1f")%")
                                .font(.system(size: 20, weight: .black)).foregroundColor(.green)
                            Text("Uptime").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(12)
                
                // Cost Summary
                VStack(spacing: 10) {
                    Text("INFRASTRUCTURE COSTS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("$\(cost.totalMonthlyCost, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .black)).foregroundColor(.orange)
                    Text("Potential savings: $\(cost.savingsPotential, specifier: "%.2f")")
                        .font(.system(size: 11, design: .monospaced)).foregroundColor(.green)
                }
                .padding(16)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(12)
                
                // Optimization Suggestions
                ForEach(cost.optimizationSuggestions.prefix(5)) { suggestion in
                    CostOptimizationCard(suggestion: suggestion)
                }
            }
            .padding(16)
        }
        .navigationTitle("System")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CostOptimizationCard: View {
    let suggestion: InfrastructureCostOptimizationService.OptimizationSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.category)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(suggestion.potentialSavings, specifier: "%.2f")")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.green)
            }
            Text(suggestion.description)
                .font(.system(size: 13))
            Text(suggestion.priority.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(suggestion.priority == "high" ? .red : .orange)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}
