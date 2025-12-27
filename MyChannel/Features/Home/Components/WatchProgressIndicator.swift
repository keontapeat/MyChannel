//
//  WatchProgressIndicator.swift
//  MyChannel
//
//  Watch progress indicator overlay for video thumbnails
//

import SwiftUI

// MARK: - Watch Progress Indicator
struct WatchProgressIndicator: View {
    let progress: Double // 0.0 - 1.0
    let height: CGFloat
    
    init(progress: Double, height: CGFloat = 3) {
        self.progress = min(max(progress, 0), 1) // Clamp to 0-1
        self.height = height
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                
                // Progress
                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: geo.size.width * progress)
            }
            .frame(height: height)
        }
        .frame(height: height)
    }
}

// MARK: - Video Thumbnail with Progress
struct VideoThumbnailWithProgress: View {
    let thumbnailURL: String
    let duration: TimeInterval
    let progress: Double? // nil = not watched, 0-1 = partially watched
    let cornerRadius: CGFloat
    
    init(
        thumbnailURL: String,
        duration: TimeInterval,
        progress: Double? = nil,
        cornerRadius: CGFloat = 12
    ) {
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.progress = progress
        self.cornerRadius = cornerRadius
    }
    
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Thumbnail
                AppAsyncImage(url: URL(string: thumbnailURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(ShimmerView())
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                
                // Duration Badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formattedDuration)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.black.opacity(0.8))
                            )
                            .padding(6)
                    }
                }
                
                // Progress Bar (if watched)
                if let progress = progress, progress > 0 {
                    WatchProgressIndicator(progress: progress)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

// MARK: - Enhanced Video Card with Progress
struct EnhancedVideoCard: View {
    let video: Video
    let watchProgress: Double?
    let onTap: () -> Void
    let onLongPress: (() -> Void)?
    
    @State private var isPressed = false
    @EnvironmentObject private var appState: AppState
    
    init(
        video: Video,
        watchProgress: Double? = nil,
        onTap: @escaping () -> Void,
        onLongPress: (() -> Void)? = nil
    ) {
        self.video = video
        self.watchProgress = watchProgress
        self.onTap = onTap
        self.onLongPress = onLongPress
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                // Thumbnail with progress
                VideoThumbnailWithProgress(
                    thumbnailURL: video.thumbnailURL,
                    duration: video.duration,
                    progress: watchProgress,
                    cornerRadius: 12
                )
                .aspectRatio(16/9, contentMode: .fit)
                
                // Video Info
                HStack(alignment: .top, spacing: 10) {
                    // Channel Avatar
                    ProfileAvatarView(urlString: video.creator.profileImageURL, size: 36)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Title
                        Text(video.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Meta info
                        HStack(spacing: 4) {
                            Text(video.creator.displayName)
                            Text("•")
                            Text("\(video.formattedViewCount) views")
                            Text("•")
                            Text(video.timeAgo)
                        }
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // More Options
                    Button {
                        HapticManager.shared.impact(style: .light)
                        // Show options menu
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            isPressed = pressing
        }) {
            HapticManager.shared.impact(style: .medium)
            onLongPress?()
        }
    }
}

// MARK: - Watch Progress Service
@MainActor
class WatchProgressService: ObservableObject {
    static let shared = WatchProgressService()
    
    @Published private var progressCache: [String: Double] = [:]
    
    private init() {
        loadFromStorage()
    }
    
    func getProgress(for videoId: String) -> Double? {
        return progressCache[videoId]
    }
    
    func setProgress(_ progress: Double, for videoId: String) {
        progressCache[videoId] = progress
        saveToStorage()
        
        // Notify observers
        NotificationCenter.default.post(name: .videoProgressUpdated, object: videoId)
    }
    
    func clearProgress(for videoId: String) {
        progressCache.removeValue(forKey: videoId)
        saveToStorage()
    }
    
    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "watchProgressCache"),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            progressCache = decoded
        }
    }
    
    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(progressCache) {
            UserDefaults.standard.set(encoded, forKey: "watchProgressCache")
        }
    }
}

#Preview("Progress Indicator") {
    VStack(spacing: 20) {
        WatchProgressIndicator(progress: 0.3)
            .frame(width: 200)
        
        WatchProgressIndicator(progress: 0.7)
            .frame(width: 200)
        
        WatchProgressIndicator(progress: 1.0)
            .frame(width: 200)
    }
    .padding()
}

#Preview("Thumbnail with Progress") {
    VStack(spacing: 20) {
        VideoThumbnailWithProgress(
            thumbnailURL: "https://picsum.photos/640/360",
            duration: 325,
            progress: 0.4
        )
        .frame(width: 300, height: 170)
        
        VideoThumbnailWithProgress(
            thumbnailURL: "https://picsum.photos/640/360",
            duration: 180,
            progress: nil
        )
        .frame(width: 300, height: 170)
    }
    .padding()
}

