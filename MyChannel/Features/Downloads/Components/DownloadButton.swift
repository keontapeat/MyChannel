import SwiftUI
import FirebaseAuth

struct DownloadButton: View {
    let videoId: String
    let title: String
    let channelName: String
    let channelId: String
    let thumbnailUrl: String
    let duration: TimeInterval
    let viewCount: Int
    let videoUrl: String
    
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingQualityPicker = false
    @State private var showingUpgrade = false
    @State private var selectedQuality: DownloadedVideo.VideoQuality = .high
    
    private var isDownloaded: Bool {
        downloadManager.isVideoDownloaded(videoId: videoId)
    }
    
    private var downloadProgress: Double? {
        downloadManager.activeDownloads[videoId]
    }
    
    var body: some View {
        Button {
            handleDownloadTap()
        } label: {
            ZStack {
                if let progress = downloadProgress {
                    // Downloading state
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.white, lineWidth: 2)
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 32, height: 32)
                } else if isDownloaded {
                    // Downloaded state
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                } else {
                    // Not downloaded state
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
        }
        .confirmationDialog("Download Quality", isPresented: $showingQualityPicker) {
            Button("Low (360p) - ~50MB") {
                selectedQuality = .low
                startDownload()
            }
            
            Button("Medium (480p) - ~100MB") {
                selectedQuality = .medium
                startDownload()
            }
            
            Button("High (720p) - ~200MB") {
                selectedQuality = .high
                startDownload()
            }
            
            Button("HD (1080p) - ~400MB") {
                selectedQuality = .hd
                startDownload()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose download quality")
        }
        .sheet(isPresented: $showingUpgrade) {
            MyChannelPlusView()
        }
    }
    
    private func handleDownloadTap() {
        if let progress = downloadProgress {
            downloadManager.cancelDownload(videoId: videoId)
        } else if isDownloaded {
            // Already downloaded, could show options
        } else {
            if subscriptionService.isPlusSubscriber {
                showingQualityPicker = true
            } else {
                showingUpgrade = true
            }
        }
    }
    
    private func startDownload() {
        Task {
            do {
                try await downloadManager.downloadVideo(
                    videoId: videoId,
                    title: title,
                    channelName: channelName,
                    channelId: channelId,
                    thumbnailUrl: thumbnailUrl,
                    duration: duration,
                    viewCount: viewCount,
                    videoUrl: videoUrl,
                    quality: selectedQuality
                )
            } catch {
                print("Download error: \(error.localizedDescription)")
            }
        }
    }
}

struct CompactDownloadButton: View {
    let videoId: String
    let title: String
    let channelName: String
    let channelId: String
    let thumbnailUrl: String
    let duration: TimeInterval
    let viewCount: Int
    let videoUrl: String
    
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingQualityPicker = false
    @State private var showingUpgrade = false
    @State private var selectedQuality: DownloadedVideo.VideoQuality = .high
    
    private var isDownloaded: Bool {
        downloadManager.isVideoDownloaded(videoId: videoId)
    }
    
    var body: some View {
        Button {
            if subscriptionService.isPlusSubscriber {
                showingQualityPicker = true
            } else {
                showingUpgrade = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 16))
                
                Text(isDownloaded ? "Downloaded" : "Download")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isDownloaded ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(20)
        }
        .confirmationDialog("Download Quality", isPresented: $showingQualityPicker) {
            Button("Low (360p) - ~50MB") {
                selectedQuality = .low
                startDownload()
            }
            
            Button("Medium (480p) - ~100MB") {
                selectedQuality = .medium
                startDownload()
            }
            
            Button("High (720p) - ~200MB") {
                selectedQuality = .high
                startDownload()
            }
            
            Button("HD (1080p) - ~400MB") {
                selectedQuality = .hd
                startDownload()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose download quality")
        }
        .sheet(isPresented: $showingUpgrade) {
            MyChannelPlusView()
        }
    }
    
    private func startDownload() {
        Task {
            do {
                try await downloadManager.downloadVideo(
                    videoId: videoId,
                    title: title,
                    channelName: channelName,
                    channelId: channelId,
                    thumbnailUrl: thumbnailUrl,
                    duration: duration,
                    viewCount: viewCount,
                    videoUrl: videoUrl,
                    quality: selectedQuality
                )
            } catch {
                print("Download error: \(error.localizedDescription)")
            }
        }
    }
}
