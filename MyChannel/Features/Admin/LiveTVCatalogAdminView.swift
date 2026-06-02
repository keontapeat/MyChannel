//
//  LiveTVCatalogAdminView.swift
//  MyChannel
//
//  🔧 Admin tool: push the bundled Live TV catalog to Firestore so channels
//  (artwork + stream URLs) can be curated server-side without an app release.
//  Writes are gated by Firestore rules to the owner/admin account.
//

import SwiftUI

struct LiveTVCatalogAdminView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isSeeding = false
    @State private var statusMessage: String?
    @State private var didSucceed = false

    private var channelCount: Int { LiveTVChannel.sampleChannels.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    infoCard

                    seedButton

                    if let statusMessage {
                        statusBanner(statusMessage)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Live TV Catalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("📡 Channel Catalog Sync")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("Push the \(channelCount) bundled channels to Firestore (collection: \(LiveTVCatalogService.collectionName)). The app reads this catalog first, so you can fix artwork or stream URLs in the console without shipping an update.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(channelCount) channels ready to sync", systemImage: "tv.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Label("Idempotent — safe to run multiple times", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Label("Requires admin sign-in (enforced by Firestore rules)", systemImage: "lock.shield.fill")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.Colors.surface))
    }

    private var seedButton: some View {
        Button {
            Task { await seed() }
        } label: {
            HStack {
                if isSeeding {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "icloud.and.arrow.up.fill")
                }
                Text(isSeeding ? "Syncing…" : "Sync Catalog to Firestore")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14).fill(isSeeding ? Color.gray : AppTheme.Colors.primary))
        }
        .disabled(isSeeding)
    }

    private func statusBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: didSucceed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(didSucceed ? .green : .orange)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.surface))
    }

    @MainActor
    private func seed() async {
        isSeeding = true
        statusMessage = nil
        #if canImport(FirebaseFirestore)
        do {
            try await LiveTVCatalogService.shared.seedFromSampleData()
            didSucceed = true
            statusMessage = "Synced \(channelCount) channels to Firestore."
            HapticManager.shared.notification(type: .success)
        } catch {
            didSucceed = false
            statusMessage = "Sync failed: \(error.localizedDescription)"
            HapticManager.shared.notification(type: .error)
        }
        #else
        didSucceed = false
        statusMessage = "FirebaseFirestore not available in this build."
        #endif
        isSeeding = false
    }
}

#Preview {
    LiveTVCatalogAdminView()
}
