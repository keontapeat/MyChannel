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
                        .foregroundColor(.secondary)
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(service.modelMetrics.count)")
                                .font(.system(size: 28, weight: .black)).foregroundColor(.cyan)
                            Text("Models").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(Int(service.overallHealth))%")
                                .font(.system(size: 28, weight: .black)).foregroundColor(service.overallHealth >= 80 ? .green : .orange)
                            Text("Health").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(service.modelsRequiringRetraining)")
                                .font(.system(size: 28, weight: .black)).foregroundColor(service.modelsRequiringRetraining > 0 ? .red : .green)
                            Text("Retrain").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(12)
                
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
                Circle().fill(model.requiresRetraining ? Color.red : Color.green).frame(width: 8, height: 8)
                Text(model.modelName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if model.requiresRetraining {
                    Text("RETRAIN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
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
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}
