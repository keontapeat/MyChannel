//
//  PlaylistDownloadButton.swift
//  MyChannel
//
//  Created by Antigravity on 2026-05-28.
//

import SwiftUI

/// A component that allows downloading an entire array of videos (like a playlist or album)
/// with a single tap, achieving 100% YouTube Premium parity.
struct PlaylistDownloadButton: View {
    let videos: [Video]
    let playlistTitle: String
    
    @StateObject private var downloadManager = NuclearDownloadManager.shared
    @State private var isDownloading = false
    @State private var showQualityPrompt = false
    @State private var selectedQuality: NuclearDownloadQuality = NuclearDownloadManager.shared.downloadQuality
    
    // Check if any videos in the playlist are already downloaded or active
    private var activeCount: Int {
        videos.filter { video in
            downloadManager.downloads.contains(where: { $0.videoId == video.id })
        }.count
    }
    
    private var isFullyDownloaded: Bool {
        activeCount == videos.count && !videos.isEmpty
    }
    
    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack(spacing: 6) {
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if isFullyDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.primary)
                } else {
                    Image(systemName: "arrow.down.circle")
                }
                
                Text(isFullyDownloaded ? "Downloaded" : "Download Playlist")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isFullyDownloaded ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isFullyDownloaded ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface)
            .cornerRadius(20)
        }
        .disabled(isDownloading || videos.isEmpty)
        .confirmationDialog("Select Download Quality", isPresented: $showQualityPrompt, titleVisibility: .visible) {
            ForEach(NuclearDownloadQuality.allCases.filter { $0 != .askEachTime }, id: \.self) { quality in
                Button(quality.displayName) {
                    startBulkDownload(quality: quality)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("How would you like to download '\(playlistTitle)'?")
        }
    }
    
    private func handleTap() {
        if isFullyDownloaded {
            // Option to delete could go here, but for now do nothing
            return
        }
        
        if downloadManager.downloadQuality == .askEachTime {
            showQualityPrompt = true
        } else {
            startBulkDownload(quality: downloadManager.downloadQuality)
        }
    }
    
    private func startBulkDownload(quality: NuclearDownloadQuality) {
        isDownloading = true
        
        Task {
            let results = await downloadManager.downloadVideos(videos, quality: quality)
            
            // Check for failures (e.g. storage limit)
            let failures = results.compactMap { result -> Error? in
                if case .failure(let error) = result { return error }
                return nil
            }
            
            if !failures.isEmpty {
                print("⚠️ [Nuclear] \(failures.count) videos failed to queue.")
                // You could present an alert here about storage space
            }
            
            isDownloading = false
        }
    }
}
