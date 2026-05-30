//
//  NuclearDownloadsView.swift
//  MyChannel
//
//  🔥💎 NUCLEAR DOWNLOADS VIEW 💎🔥
//  YouTube Premium-level Downloads UI
//
//  Features:
//  - Beautiful download list with progress
//  - Smart downloads section
//  - Storage management
//  - Quality settings
//  - Offline indicator
//  - Download queue management
//

import SwiftUI

struct NuclearDownloadsView: View {
    @StateObject private var downloadManager = NuclearDownloadManager.shared
    @StateObject private var smartEngine = SmartDownloadEngine.shared
    @StateObject private var scheduler = DownloadScheduler.shared
    @StateObject private var storeKit = StoreKitService.shared
    
    @State private var showingSettings = false
    @State private var showingSmartDownloads = false
    @State private var selectedDownload: NuclearDownload?
    @State private var showingDeleteConfirmation = false
    @State private var searchText = ""
    
    private var filteredDownloads: [NuclearDownload] {
        if searchText.isEmpty {
            return downloadManager.downloads
        }
        return downloadManager.downloads.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.channelName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var completedDownloads: [NuclearDownload] {
        filteredDownloads.filter { $0.status == .completed }
    }
    
    private var activeDownloads: [NuclearDownload] {
        filteredDownloads.filter { $0.status == .downloading || $0.status == .queued || $0.status == .paused }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                if AppConfig.Features.enableSubscriptions && !storeKit.isPremium {
                    premiumUpgradeView
                } else if downloadManager.downloads.isEmpty && downloadManager.downloadQueue.isEmpty {
                    emptyStateView
                } else {
                    downloadsContent
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search downloads")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        
                        Button {
                            showingSmartDownloads = true
                        } label: {
                            Label("Smart Downloads", systemImage: "sparkles")
                        }
                        
                        if !downloadManager.downloads.isEmpty {
                            Divider()
                            
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete All", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                DownloadSettingsSheet()
            }
            .sheet(isPresented: $showingSmartDownloads) {
                SmartDownloadsSheet()
            }
            .alert("Delete All Downloads?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) {
                    Task {
                        await downloadManager.deleteAllDownloads()
                    }
                }
            } message: {
                Text("This will remove all downloaded videos and free up \(formatBytes(downloadManager.totalStorageUsed)) of storage.")
            }
        }
    }
    
    // MARK: - Premium Upgrade View
    
    private var premiumUpgradeView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)
                
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary.opacity(0.2), AppTheme.Colors.secondary.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 20, y: 10)
                
                VStack(spacing: 16) {
                    Text("Download videos offline")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Save videos and watch them anywhere, anytime - even without internet")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Benefits
                VStack(spacing: 20) {
                    PremiumBenefitRow(icon: "arrow.down.circle.fill", title: "Unlimited Downloads", subtitle: "Download any video")
                    PremiumBenefitRow(icon: "wifi.slash", title: "Watch Offline", subtitle: "No internet needed")
                    PremiumBenefitRow(icon: "sparkles", title: "Smart Downloads", subtitle: "Auto-download recommendations")
                    PremiumBenefitRow(icon: "4k.tv", title: "HD Quality", subtitle: "Up to 4K downloads")
                }
                .padding(.horizontal, 24)
                
                // Upgrade Button
                NavigationLink {
                    MyChannelPlusView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                        Text("Get Plus+ Free for 7 Days")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Text("Then $4.99/month. Cancel anytime.")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 80)
                
                // Illustration
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.to.line.circle")
                        .font(.system(size: 80))
                        .foregroundColor(AppTheme.Colors.textTertiary.opacity(0.5))
                    
                    Text("No downloads yet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Videos you download will appear here")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                // Smart Downloads Card
                if !smartEngine.isEnabled {
                    smartDownloadsPromptCard
                        .padding(.horizontal, 20)
                }
                
                // Recommended Section
                if !smartEngine.recommendedVideos.isEmpty {
                    recommendedSection
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Downloads Content
    
    private var downloadsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Expiration Warning
                if hasExpiringDownloads {
                    expirationWarningBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }

                // Storage Info
                storageInfoCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                // Active Downloads
                if !activeDownloads.isEmpty {
                    Section {
                        ForEach(activeDownloads) { download in
                            ActiveDownloadRow(download: download)
                                .padding(.horizontal, 16)
                        }
                    } header: {
                        HStack {
                            sectionHeader("Downloading", count: activeDownloads.count)
                            Spacer()
                            if activeDownloads.count > 1 {
                                Button {
                                    Task { await downloadManager.pauseAll() }
                                } label: { Image(systemName: "pause.circle.fill").foregroundColor(.orange) }
                                
                                Button {
                                    Task { await downloadManager.resumeAll() }
                                } label: { Image(systemName: "play.circle.fill").foregroundColor(.green) }
                                .padding(.trailing, 16)
                            }
                        }
                        .background(AppTheme.Colors.background)
                    }
                }
                
                // Completed Downloads
                if !completedDownloads.isEmpty {
                    Section {
                        ForEach(completedDownloads) { download in
                            DownloadedVideoRow(download: download) {
                                selectedDownload = download
                            }
                            .padding(.horizontal, 16)
                            
                            if download.id != completedDownloads.last?.id {
                                Divider()
                                    .padding(.leading, 140)
                            }
                        }
                    } header: {
                        sectionHeader("Downloaded", count: completedDownloads.count)
                    }
                }
                
                // Smart Downloads Section
                if smartEngine.isEnabled && !smartEngine.downloadedSmartVideos.isEmpty {
                    Section {
                        smartDownloadsSection
                    } header: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(AppTheme.Colors.primary)
                            Text("Smart Downloads")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.background)
                    }
                }
            }
        }
    }
    
    // MARK: - Storage Info Card
    
    private var storageInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(formatBytes(downloadManager.totalStorageUsed)) of \(formatBytes(downloadManager.storageLimit))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AppTheme.Colors.surface)
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 3)
                                .fill(storageBarColor)
                                .frame(width: geo.size.width * storageUsagePercentage, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                
                Spacer()
                
                Button {
                    showingSettings = true
                } label: {
                    Text("Manage")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            // Network Status
            if downloadManager.networkStatus == .offline {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14))
                    Text("You're offline - downloads will sync when connected")
                        .font(.system(size: 13))
                }
                .foregroundColor(AppTheme.Colors.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    private var storageUsagePercentage: Double {
        guard downloadManager.storageLimit > 0 else { return 0 }
        return min(Double(downloadManager.totalStorageUsed) / Double(downloadManager.storageLimit), 1.0)
    }
    
    private var storageBarColor: Color {
        if storageUsagePercentage > 0.9 {
            return AppTheme.Colors.error
        } else if storageUsagePercentage > 0.7 {
            return AppTheme.Colors.warning
        }
        return AppTheme.Colors.primary
    }
    
    // MARK: - Expiration Banner
    
    private var hasExpiringDownloads: Bool {
        return completedDownloads.contains {
            if let exp = $0.expiresAt {
                return exp.timeIntervalSinceNow < (5 * 24 * 60 * 60) // Less than 5 days
            }
            return false
        }
    }
    
    private var expirationWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text("Connect to the internet soon or some downloads will be removed.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(12)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            
            // Note: Spacer is handled by the caller if they need to add buttons
        }
        .padding(.leading, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Smart Downloads Prompt
    
    private var smartDownloadsPromptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Smart Downloads")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            Text("Automatically download recommended videos when connected to WiFi so you always have something to watch offline.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 12) {
                Button {
                    // Dismiss
                } label: {
                    Text("Not Now")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await smartEngine.enable()
                    }
                } label: {
                    Text("Turn On")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(20)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    // MARK: - Recommended Section
    
    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended for download")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(smartEngine.recommendedVideos.prefix(10)) { rec in
                        RecommendedDownloadCard(recommendation: rec)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 24)
    }
    
    // MARK: - Smart Downloads Section
    
    private var smartDownloadsSection: some View {
        VStack(spacing: 0) {
            ForEach(downloadManager.downloads.filter { smartEngine.downloadedSmartVideos.contains($0.videoId) }) { download in
                DownloadedVideoRow(download: download) {
                    selectedDownload = download
                }
                .padding(.horizontal, 16)
                
                Divider()
                    .padding(.leading, 140)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Active Download Row

struct ActiveDownloadRow: View {
    let download: NuclearDownload
    @StateObject private var downloadManager = NuclearDownloadManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with progress overlay
            ZStack {
                AsyncImage(url: URL(string: download.thumbnailURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.surface)
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Progress overlay
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    
                    if download.status == .downloading {
                        Circle()
                            .trim(from: 0, to: download.progress)
                            .stroke(AppTheme.Colors.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(download.progress * 100))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    } else if download.status == .paused {
                        Image(systemName: "pause.fill")
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(download.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text(download.channelName)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 8) {
                    Text(download.quality.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("•")
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text("\(formatBytes(download.bytesDownloaded)) / \(formatBytes(download.totalBytes))")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            
            Spacer()
            
            // Control button
            Button {
                Task {
                    if download.status == .paused {
                        await downloadManager.resumeDownload(download.id)
                    } else {
                        await downloadManager.pauseDownload(download.id)
                    }
                }
            } label: {
                Image(systemName: download.status == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.surface)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Downloaded Video Row

struct DownloadedVideoRow: View {
    let download: NuclearDownload
    let onTap: () -> Void
    
    @StateObject private var downloadManager = NuclearDownloadManager.shared
    @State private var showingOptions = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: download.thumbnailURL)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Duration badge
                    Text(download.formattedDuration)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                        .padding(4)
                    
                    // Watch progress bar
                    if download.watchProgress > 0 {
                        GeometryReader { geo in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: geo.size.width * download.watchProgress, height: 3)
                            }
                        }
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(download.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(download.channelName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    HStack(spacing: 8) {
                        Text(download.formattedSize)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        if let expiration = download.timeUntilExpiration {
                            Text("•")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text(expiration)
                                .font(.system(size: 11))
                                .foregroundColor(download.isExpired ? AppTheme.Colors.error : AppTheme.Colors.textTertiary)
                        }
                    }
                }
                
                Spacer()
                
                // Menu
                Menu {
                    Button {
                        onTap()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    
                    Button {
                        // Share
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        Task {
                            try? await downloadManager.deleteDownload(download.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recommended Download Card

struct RecommendedDownloadCard: View {
    let recommendation: SmartDownloadRecommendation
    @StateObject private var downloadManager = NuclearDownloadManager.shared
    @State private var isDownloading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: recommendation.video.thumbnailURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(AppTheme.Colors.surface)
            }
            .frame(width: 180, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.video.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text(recommendation.video.creator.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(recommendation.reason.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            .frame(width: 180, alignment: .leading)
            
            // Download button
            Button {
                Task {
                    isDownloading = true
                    _ = try? await downloadManager.downloadVideo(recommendation.video)
                    isDownloading = false
                }
            } label: {
                HStack(spacing: 6) {
                    if isDownloading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 14))
                    }
                    
                    Text("Download")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(AppTheme.Colors.primary.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(width: 180)
            .disabled(isDownloading)
        }
    }
}

// MARK: - Premium Benefit Row

struct PremiumBenefitRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Download Settings Sheet

struct DownloadSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = NuclearDownloadManager.shared
    @StateObject private var scheduler = DownloadScheduler.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Download Quality", selection: $downloadManager.downloadQuality) {
                        ForEach(NuclearDownloadQuality.allCases, id: \.self) { quality in
                            VStack(alignment: .leading) {
                                Text(quality.displayName)
                                Text(quality.estimatedSizePerHour)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(quality)
                        }
                    }
                } header: {
                    Text("Quality")
                } footer: {
                    Text("Higher quality uses more storage space")
                }
                
                Section {
                    Toggle("Download on Wi-Fi only", isOn: $downloadManager.downloadOnWiFiOnly)
                    Toggle("Require charging", isOn: $scheduler.requireCharging)
                    
                    Stepper("Min battery: \(scheduler.minimumBatteryLevel)%", value: $scheduler.minimumBatteryLevel, in: 10...50, step: 5)
                } header: {
                    Text("Network & Power")
                }
                
                Section {
                    Toggle("Smart Downloads", isOn: Binding(
                        get: { SmartDownloadEngine.shared.isEnabled },
                        set: { newValue in
                            Task {
                                if newValue {
                                    await SmartDownloadEngine.shared.enable()
                                } else {
                                    SmartDownloadEngine.shared.disable()
                                }
                            }
                        }
                    ))
                    
                    Toggle("Include Shorts", isOn: $downloadManager.downloadShortsEnabled)
                    Toggle("Auto-delete watched", isOn: $downloadManager.autoDeleteWatched)
                } header: {
                    Text("Automation")
                }
                
                Section {
                    HStack {
                        Text("Storage Limit")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: downloadManager.storageLimit, countStyle: .file))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(downloadManager.storageLimit) / 1_073_741_824 },
                            set: { downloadManager.setStorageLimit(Int64($0 * 1_073_741_824)) }
                        ),
                        in: 1...50,
                        step: 1
                    )
                    
                    HStack {
                        Text("Used")
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: downloadManager.totalStorageUsed, countStyle: .file))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Storage")
                }
                
                Section {
                    Button("Delete All Downloads", role: .destructive) {
                        Task {
                            await downloadManager.deleteAllDownloads()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Download Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Smart Downloads Sheet

struct SmartDownloadsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var smartEngine = SmartDownloadEngine.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Smart Downloads", isOn: Binding(
                        get: { smartEngine.isEnabled },
                        set: { newValue in
                            Task {
                                if newValue {
                                    await smartEngine.enable()
                                } else {
                                    smartEngine.disable()
                                }
                            }
                        }
                    ))
                } footer: {
                    Text("Automatically download recommended videos when connected to Wi-Fi")
                }
                
                if smartEngine.isEnabled {
                    Section {
                        Toggle("From Subscriptions", isOn: $smartEngine.includeSubscriptions)
                        Toggle("Recommended Videos", isOn: $smartEngine.includeRecommended)
                        Toggle("Watch Later", isOn: $smartEngine.includeWatchLater)
                        Toggle("Shorts", isOn: $smartEngine.includeShorts)
                    } header: {
                        Text("Include")
                    }
                    
                    Section {
                        Stepper("Max videos: \(smartEngine.maxVideosToDownload)", value: $smartEngine.maxVideosToDownload, in: 5...50, step: 5)
                        
                        Picker("Refresh", selection: $smartEngine.refreshFrequency) {
                            ForEach(RefreshFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                        
                        Picker("Download Time", selection: $smartEngine.downloadTimeWindow) {
                            ForEach(DownloadTimeWindow.allCases, id: \.self) { window in
                                Text(window.rawValue).tag(window)
                            }
                        }
                    } header: {
                        Text("Settings")
                    }
                    
                    Section {
                        HStack {
                            Text("Storage Allocated")
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: smartEngine.storageAllocated, countStyle: .file))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(smartEngine.storageAllocated) / 1_073_741_824 },
                                set: { smartEngine.setStorageAllocation(Int64($0 * 1_073_741_824)) }
                            ),
                            in: 0.5...10,
                            step: 0.5
                        )
                    } header: {
                        Text("Storage")
                    }
                    
                    Section {
                        Button("Check Now") {
                            Task {
                                await smartEngine.runSmartDownloads()
                            }
                        }
                        
                        if let lastRun = smartEngine.lastSmartDownloadRun {
                            HStack {
                                Text("Last check")
                                Spacer()
                                Text(lastRun, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Smart Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NuclearDownloadsView()
}
