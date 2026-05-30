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
    
    @State private var isArchiving = false
    @State private var isOptimizing = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
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
                
                // Transcoding & CDN Telemetry Card
                VStack(spacing: 12) {
                    Text("TRANSCODING & CDN TELEMETRY")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 15) {
                        VStack(spacing: 4) {
                            Text("\(health.transcodingQueueDepth)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.orange)
                            Text("Queue").font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text("\(health.activeTranscoders)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.cyan)
                            Text("Nodes").font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text("\(health.cdnCacheHitRatio, specifier: "%.1f")%")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                            Text("Hit Ratio").font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text("\(health.cdnEgressGb, specifier: "%.1f") GB")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.purple)
                            Text("Egress").font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .background(Color.purple.opacity(0.06))
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
                
                // FinOps Actions Card
                VStack(spacing: 12) {
                    Text("ACTIVE COST OPTIMIZATION ACTIONS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                isArchiving = true
                                let success = try? await cost.archiveColdVideos()
                                isArchiving = false
                                if success == true {
                                    toastMessage = "Successfully archived cold videos!"
                                    withAnimation {
                                        showToast = true
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if isArchiving {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "archivebox.fill")
                                }
                                Text("Archive Cold")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.orange)
                            .cornerRadius(8)
                        }
                        .disabled(isArchiving)
                        
                        Button {
                            Task {
                                isOptimizing = true
                                let success = try? await cost.optimizeEncodingCodec()
                                isOptimizing = false
                                if success == true {
                                    toastMessage = "Successfully optimized video codecs!"
                                    withAnimation {
                                        showToast = true
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if isOptimizing {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "cpu.fill")
                                }
                                Text("Optimize Codecs")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                        .disabled(isOptimizing)
                    }
                }
                .padding(16)
                .background(Color.green.opacity(0.06))
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
        .overlay(alignment: .bottom) {
            if showToast {
                Text(toastMessage)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
            }
        }
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
