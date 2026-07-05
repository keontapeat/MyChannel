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
                        .foregroundColor(CCTheme.textSecondary)
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(health.systemStatus.rawValue)")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundColor(health.systemStatus == .healthy ? CCTheme.good : health.systemStatus == .degraded ? CCTheme.warning : CCTheme.critical)
                            Text("Status").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        VStack {
                            Text("\(Int(health.avgLatency))ms")
                                .font(.system(size: 20, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
                            Text("Latency").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        VStack {
                            Text("\(health.uptime, specifier: "%.1f")%")
                                .font(.system(size: 20, weight: .black, design: .monospaced)).foregroundColor(CCTheme.good)
                            Text("Uptime").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                    }
                }
                .padding(16)
                .background(CCTheme.panel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
                
                // Transcoding & CDN Telemetry Card
                VStack(spacing: 12) {
                    Text("TRANSCODING & CDN TELEMETRY")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                    
                    HStack(spacing: 15) {
                        VStack(spacing: 4) {
                            Text("\(health.transcodingQueueDepth)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(CCTheme.textPrimary)
                            Text("Queue").font(.system(size: 9, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text("\(health.activeTranscoders)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(CCTheme.textPrimary)
                            Text("Nodes").font(.system(size: 9, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text("\(health.cdnCacheHitRatio, specifier: "%.1f")%")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(CCTheme.good)
                            Text("Hit Ratio").font(.system(size: 9, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 4) {
                            Text("\(health.cdnEgressGb, specifier: "%.1f") GB")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(CCTheme.textPrimary)
                            Text("Egress").font(.system(size: 9, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .background(CCTheme.panel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
                
                // Cost Summary
                VStack(spacing: 10) {
                    Text("INFRASTRUCTURE COSTS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                    Text("$\(cost.totalMonthlyCost, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
                    Text("Potential savings: $\(cost.savingsPotential, specifier: "%.2f")")
                        .font(.system(size: 11, design: .monospaced)).foregroundColor(CCTheme.good)
                }
                .padding(16)
                .background(CCTheme.panel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
                
                // FinOps Actions Card
                VStack(spacing: 12) {
                    Text("ACTIVE COST OPTIMIZATION ACTIONS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                    
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
                            .background(CCTheme.ink)
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
                            .background(CCTheme.ink)
                            .cornerRadius(8)
                        }
                        .disabled(isOptimizing)
                    }
                }
                .padding(16)
                .background(CCTheme.panel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
                
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
                    .background(CCTheme.ink)
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
                    .foregroundColor(CCTheme.textSecondary)
                Spacer()
                Text("$\(suggestion.potentialSavings, specifier: "%.2f")")
                    .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(CCTheme.good)
            }
            Text(suggestion.description)
                .font(.system(size: 13))
                .foregroundColor(CCTheme.textPrimary)
            Text(suggestion.priority.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(suggestion.priority == "high" ? CCTheme.critical : CCTheme.warning)
        }
        .padding(12)
        .background(CCTheme.panel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CCTheme.panelBorder, lineWidth: 1))
    }
}
