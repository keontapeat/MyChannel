//
//  ProfileDownloadsTabView.swift
//  MyChannel
//
//  Inline downloads tab for ProfileView — YouTube-style.
//  Backed by DownloadManager (Firestore + local files).
//

import SwiftUI
import UIKit
import FirebaseAuth

// MARK: - Profile Downloads Tab View (inline in profile)
struct ProfileDownloadsTabView: View {
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingUpgrade = false
    @State private var showingDeleteAlert = false
    @State private var videoToDelete: DownloadedVideo?
    @State private var showingDeleteAllAlert = false
    @State private var selectedVideoForPlayback: DownloadedVideo?
    
    private var isAuthenticated: Bool {
        Auth.auth().currentUser != nil
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
            } else if !subscriptionService.isPlusSubscriber {
                premiumUpgradePrompt
            } else if downloadManager.isLoading {
                loadingView
            } else if downloadManager.downloads.isEmpty && downloadManager.activeDownloads.isEmpty {
                emptyDownloadsView
            } else {
                downloadsListView
            }
        }
        .padding(.vertical, 16)
        .sheet(isPresented: $showingUpgrade) {
            MyChannelPlusView()
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
                Text("Remove \"\(video.title)\" from downloads? This will free up \(video.formattedFileSize).")
            }
        }
        .alert("Delete All Downloads", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                deleteAllDownloads()
            }
        } message: {
            Text("Remove all \(downloadManager.downloads.count) downloaded videos? This will free up \(downloadManager.getFormattedTotalStorage()).")
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
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.Colors.primary)
            
            Text("Loading downloads...")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
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
                    Text("\(downloadManager.getFormattedTotalStorage()) used")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("\(downloadManager.downloads.count) video\(downloadManager.downloads.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                if !downloadManager.downloads.isEmpty {
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
            ForEach(Array(downloadManager.activeDownloads.keys.sorted()), id: \.self) { videoId in
                if let progress = downloadManager.activeDownloads[videoId] {
                    activeDownloadRow(videoId: videoId, progress: progress)
                }
            }
            
            // Completed downloads
            ForEach(downloadManager.downloads) { download in
                downloadRow(download)
                
                if download.id != downloadManager.downloads.last?.id {
                    Divider()
                        .padding(.leading, 96)
                        .padding(.trailing, 20)
                }
            }
        }
    }
    
    // MARK: - Active Download Row (in-progress)
    private func activeDownloadRow(videoId: String, progress: Double) -> some View {
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
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 28, height: 28)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Downloading...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                ProgressView(value: progress)
                    .tint(.blue)
            }
            
            Spacer()
            
            Button {
                downloadManager.cancelDownload(videoId: videoId)
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
    private func downloadRow(_ download: DownloadedVideo) -> some View {
        Button {
            playDownloadedVideo(download)
        } label: {
            HStack(spacing: 14) {
                // Thumbnail
                AsyncImage(url: URL(string: download.thumbnailUrl)) { image in
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
                    Text(download.formattedDuration)
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
                    
                    Text(download.channelName)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(download.quality.displayName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(download.quality.color)
                            .cornerRadius(3)
                        
                        Text(download.formattedFileSize)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text(download.downloadTimeAgo)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        if download.isWatched {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
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
    
    private func playDownloadedVideo(_ download: DownloadedVideo) {
        HapticManager.shared.impact(style: .light)
        // Post notification to open the video in the global player
        let videoURL = download.localFilePath
        let fileURL = URL(fileURLWithPath: videoURL)
        
        if FileManager.default.fileExists(atPath: videoURL) {
            // Create a Video object from the download for the player
            let video = Video(
                id: download.videoId,
                title: download.title,
                description: "Downloaded video",
                thumbnailURL: download.thumbnailUrl,
                videoURL: fileURL.absoluteString,
                duration: download.duration,
                viewCount: download.viewCount,
                likeCount: 0,
                creator: User(
                    id: download.channelId,
                    username: download.channelName.lowercased().replacingOccurrences(of: " ", with: ""),
                    displayName: download.channelName,
                    email: "",
                    profileImageURL: "",
                    bannerImageURL: nil,
                    bio: "",
                    subscriberCount: 0,
                    videoCount: 0
                ),
                category: .entertainment,
                tags: [],
                isPublic: true
            )
            NotificationCenter.default.post(name: .openVideoFromHistory, object: video)
        } else {
            // File missing — remove stale download
            Task {
                try? await downloadManager.deleteDownload(videoId: download.videoId)
            }
        }
    }
    
    private func deleteDownload(_ download: DownloadedVideo) {
        HapticManager.shared.impact(style: .medium)
        Task {
            try? await downloadManager.deleteDownload(videoId: download.videoId)
        }
    }
    
    private func deleteAllDownloads() {
        HapticManager.shared.impact(style: .heavy)
        Task {
            for download in downloadManager.downloads {
                try? await downloadManager.deleteDownload(videoId: download.videoId)
            }
        }
    }
    
    private func shareDownload(_ download: DownloadedVideo) {
        let url = URL(string: "https://mychannel.live/watch?v=\(download.videoId)")!
        let activityVC = UIActivityViewController(activityItems: [download.title, url], applicationActivities: nil)
        UIApplication.shared.presentShareSheet(activityVC)
    }
}

#Preview {
    ProfileDownloadsTabView()
}
