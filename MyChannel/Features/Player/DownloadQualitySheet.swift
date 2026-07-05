//
//  DownloadQualitySheet.swift
//  MyChannel
//
//  YouTube Premium-style download quality selection sheet
//

import SwiftUI
#if canImport(Network)
import Network
#endif

struct DownloadQualitySheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @StateObject private var premiumService = PremiumService.shared
    @StateObject private var offlineService = OfflineDownloadService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var selectedQuality: DownloadQuality = .medium
    @State private var isDownloading: Bool = false
    @State private var downloadProgress: Double = 0.0
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingPremiumAlert: Bool = false
    
    private let availableQualities: [DownloadQuality] = [.low, .medium, .high]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Video Info Header
                videoInfoHeader
                
                // Quality Selection
                qualitySelectionSection
                
                // Download Settings
                downloadSettingsSection
                
                // Download Info
                downloadInfoSection
                
                Spacer()
                
                // Download Button
                downloadButton
            }
            .navigationTitle("Download Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Premium Required", isPresented: $showingPremiumAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Get Premium") {
                    NotificationCenter.default.post(name: .navigateToPremium, object: nil)
                }
            } message: {
                Text("Offline downloads are only available with MyChannel Premium. Upgrade to download videos and watch offline.")
            }
            .alert("Download Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Video Info Header
    private var videoInfoHeader: some View {
        HStack(spacing: 12) {
            AppAsyncImage(url: URL(string: video.thumbnailURL)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(video.creator.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(formatDuration(video.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Quality Selection Section
    private var qualitySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Video Quality")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(availableQualities, id: \.self) { quality in
                    Button {
                        selectedQuality = quality
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        HStack {
                            Image(systemName: selectedQuality == quality ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedQuality == quality ? .blue : .gray)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(quality.displayName.components(separatedBy: " ").first ?? quality.rawValue)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text(quality.estimatedSize)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedQuality == quality {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(
                            selectedQuality == quality
                                ? Color.blue.opacity(0.1)
                                : Color(.systemGray6)
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedQuality == quality ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Download Settings Section
    private var downloadSettingsSection: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $offlineService.downloadOnlyOnWiFi) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download on Wi‑Fi only")
                        .font(.body)
                    
                    Text("Save data by only downloading when connected to Wi‑Fi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Download Info Section
    private var downloadInfoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("Downloads expire after 48 hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack {
                Image(systemName: "wifi")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("You can refresh downloads while connected to Wi‑Fi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Download Button
    private var downloadButton: some View {
        Button {
            Task {
                await startDownload()
            }
        } label: {
            HStack {
                if isDownloading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text("Downloading... \(Int(downloadProgress * 100))%")
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Download")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDownloading || (AppConfig.Features.enableSubscriptions && !subscriptionService.isPlusSubscriber && !premiumService.isPremium))
        .padding()
    }
    
    // MARK: - Helper Functions
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
    
    // MARK: - Download Action
    private func startDownload() async {
        // Check premium via Firestore-backed subscription
        // 🔥 FIX 2.1(b): Skip premium check when IAPs not submitted
        if AppConfig.Features.enableSubscriptions {
            guard subscriptionService.isPlusSubscriber || premiumService.isPremium else {
                await MainActor.run {
                    showingPremiumAlert = true
                }
                return
            }
        }
        
        // Check WiFi if required
        if offlineService.downloadOnlyOnWiFi && !isOnWiFi() {
            await MainActor.run {
                errorMessage = "Wi‑Fi connection required. Please connect to Wi‑Fi to download this video."
                showingError = true
            }
            return
        }
        
        // Check if already downloaded via offline service
        if offlineService.isVideoAvailableOffline(video.id) || offlineService.downloads.contains(where: { $0.videoId == video.id }) {
            await MainActor.run {
                errorMessage = "This video is already downloaded."
                showingError = true
            }
            return
        }
        
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
        }
        
        do {
            try await offlineService.downloadVideo(video, quality: selectedQuality)
            
            await monitorDownloadProgress(videoId: video.id)
            
            await MainActor.run {
                isDownloading = false
                downloadProgress = 1.0
                HapticManager.shared.notification(type: .success)
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDownloading = false
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func monitorDownloadProgress(videoId: String) async {
        while isDownloading {
            do {
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            } catch {
                break
            }
            
            if let download = offlineService.downloads.first(where: { $0.videoId == videoId }) {
                await MainActor.run {
                    downloadProgress = download.progress
                }
                if download.status == .completed {
                    await MainActor.run {
                        downloadProgress = 1.0
                        isDownloading = false
                    }
                } else if download.status == .failed {
                    await MainActor.run {
                        isDownloading = false
                        errorMessage = "Download failed. Please try again."
                        showingError = true
                    }
                }
            } else if offlineService.isVideoAvailableOffline(videoId) {
                // Download completed
                await MainActor.run {
                    downloadProgress = 1.0
                    isDownloading = false
                }
            } else {
                break
            }
        }
    }
    
    private func isOnWiFi() -> Bool {
        // Check for WiFi using Network framework
        #if canImport(Network)
        let monitor = NWPathMonitor()
        var isWifi = false
        let sem = DispatchSemaphore(value: 0)
        monitor.pathUpdateHandler = { path in
            isWifi = path.usesInterfaceType(.wifi)
            sem.signal()
        }
        monitor.start(queue: DispatchQueue.global())
        _ = sem.wait(timeout: .now() + 0.1)
        monitor.cancel()
        return isWifi
        #else
        return true
        #endif
    }
}

