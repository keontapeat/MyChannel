//
//  ProfileDownloadsView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct ProfileDownloadsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var downloads: [ProfileDownloadedVideo] = []
    @State private var selectedQuality: DownloadQuality = .high
    @State private var isLoading: Bool = true
    @State private var showingDeleteAlert: Bool = false
    @State private var videoToDelete: ProfileDownloadedVideo?
    @State private var showingDeleteAllAlert: Bool = false
    @State private var totalStorageUsed: Int64 = 0
    
    private var totalStorageText: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .binary)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if downloads.isEmpty {
                    emptyStateView
                } else {
                    // Storage Info
                    storageInfoSection
                    
                    // Downloads List
                    downloadsListView
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .fontWeight(.semibold)
                }
                
                if !downloads.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            showingDeleteAllAlert = true
                            HapticManager.shared.impact(style: .light)
                        }
                        .foregroundColor(AppTheme.Colors.error)
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                loadDownloads()
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
                    Text("Are you sure you want to delete \"\(video.title)\"? This will free up \(ByteCountFormatter.string(fromByteCount: video.fileSize, countStyle: .binary)) of storage.")
                }
            }
            .alert("Clear All Downloads", isPresented: $showingDeleteAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearAllDownloads()
                }
            } message: {
                Text("Are you sure you want to delete all downloads? This will free up \(totalStorageText) of storage.")
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppTheme.Colors.primary)
            
            Text("Loading downloads...")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 100)
                
                // Illustration
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppTheme.Colors.primary.opacity(0.1),
                                    AppTheme.Colors.primary.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                .shadow(color: AppTheme.Colors.primary.opacity(0.2), radius: 20, x: 0, y: 8)
                
                // Content
                VStack(spacing: 16) {
                    Text("No Downloads")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Download videos to watch offline. Your downloads will appear here and can be accessed without an internet connection.")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 20)
                }
                
                // Benefits Section
                VStack(spacing: 16) {
                    Text("Download Benefits")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    VStack(spacing: 12) {
                        DownloadBenefitRow(
                            icon: "wifi.slash",
                            text: "Watch without internet connection"
                        )
                        
                        DownloadBenefitRow(
                            icon: "battery.100",
                            text: "Save battery and data usage"
                        )
                        
                        DownloadBenefitRow(
                            icon: "4k.tv",
                            text: "Choose your preferred quality"
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // MARK: - Storage Info Section
    private var storageInfoSection: some View {
        VStack(spacing: 16) {
            // Storage Usage
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage Used")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(totalStorageText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Downloads")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("\(downloads.count) videos")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 20)
            
            // Quality Selector
            HStack {
                Text("Default Quality")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Picker("Quality", selection: $selectedQuality) {
                    ForEach(DownloadQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName)
                            .tag(quality)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Colors.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Downloads List View
    private var downloadsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(downloads) { video in
                    ProfileDownloadedVideoRow(
                        video: video,
                        onDelete: {
                            videoToDelete = video
                            showingDeleteAlert = true
                        },
                        onPlay: {
                            // Handle video playback
                            HapticManager.shared.impact(style: .light)
                        }
                    )
                    
                    if video.id != downloads.last?.id {
                        Divider()
                            .padding(.leading, 80)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadDownloads() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Simulate loading downloads
            downloads = [
                ProfileDownloadedVideo(
                    id: "1",
                    title: "Swift UI Advanced Techniques",
                    channelName: "Tech Channel",
                    thumbnailURL: "https://example.com/thumb1.jpg",
                    duration: 1200,
                    quality: .high,
                    fileSize: 250 * 1024 * 1024, // 250 MB
                    downloadDate: Date(),
                    isWatched: false
                ),
                ProfileDownloadedVideo(
                    id: "2",
                    title: "iOS Development Best Practices",
                    channelName: "Developer Hub",
                    thumbnailURL: "https://example.com/thumb2.jpg",
                    duration: 900,
                    quality: .medium,
                    fileSize: 180 * 1024 * 1024, // 180 MB
                    downloadDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                    isWatched: true
                ),
                ProfileDownloadedVideo(
                    id: "3",
                    title: "Building Modern Apps",
                    channelName: "Code Masters",
                    thumbnailURL: "https://example.com/thumb3.jpg",
                    duration: 1800,
                    quality: .ultra,
                    fileSize: 450 * 1024 * 1024, // 450 MB
                    downloadDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                    isWatched: false
                )
            ]
            
            totalStorageUsed = downloads.reduce(0) { $0 + $1.fileSize }
            isLoading = false
        }
    }
    
    private func deleteDownload(_ video: ProfileDownloadedVideo) {
        HapticManager.shared.impact(style: .medium)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            downloads.removeAll { $0.id == video.id }
            totalStorageUsed -= video.fileSize
        }
    }
    
    private func clearAllDownloads() {
        HapticManager.shared.impact(style: .heavy)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            downloads.removeAll()
            totalStorageUsed = 0
        }
    }
}

// MARK: - Downloaded Video Row
struct ProfileDownloadedVideoRow: View {
    let video: ProfileDownloadedVideo
    let onDelete: () -> Void
    let onPlay: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 16) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .overlay(
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.primary)
                        )
                }
                .frame(width: 64, height: 36)
                .cornerRadius(8)
                .overlay(
                    // Duration badge
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formatDuration(video.duration))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                                .padding(4)
                        }
                    }
                )
                
                // Video Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(video.channelName)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        // Quality badge
                        Text(video.quality.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(4)
                        
                        // File size
                        Text(ByteCountFormatter.string(fromByteCount: video.fileSize, countStyle: .binary))
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        // Watch status
                        if video.isWatched {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Action button
                Button {
                    onDelete()
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.error)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.Colors.error.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.clear)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    private func formatDuration(_ duration: Int) -> String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Benefit Row
struct DownloadBenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Profile Downloaded Video Model
struct ProfileDownloadedVideo: Identifiable {
    let id: String
    let title: String
    let channelName: String
    let thumbnailURL: String
    let duration: Int // in seconds
    let quality: DownloadQuality
    let fileSize: Int64 // in bytes
    let downloadDate: Date
    let isWatched: Bool
}

#Preview {
    ProfileDownloadsView()
        .environmentObject(AuthenticationManager.shared)
}