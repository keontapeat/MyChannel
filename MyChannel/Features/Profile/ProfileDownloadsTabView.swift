//
//  ProfileDownloadsTabView.swift
//  MyChannel
//
//  Inline downloads tab for ProfileView — YouTube-style.
//  Backed by OfflineDownloadService (the canonical offline-downloads engine),
//  so it stays in perfect sync with the Downloads screen and the in-player
//  download button.
//

import SwiftUI
import UIKit
import FirebaseAuth

// MARK: - Profile Downloads Tab View (inline in profile)
struct ProfileDownloadsTabView: View {
    @StateObject private var offlineService = OfflineDownloadService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingUpgrade = false
    @State private var showingDeleteAlert = false
    @State private var videoToDelete: OfflineDownload?
    @State private var showingDeleteAllAlert = false
    @State private var shareItems: [Any]?

    private var isAuthenticated: Bool {
        Auth.auth().currentUser != nil
    }

    private var completedDownloads: [OfflineDownload] {
        offlineService.completedDownloads
    }

    private var inProgressDownloads: [OfflineDownload] {
        offlineService.inProgressDownloads
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isAuthenticated {
                signInPrompt
            } else if !AppConfig.Features.enableSubscriptions && !subscriptionService.isPlusSubscriber {
                // 🔥 FIX 2.1(b): Hide subscription upsell when IAPs not submitted
                VStack(spacing: 16) {
                    Spacer().frame(height: 32)
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("Downloads Coming Soon")
                        .font(.system(size: 20, weight: .bold))
                    Text("Offline downloads will be available in a future update.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if AppConfig.Features.enableSubscriptions && !subscriptionService.isPlusSubscriber {
                premiumUpgradePrompt
            } else if completedDownloads.isEmpty && inProgressDownloads.isEmpty {
                emptyDownloadsView
            } else {
                downloadsListView
            }
        }
        .padding(.vertical, 16)
        .task {
            offlineService.updateStorageInfo()
        }
        .sheet(isPresented: $showingUpgrade) {
            MyChannelPlusView()
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                NativeShareSheet(items: items)
            }
        }
        .alert("Delete Download", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let video = videoToDelete {
                    deleteDownload(video)
                }
            }
        } message: {
            if let video = videoToDelete {
                Text("Remove \"\(video.title)\" from downloads? This will free up \(ByteCountFormatter.string(fromByteCount: Int64(video.fileSize), countStyle: .file)).")
            }
        }
        .alert("Delete All Downloads", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllDownloads()
            }
        } message: {
            Text("Remove all \(completedDownloads.count) downloaded videos? This will free up \(offlineService.formattedStorageUsed()).")
        }
    }

    // MARK: - Sign In Prompt
    private var signInPrompt: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.Colors.textSecondary)

            Text("Sign in to download videos")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Premium Upgrade Prompt
    private var premiumUpgradePrompt: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 32)

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 10) {
                Text("Download videos to watch offline")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Get MyChannel Plus to download videos and watch them anywhere, even without internet.")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                premiumBenefit(icon: "arrow.down.circle.fill", text: "Unlimited downloads")
                premiumBenefit(icon: "wifi.slash", text: "Watch offline anywhere")
                premiumBenefit(icon: "play.slash.fill", text: "Ad-free viewing")
                premiumBenefit(icon: "hd.circle.fill", text: "Up to 1080p quality")
            }
            .padding(.horizontal, 40)

            Button {
                showingUpgrade = true
                HapticManager.shared.impact(style: .medium)
            } label: {
                Text("Get MyChannel Plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.blue)
                    .cornerRadius(24)
            }
            .padding(.horizontal, 32)

            Spacer().frame(height: 32)
        }
        .frame(maxWidth: .infinity)
    }

    private func premiumBenefit(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)

            Spacer()
        }
    }

    // MARK: - Empty Downloads
    private var emptyDownloadsView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 88, height: 88)

                Image(systemName: "arrow.down.to.line.circle")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            VStack(spacing: 8) {
                Text("No downloads yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text("Videos you download will appear here.\nTap the download button on any video to save it.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Downloads List
    private var downloadsListView: some View {
        VStack(spacing: 0) {
            // Storage & count header
            HStack(spacing: 12) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(offlineService.formattedStorageUsed()) used")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("\(completedDownloads.count) video\(completedDownloads.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                Spacer()

                if !completedDownloads.isEmpty {
                    Button {
                        showingDeleteAllAlert = true
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text("Clear all")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.error)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.surface.opacity(0.5))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Active downloads (in-progress)
            ForEach(inProgressDownloads) { download in
                activeDownloadRow(download)
            }

            // Completed downloads
            ForEach(completedDownloads) { download in
                downloadRow(download)

                if download.id != completedDownloads.last?.id {
                    Divider()
                        .padding(.leading, 96)
                        .padding(.trailing, 20)
                }
            }
        }
    }

    // MARK: - Active Download Row (in-progress)
    private func activeDownloadRow(_ download: OfflineDownload) -> some View {
        HStack(spacing: 14) {
            // Progress indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 72, height: 42)

                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2.5)
                        .frame(width: 28, height: 28)

                    Circle()
                        .trim(from: 0, to: download.progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 28, height: 28)

                    Text("\(Int(download.progress * 100))%")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.blue)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(download.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(download.status == .queued ? "Waiting…" : "Downloading…")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Button {
                Task { await offlineService.cancelDownload(download.id) }
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Download Row
    private func downloadRow(_ download: OfflineDownload) -> some View {
        Button {
            playDownloadedVideo(download)
        } label: {
            HStack(spacing: 14) {
                // Thumbnail
                AsyncImage(url: URL(string: download.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        )
                }
                .frame(width: 72, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .bottomTrailing) {
                    Text(formattedDuration(download.duration))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(3)
                        .padding(3)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(download.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("Available offline")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(download.quality.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(download.quality.color)
                            .cornerRadius(3)

                        Text(ByteCountFormatter.string(fromByteCount: Int64(download.fileSize), countStyle: .file))
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }

                Spacer()

                // More options
                Menu {
                    Button {
                        playDownloadedVideo(download)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }

                    Button {
                        shareDownload(download)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        videoToDelete = download
                        showingDeleteAlert = true
                    } label: {
                        Label("Remove Download", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func playDownloadedVideo(_ download: OfflineDownload) {
        HapticManager.shared.impact(style: .light)

        guard let video = offlineService.offlinePlaybackVideo(for: download.videoId) else {
            // File missing — remove stale download
            Task { try? await offlineService.deleteDownload(download.id) }
            return
        }

        NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
    }

    private func deleteDownload(_ download: OfflineDownload) {
        HapticManager.shared.impact(style: .medium)
        Task {
            try? await offlineService.deleteDownload(download.id)
        }
    }

    private func deleteAllDownloads() {
        HapticManager.shared.impact(style: .heavy)
        Task {
            await offlineService.deleteAllDownloads()
        }
    }

    private func shareDownload(_ download: OfflineDownload) {
        HapticManager.shared.impact(style: .light)
        guard let url = URL(string: "https://mychannel.live/watch?v=\(download.videoId)") else { return }
        shareItems = [download.title, url]
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let total = max(Int(duration), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ProfileDownloadsTabView()
}
