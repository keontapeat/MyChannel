//
//  ExecutiveCommandCenterView.swift
//  MyChannel
//
//  Phase 280: Executive KPI Tab
//

import SwiftUI

struct ExecutiveCommandCenterView: View {
    @StateObject private var kpi = ExecutiveKPIService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Overall Score
                VStack(spacing: 10) {
                    Text("EXECUTIVE KPI SUMMARY")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("\(Int(kpi.overallScore))%")
                        .font(.system(size: 48, weight: .black))
                        .foregroundColor(kpi.overallScore >= 80 ? .green : kpi.overallScore >= 60 ? .orange : .red)
                }
                .padding(16)
                .background(Color.cyan.opacity(0.08))
                .cornerRadius(12)
                
                // KPI Metrics
                ForEach(kpi.kpiMetrics) { metric in
                    KPICard(metric: metric)
                }
                
                // Alerts
                if !kpi.alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ALERTS")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        ForEach(kpi.alerts) { alert in
                            AlertCard(alert: alert)
                        }
                    }
                    .padding(14)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(12)
                }
            }
            .padding(16)
        }
        .navigationTitle("Executive")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct KPICard: View {
    let metric: ExecutiveKPIService.KPIMetric
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(metric.category)
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(String(format: "%.1f", metric.percentage))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(metric.percentage >= 80 ? .green : metric.percentage >= 60 ? .orange : .red)
                Text(metric.trend)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(metric.trend == "up" ? .green : .red)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

private struct AlertCard: View {
    let alert: ExecutiveKPIService.KPIAlert
    
    var body: some View {
        HStack {
            Circle().fill(alert.severity == "critical" ? Color.red : Color.orange).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.metric)
                    .font(.system(size: 12, weight: .semibold))
                Text(alert.message)
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            Text(alert.triggeredAt, style: .relative)
                .font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
        }
        .padding(10)
        .background(alert.severity == "critical" ? Color.red.opacity(0.08) : Color.orange.opacity(0.08))
        .cornerRadius(8)
    }
}
