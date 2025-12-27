//
//  ContinueWatchingSection.swift
//  MyChannel
//
//  Continue Watching section for Home - shows videos user started but didn't finish
//

import SwiftUI

// MARK: - Continue Watching Section
struct ContinueWatchingSection: View {
    @ObservedObject private var historyService = HistoryService.shared
    @EnvironmentObject private var appState: AppState
    
    let onVideoTap: (Video) -> Void
    
    @State private var continueWatchingVideos: [ContinueWatchingItem] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if !continueWatchingVideos.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    // Section Header
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text("Continue Watching")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button {
                            HapticManager.shared.impact(style: .light)
                            NotificationCenter.default.post(name: .openFullHistory, object: nil)
                        } label: {
                            Text("See All")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Horizontal Scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(continueWatchingVideos) { item in
                                ContinueWatchingCard(
                                    item: item,
                                    onTap: { onVideoTap(item.video) },
                                    onRemove: { removeFromContinueWatching(item) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            } else if isLoading {
                // Skeleton loader
                ContinueWatchingSkeleton()
            }
        }
        .onAppear {
            loadContinueWatching()
        }
        .onReceive(NotificationCenter.default.publisher(for: .videoProgressUpdated)) { _ in
            loadContinueWatching()
        }
    }
    
    // MARK: - Load Continue Watching
    private func loadContinueWatching() {
        guard let userId = appState.currentUser?.id else {
            isLoading = false
            return
        }
        
        Task { @MainActor in
            isLoading = true
            
            // Fetch watch history with progress
            let history = await historyService.fetch(userId: userId, limit: 20)
            
            // Filter to videos that are partially watched (10% - 90% complete)
            let partiallyWatched = history.compactMap { video -> ContinueWatchingItem? in
                let progress = historyService.getProgress(for: video.id, userId: userId)
                guard progress > 0.1 && progress < 0.9 else { return nil }
                return ContinueWatchingItem(video: video, progress: progress)
            }
            
            continueWatchingVideos = Array(partiallyWatched.prefix(10))
            isLoading = false
        }
    }
    
    private func removeFromContinueWatching(_ item: ContinueWatchingItem) {
        HapticManager.shared.notification(type: .warning)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            continueWatchingVideos.removeAll { $0.id == item.id }
        }
        
        // Clear progress in history service
        if let userId = appState.currentUser?.id {
            Task {
                await historyService.clearProgress(for: item.video.id, userId: userId)
            }
        }
    }
}

// MARK: - Continue Watching Item Model
struct ContinueWatchingItem: Identifiable {
    let id = UUID()
    let video: Video
    let progress: Double // 0.0 - 1.0
    
    var remainingTime: String {
        let remaining = video.duration * (1.0 - progress)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s left"
        } else {
            return "\(seconds)s left"
        }
    }
}

// MARK: - Continue Watching Card
struct ContinueWatchingCard: View {
    let item: ContinueWatchingItem
    let onTap: () -> Void
    let onRemove: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail with progress bar
                ZStack(alignment: .bottomLeading) {
                    // Thumbnail
                    AppAsyncImage(url: URL(string: item.video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                ShimmerView()
                            )
                    }
                    .frame(width: 180, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    // Progress Bar
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 3)
                                
                                Rectangle()
                                    .fill(AppTheme.Colors.primary)
                                    .frame(width: geo.size.width * item.progress, height: 3)
                            }
                        }
                    }
                    .frame(width: 180, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    // Play Button Overlay
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Remove Button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: onRemove) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .padding(6)
                        }
                        Spacer()
                    }
                    .frame(width: 180, height: 100)
                    
                    // Duration Badge
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(item.remainingTime)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.7)))
                                .padding(6)
                        }
                    }
                    .frame(width: 180, height: 100)
                }
                
                // Title
                Text(item.video.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(width: 180, alignment: .leading)
                
                // Channel
                Text(item.video.creator.displayName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Continue Watching Skeleton
struct ContinueWatchingSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Skeleton
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 150, height: 16)
                    .overlay(ShimmerView())
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Cards Skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray5))
                                .frame(width: 180, height: 100)
                                .overlay(ShimmerView())
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(width: 160, height: 12)
                                .overlay(ShimmerView())
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(width: 100, height: 10)
                                .overlay(ShimmerView())
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Shimmer View
struct ShimmerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.4),
                    Color.white.opacity(0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 2)
            .offset(x: isAnimating ? geo.size.width : -geo.size.width)
            .animation(
                Animation.linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
        }
        .clipped()
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let videoProgressUpdated = Notification.Name("videoProgressUpdated")
}

// MARK: - History Service Extension
extension HistoryService {
    func getProgress(for videoId: String, userId: String) -> Double {
        // This would be implemented to fetch from local storage or Firestore
        // For now, return a mock value
        return Double.random(in: 0.1...0.9)
    }
    
    func clearProgress(for videoId: String, userId: String) async {
        // Implementation to clear progress
    }
}

#Preview {
    ContinueWatchingSection(onVideoTap: { _ in })
        .environmentObject(AppState())
}

