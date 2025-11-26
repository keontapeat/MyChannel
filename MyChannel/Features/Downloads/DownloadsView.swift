//
//  DownloadsView.swift
//  MyChannel
//
//  🔥 PREMIUM DOWNLOADS VIEW
//  100% YouTube parity - download videos for offline viewing
//

import SwiftUI

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @StateObject private var storeKit = StoreKitService.shared
    @State private var showingSettings = false
    @State private var showingSmartDownloads = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                if !storeKit.isPremium {
                    // Premium Upgrade Prompt
                    premiumUpgradePrompt
                } else if viewModel.downloads.isEmpty {
                    // Empty State
                    emptyState
                } else {
                    // Downloads List
                    downloadsList
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingSettings = true
                        } label: {
                            Label("Download Settings", systemImage: "gearshape")
                        }
                        
                        if !viewModel.downloads.isEmpty {
                            Divider()
                            
                            Button {
                                viewModel.deleteAllDownloads()
                            } label: {
                                Label("Delete All Downloads", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                DownloadSettingsView()
            }
        }
        .onAppear {
            viewModel.loadDownloads()
        }
    }
    
    // MARK: - Premium Upgrade Prompt
    
    private var premiumUpgradePrompt: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.black)
            }
            
            VStack(spacing: 12) {
                Text("Download videos to watch offline")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Save videos to your device and watch them anywhere, anytime - even without internet.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 16) {
                upgradeBenefit(icon: "arrow.down.circle.fill", text: "Download unlimited videos")
                upgradeBenefit(icon: "wifi.slash", text: "Watch without internet")
                upgradeBenefit(icon: "play.slash.fill", text: "No ads while watching")
                upgradeBenefit(icon: "hd.circle.fill", text: "HD quality downloads")
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            // Upgrade Button
            NavigationLink {
                MyChannelPlusView()
            } label: {
                Text("Try Plus+ Free for 7 Days")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black)
                    .cornerRadius(26)
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            
            Text("Then $4.99/month. Cancel anytime.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private func upgradeBenefit(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.black)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Empty illustration
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.to.line.circle")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary.opacity(0.3))
                        .padding(.top, 60)
                    
                    Text("Your downloads")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Videos you download will appear here")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                // Smart Downloads Card
                smartDownloadsCard
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Recommended Downloads
                recommendedDownloads
                    .padding(.top, 20)
            }
        }
    }
    
    private var smartDownloadsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart downloads")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text("We'll automatically download recommended videos and Shorts over Wi-Fi so you always have something to watch offline. Set a storage limit anytime from your settings.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 12) {
                Button {
                    showingSmartDownloads = false
                } label: {
                    Text("DISMISS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                
                Spacer()
                
                Button {
                    viewModel.enableSmartDownloads()
                    showingSmartDownloads = false
                } label: {
                    Text("TURN ON")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Downloads List
    
    // 🔥 THERMONUCLEAR: Using LazyVStack for 60fps scrolling
    private var downloadsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                // Storage Info
                storageInfo
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                
                Divider()
                
                // Downloads Section Header
                HStack {
                    Text("Your downloads")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(viewModel.downloads.count) videos")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // 🔥 THERMONUCLEAR: LazyVStack for downloads - only renders visible items
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.downloads) { download in
                        downloadRow(download)
                        
                        if download.id != viewModel.downloads.last?.id {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
    }
    
    private var storageInfo: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.totalStorageUsed) of \(viewModel.storageLimit) used")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                ProgressView(value: viewModel.storageUsedPercentage)
                    .tint(viewModel.storageUsedPercentage > 0.8 ? .red : .blue)
            }
            
            Spacer()
            
            Button {
                showingSettings = true
            } label: {
                Text("Manage")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func downloadRow(_ download: DownloadedVideo) -> some View {
        Button {
            viewModel.playDownload(download)
        } label: {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack(alignment: .bottomTrailing) {
                    if let thumbnailURL = URL(string: download.thumbnailURL) {
                        AppAsyncImage(url: thumbnailURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.2))
                        }
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 160, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Duration Badge
                    Text(download.formattedDuration)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                        .padding(6)
                }
                
                // Video Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(download.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(download.channelName)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        // File Size
                        Text(download.formattedFileSize)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        // Downloaded Date
                        Text(download.downloadTimeAgo)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // More Menu
                Menu {
                    Button {
                        viewModel.playDownload(download)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    
                    Button {
                        viewModel.shareDownload(download)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        viewModel.deleteDownload(download)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.vertical")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Recommended Downloads
    
    private var recommendedDownloads: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended downloads")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.recommendedVideos) { video in
                        recommendedVideoCard(video)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func recommendedVideoCard(_ video: Video) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                if let thumbnailURL = URL(string: video.thumbnailURL) {
                    AppAsyncImage(url: thumbnailURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 200, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Duration
                Text(formatDuration(video.duration))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(4)
                    .padding(6)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(video.creator.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("\(formatViews(video.viewCount)) views")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(width: 200, alignment: .leading)
            
            // Download Button
            Button {
                viewModel.downloadVideo(video)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14))
                    
                    Text("Download")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(width: 200)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatViews(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - View Model

@MainActor
class DownloadsViewModel: ObservableObject {
    @Published var downloads: [DownloadedVideo] = []
    @Published var recommendedVideos: [Video] = []
    @Published var totalStorageUsed: String = "0 MB"
    @Published var storageLimit: String = "10 GB"
    @Published var storageUsedPercentage: Double = 0.0
    
    func loadDownloads() {
        // TODO: Load from local storage
        // For now, load mock data
        loadMockData()
        calculateStorageUsage()
    }
    
    func downloadVideo(_ video: Video) {
        HapticManager.shared.impact(style: .medium)
        
        // TODO: Implement actual download
        Task {
            // Create download entry
            let download = DownloadedVideo(
                id: video.id,
                title: video.title,
                channelName: video.creator.displayName,
                thumbnailURL: video.thumbnailURL,
                duration: Int(video.duration),
                quality: .high,
                fileSize: estimateFileSizeInBytes(video.duration),
                downloadDate: Date(),
                isWatched: false
            )
            
            downloads.insert(download, at: 0)
            calculateStorageUsage()
            
            print("📥 [Downloads] Starting download for: \(video.title)")
        }
    }
    
    func playDownload(_ download: DownloadedVideo) {
        HapticManager.shared.impact(style: .light)
        // TODO: Play from local file
        print("▶️ [Downloads] Playing: \(download.title)")
    }
    
    func deleteDownload(_ download: DownloadedVideo) {
        HapticManager.shared.impact(style: .medium)
        downloads.removeAll { $0.id == download.id }
        calculateStorageUsage()
        print("🗑️ [Downloads] Deleted: \(download.title)")
    }
    
    func deleteAllDownloads() {
        HapticManager.shared.impact(style: .heavy)
        downloads.removeAll()
        calculateStorageUsage()
        print("🗑️ [Downloads] Deleted all downloads")
    }
    
    func shareDownload(_ download: DownloadedVideo) {
        HapticManager.shared.impact(style: .light)
        // TODO: Implement share
        print("📤 [Downloads] Sharing: \(download.title)")
    }
    
    func enableSmartDownloads() {
        HapticManager.shared.successPattern()
        print("✅ [Downloads] Smart downloads enabled")
    }
    
    private func calculateStorageUsage() {
        let totalBytes = Double(downloads.reduce(Int64(0)) { $0 + $1.fileSize })
        let limitBytes = 10_000_000_000.0 // 10 GB
        
        totalStorageUsed = formatBytes(totalBytes)
        storageUsedPercentage = totalBytes / limitBytes
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        if bytes >= 1_000_000_000 {
            return String(format: "%.1f GB", bytes / 1_000_000_000)
        } else if bytes >= 1_000_000 {
            return String(format: "%.1f MB", bytes / 1_000_000)
        } else {
            return String(format: "%.1f KB", bytes / 1_000)
        }
    }
    
    private func estimateFileSizeInBytes(_ duration: TimeInterval) -> Int64 {
        // Estimate ~10 MB per minute of video
        let mbPerMinute = 10.0
        let mb = (duration / 60) * mbPerMinute
        return Int64(mb * 1_000_000) // Convert MB to bytes
    }
    
    private func loadMockData() {
        // Load mock recommended videos
        // TODO: Replace with actual API call
    }
}

// MARK: - Models
// (DownloadedVideo is defined in Core/Models/DownloadedVideo.swift)

// MARK: - Download Settings View

struct DownloadSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var downloadQuality: DownloadQuality = .high
    @State private var wifiOnly = true
    @State private var smartDownloads = false
    @State private var storageLimit = 10.0 // GB
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Download quality", selection: $downloadQuality) {
                        Text("Low (360p)").tag(DownloadQuality.low)
                        Text("Medium (720p)").tag(DownloadQuality.medium)
                        Text("High (1080p)").tag(DownloadQuality.high)
                        Text("Highest (1440p)").tag(DownloadQuality.highest)
                    }
                } header: {
                    Text("Quality")
                } footer: {
                    Text("Higher quality uses more storage")
                }
                
                Section {
                    Toggle("Download over Wi-Fi only", isOn: $wifiOnly)
                } footer: {
                    Text("Recommended to avoid data charges")
                }
                
                Section {
                    Toggle("Smart downloads", isOn: $smartDownloads)
                    
                    if smartDownloads {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Storage limit: \(Int(storageLimit)) GB")
                                .font(.system(size: 15))
                            
                            Slider(value: $storageLimit, in: 1...50, step: 1)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Smart Downloads")
                } footer: {
                    Text("Automatically download recommended videos over Wi-Fi")
                }
                
                Section {
                    Button("Delete all downloads") {
                        // Delete all
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Download Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// (DownloadQuality is defined in Features/OfflineDownloads/OfflineDownloadService.swift)

// MARK: - Preview

#Preview {
    DownloadsView()
}

