//
//  CreatorAdsDashboardStubView.swift
//  MyChannel
//
//  Creator-facing ads revenue dashboard. Shows real RPM + fill-rate from
//  Firestore `creator_ad_stats/{uid}` when data exists, with stub
//  placeholders while the collection is being backfilled.
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct CreatorAdsDashboardStubView: View {
    @State private var rpm: Double? = nil
    @State private var fillRate: Double? = nil
    @State private var estimatedRevenue: Double? = nil
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("Creator Ads")
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.vertical, 24)
                } else {
                    HStack(spacing: AppTheme.Spacing.md) {
                        statCard(label: "Est. RPM", value: rpm.map { String(format: "$%.2f", $0) } ?? "—")
                        statCard(label: "Fill Rate", value: fillRate.map { String(format: "%.1f%%", $0 * 100) } ?? "—")
                        statCard(label: "Est. Revenue", value: estimatedRevenue.map { String(format: "$%.2f", $0) } ?? "—")
                    }
                }

                if rpm == nil && !isLoading {
                    Text("Revenue share, RPM, and fill-rate analytics will appear here once your channel is monetized and data has been collected.")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Divider()

                Link("Advertiser platform →", destination: URL(string: "https://mychannel.app/ads")!)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(AppTheme.Spacing.lg)
        }
        .navigationTitle("Ads Revenue")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStats() }
    }

    private func statCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(label)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text(value)
                .font(AppTheme.Typography.title3)
                .fontWeight(.semibold)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func loadStats() async {
        isLoading = true
        defer { isLoading = false }
        guard let uid = AppState.shared.currentUser?.id else { return }
        #if canImport(FirebaseFirestore)
        let snap = try? await Firestore.firestore()
            .collection("creator_ad_stats")
            .document(uid)
            .getDocument()
        if let data = snap?.data() {
            await MainActor.run {
                rpm = data["rpmUSD"] as? Double
                fillRate = data["fillRate"] as? Double
                estimatedRevenue = data["estimatedRevenueUSD"] as? Double
            }
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        CreatorAdsDashboardStubView()
    }
}
