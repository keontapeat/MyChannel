//
//  CreatorCoachReportView.swift
//  MyChannel
//
//  Phase 34 UI: AI Creator Coach weekly report card in Creator Studio.
//

import SwiftUI

struct CreatorCoachReportView: View {
    @StateObject private var coach = CreatorCoachService.shared
    @EnvironmentObject private var authManager: AuthenticationManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if coach.isGenerating {
                    ProgressView("Generating your weekly report...")
                        .padding(.top, 40)
                } else if let report = coach.lastReport {
                    reportCard(report)
                } else {
                    generatePrompt
                }

                if let err = coach.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle("AI Coach")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Creator Coach")
                    .font(.title2.bold())
                Text("AI-powered insights for your channel")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Generate Prompt

    private var generatePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Get your weekly AI insights")
                .font(.headline)
            Text("We'll analyze your uploads, audience engagement, and viral potential to give you actionable advice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                generate()
            } label: {
                Text("Generate Report")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Report Card

    private func reportCard(_ report: CreatorWeeklyReport) -> some View {
        VStack(spacing: 20) {
            // Summary
            VStack(alignment: .leading, spacing: 8) {
                Label("Summary", systemImage: "doc.text")
                    .font(.headline)
                Text(report.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Scores
            if report.viralScoreForecast != nil || report.retentionScoreForecast != nil {
                HStack(spacing: 16) {
                    if let viral = report.viralScoreForecast {
                        scoreGauge(title: "Viral Potential", value: viral, color: .orange)
                    }
                    if let retention = report.retentionScoreForecast {
                        scoreGauge(title: "Retention", value: retention, color: .green)
                    }
                }
            }

            // Strengths
            if !report.strengths.isEmpty {
                listSection(title: "Strengths", icon: "star.fill", color: .yellow, items: report.strengths)
            }

            // Opportunities
            if !report.opportunities.isEmpty {
                listSection(title: "Opportunities", icon: "lightbulb.fill", color: .blue, items: report.opportunities)
            }

            // Actions
            if !report.actions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Action Items", systemImage: "checklist")
                        .font(.headline)
                    ForEach(report.actions) { action in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(priorityColor(action.priority))
                                .frame(width: 10, height: 10)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title).font(.subheadline.bold())
                                if !action.detail.isEmpty {
                                    Text(action.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Refresh
            Button {
                generate()
            } label: {
                Label("Refresh Report", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func scoreGauge(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value * 100))%")
                    .font(.headline.monospacedDigit())
            }
            .frame(width: 80, height: 80)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func listSection(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundStyle(color)
                    Text(item).font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func priorityColor(_ p: CoachAction.Priority) -> Color {
        switch p {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    private func generate() {
        guard let uid = authManager.currentUser?.id else { return }
        Task { _ = try? await coach.generateWeeklyReport(creatorId: uid) }
    }
}

#Preview {
    NavigationStack {
        CreatorCoachReportView()
            .environmentObject(AuthenticationManager.shared)
    }
}
