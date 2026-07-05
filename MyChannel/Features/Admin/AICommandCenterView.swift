//
//  AICommandCenterView.swift
//  MyChannel
//
//  Phase 270: AI Model Performance Tab
//

import SwiftUI

struct AICommandCenterView: View {
    @StateObject private var service = AIModelPerformanceService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Summary Card
                VStack(spacing: 10) {
                    Text("AI MODEL PERFORMANCE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.textSecondary)
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(service.modelMetrics.count)")
                                .font(.system(size: 28, weight: .black, design: .monospaced)).foregroundColor(CCTheme.textPrimary)
                            Text("Models").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        VStack {
                            Text("\(Int(service.overallHealth))%")
                                .font(.system(size: 28, weight: .black, design: .monospaced)).foregroundColor(service.overallHealth >= 80 ? CCTheme.good : CCTheme.warning)
                            Text("Health").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                        VStack {
                            Text("\(service.modelsRequiringRetraining)")
                                .font(.system(size: 28, weight: .black, design: .monospaced)).foregroundColor(service.modelsRequiringRetraining > 0 ? CCTheme.critical : CCTheme.good)
                            Text("Retrain").font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
                        }
                    }
                }
                .padding(16)
                .background(CCTheme.panel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
                
                // Model List
                ForEach(service.modelMetrics) { model in
                    AIModelCard(model: model)
                }
            }
            .padding(16)
        }
        .navigationTitle("AI Performance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AIModelCard: View {
    let model: AIModelPerformanceService.AIModelMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(model.requiresRetraining ? CCTheme.critical : CCTheme.good).frame(width: 7, height: 7)
                Text(model.modelName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CCTheme.textPrimary)
                Spacer()
                if model.requiresRetraining {
                    Text("RETRAIN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(CCTheme.critical)
                }
            }
            HStack(spacing: 16) {
                Text("Acc: \(String(format: "%.1f%%", model.accuracy))")
                    .font(.system(size: 11, design: .monospaced))
                Text("F1: \(String(format: "%.2f", model.f1Score))")
                    .font(.system(size: 11, design: .monospaced))
                Text("Lat: \(Int(model.latency))ms")
                    .font(.system(size: 11, design: .monospaced))
            }
            .foregroundColor(CCTheme.textSecondary)
        }
        .padding(12)
        .background(CCTheme.panel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CCTheme.panelBorder, lineWidth: 1))
    }
}
