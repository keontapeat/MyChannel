//
//  CreatorAdsDashboardStubView.swift
//  MyChannel
//
//  Stub creator-facing ads dashboard until Firestore creator_ad_stats ships.
//  See docs/ads-remaining.md
//

import SwiftUI

struct CreatorAdsDashboardStubView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("Creator Ads")
                    .font(AppTheme.Typography.title2)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text("Revenue share, RPM, and fill-rate analytics will appear here once your channel is monetized.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)

                HStack(spacing: AppTheme.Spacing.md) {
                    stubStat(label: "Est. RPM", value: "—")
                    stubStat(label: "Ad share", value: "90%")
                }

                Link("Advertiser platform", destination: URL(string: "https://mychannel.app/ads")!)
                    .font(AppTheme.Typography.subheadline)
            }
            .padding(AppTheme.Spacing.lg)
        }
        .navigationTitle("Ads")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stubStat(label: String, value: String) -> some View {
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
}

#Preview {
    NavigationStack {
        CreatorAdsDashboardStubView()
    }
}
