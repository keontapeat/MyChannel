import SwiftUI
import FirebaseAuth

struct DownloadsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var mlService = DownloadMLService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingSettings = false
    @State private var showingUpgrade = false
    @State private var selectedVideo: DownloadedVideo?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if !subscriptionService.isPlusSubscriber {
                    plusUpgradePrompt
                } else if downloadManager.downloads.isEmpty && !downloadManager.isLoading {
                    emptyDownloadsState
                } else {
                    downloadsContent
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Downloads")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        
                    } label: {
                        Image(systemName: "airplayvideo")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "ellipsis.vertical")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                DownloadSettingsView()
            }
            .sheet(isPresented: $showingUpgrade) {
                MyChannelPlusView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadContent()
        }
    }
    
    // MARK: - Load Content
    
    private func loadContent() async {
        downloadManager.loadDownloads()
        await mlService.fetchRecommendedDownloads(limit: 10)
    }
    
    // MARK: - Plus Upgrade Prompt
    
    private var plusUpgradePrompt: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 60)
                
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white)
                    
                    Text("Download videos to watch offline")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Get MyChannel Plus to download videos and watch them anywhere, anytime - even without internet.")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    plusFeature(icon: "arrow.down.circle.fill", title: "Download unlimited videos")
                    plusFeature(icon: "wifi.slash", title: "Watch without internet")
                    plusFeature(icon: "play.slash.fill", title: "Ad-free viewing")
                    plusFeature(icon: "hd.circle.fill", title: "HD quality downloads")
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                Button {
                    showingUpgrade = true
                } label: {
                    Text("Try Plus Free")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                
                Text("Then $4.99/month. Cancel anytime.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                
                Spacer()
            }
        }
    }
    
    private func plusFeature(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.white)
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Empty Downloads State
    
    private var emptyDownloadsState: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 60)
                
                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.to.line.circle")
                        .font(.system(size: 72))
                        .foregroundColor(.gray)
                    
                    Text("Your downloads")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Videos you download will appear here")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
                
                if !mlService.recommendedDownloads.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recommended downloads")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        ForEach(mlService.recommendedDownloads.prefix(5)) { video in
                            recommendedDownloadRow(video)
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Downloads Content
    
    private var downloadsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                storageHeader
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)
                
                HStack {
                    Text("Your downloads")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(downloadManager.downloads.count) videos")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                ForEach(downloadManager.downloads) { download in
                    downloadedVideoRow(download)
                }
                
                if !mlService.recommendedDownloads.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recommended downloads")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 8)
                        
                        ForEach(mlService.recommendedDownloads) { video in
                            recommendedDownloadRow(video)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Storage Header
    
    private var storageHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive")
                .font(.system(size: 20))
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(downloadManager.getFormattedTotalStorage()) used")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                ProgressView(value: Double(downloadManager.getTotalStorageUsed()) / 10_000_000_000.0)
                    .tint(.blue)
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
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Downloaded Video Row
    
    private func downloadedVideoRow(_ download: DownloadedVideo) -> some View {
        Button {
            selectedVideo = download
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: download.thumbnailUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 168, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    Text(download.formattedDuration)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(4)
                        .padding(6)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(download.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(download.channelName)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(download.formattedViewCount)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text(download.formattedFileSize)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button {
                        
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    
                    Button {
                        
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        Task {
                            try? await downloadManager.deleteDownload(videoId: download.videoId)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.vertical")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Recommended Download Row
    
    private func recommendedDownloadRow(_ video: RecommendedDownload) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 168, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    Text(video.formattedDuration)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(4)
                        .padding(6)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(video.channelName)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Text(video.formattedViewCount)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button {
                    
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Download Settings View

struct DownloadSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var downloadQuality: DownloadedVideo.VideoQuality = .high
    @State private var wifiOnly = true
    @State private var smartDownloads = false
    @State private var storageLimit = 10.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                Form {
                    Section {
                        Picker("Download quality", selection: $downloadQuality) {
                            Text("Low (360p)").tag(DownloadedVideo.VideoQuality.low)
                            Text("Medium (480p)").tag(DownloadedVideo.VideoQuality.medium)
                            Text("High (720p)").tag(DownloadedVideo.VideoQuality.high)
                            Text("HD (1080p)").tag(DownloadedVideo.VideoQuality.hd)
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
                                    .foregroundColor(.white)
                                
                                Slider(value: $storageLimit, in: 1...50, step: 1)
                                    .tint(.blue)
                            }
                            .padding(.vertical, 8)
                        }
                    } header: {
                        Text("Smart Downloads")
                    } footer: {
                        Text("Automatically download recommended videos over Wi-Fi")
                    }
                    
                    Section {
                        HStack {
                            Text("Total storage used")
                                .foregroundColor(.white)
                            Spacer()
                            Text(downloadManager.getFormattedTotalStorage())
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Section {
                        Button("Delete all downloads") {
                            Task {
                                for download in downloadManager.downloads {
                                    try? await downloadManager.deleteDownload(videoId: download.videoId)
                                }
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Download Settings")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    DownloadsView()
}

