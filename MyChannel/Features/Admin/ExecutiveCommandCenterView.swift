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
                        .foregroundColor(CCTheme.textSecondary)
                    Text("\(Int(kpi.overallScore))%")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundColor(kpi.overallScore >= 80 ? CCTheme.good : kpi.overallScore >= 60 ? CCTheme.warning : CCTheme.critical)
                }
                .padding(16)
                .background(CCTheme.panel)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
                
                // KPI Metrics
                ForEach(kpi.kpiMetrics) { metric in
                    KPICard(metric: metric)
                }
                
                // Alerts
                if !kpi.alerts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ALERTS")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(CCTheme.textSecondary)
                        ForEach(kpi.alerts) { alert in
                            AlertCard(alert: alert)
                        }
                    }
                    .padding(14)
                    .background(CCTheme.panel)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(CCTheme.panelBorder, lineWidth: 1))
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
                    .foregroundColor(CCTheme.textPrimary)
                Text(metric.category)
                    .font(.system(size: 11)).foregroundColor(CCTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(String(format: "%.1f", metric.percentage))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(metric.percentage >= 80 ? CCTheme.good : metric.percentage >= 60 ? CCTheme.warning : CCTheme.critical)
                Text(metric.trend)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(metric.trend == "up" ? CCTheme.good : CCTheme.critical)
            }
        }
        .padding(12)
        .background(CCTheme.panel)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CCTheme.panelBorder, lineWidth: 1))
    }
}

private struct AlertCard: View {
    let alert: ExecutiveKPIService.KPIAlert
    
    var body: some View {
        HStack {
            Circle().fill(alert.severity == "critical" ? CCTheme.critical : CCTheme.warning).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.metric)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CCTheme.textPrimary)
                Text(alert.message)
                    .font(.system(size: 11)).foregroundColor(CCTheme.textSecondary)
            }
            Spacer()
            Text(alert.triggeredAt, style: .relative)
                .font(.system(size: 10, design: .monospaced)).foregroundColor(CCTheme.textSecondary)
        }
        .padding(10)
        .background(CCTheme.panel)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(alert.severity == "critical" ? CCTheme.critical.opacity(0.35) : CCTheme.warning.opacity(0.35), lineWidth: 1))
    }
}
