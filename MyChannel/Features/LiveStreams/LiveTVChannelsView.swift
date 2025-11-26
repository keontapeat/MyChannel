import SwiftUI

struct LiveTVChannelsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: LiveTVChannel.ChannelCategory? = nil
    @State private var searchText: String = ""
    @State private var viewMode: ViewMode = .grid
    @State private var healthyChannels: [LiveTVChannel] = []
    @State private var isCheckingHealth = true
    @State private var showingPlayer = false
    @State private var selectedChannel: LiveTVChannel?

    enum ViewMode: String, CaseIterable {
        case grid = "grid"
        case list = "list"

        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }

    // Use ALL channels - no filtering!
    private var allChannels: [LiveTVChannel] {
        LiveTVChannel.sampleChannels
    }

    private var filteredChannels: [LiveTVChannel] {
        var channels = healthyChannels.isEmpty ? allChannels : healthyChannels

        if let category = selectedCategory {
            channels = channels.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            channels = channels.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return channels.sorted { $0.viewerCount > $1.viewerCount }
    }
    
    // Category counts for chips
    private func channelCount(for category: LiveTVChannel.ChannelCategory) -> Int {
        allChannels.filter { $0.category == category }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                searchBar
                categoryChips

                ScrollView {
                    if isCheckingHealth {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(AppTheme.Colors.primary)
                            Text("Checking \(allChannels.count) channels...")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .padding(.top, 40)
                    }
                    
                    if viewMode == .grid {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16),
                                            GridItem(.flexible(), spacing: 16)],
                                  spacing: 16) {
                            ForEach(filteredChannels) { channel in
                                MinimalGridChannelCard(channel: channel) { 
                                    playChannel(channel)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredChannels) { channel in
                                MinimalListChannelCard(channel: channel) { 
                                    playChannel(channel)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    Color.clear.frame(height: 16)
                }
            }
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            // Health-rank in the background
            let ranked = await LiveStreamHealthChecker.rankHealthyChannels(allChannels, timeout: 2.0)
            await MainActor.run {
                // If we get healthy channels, use them; otherwise show all
                healthyChannels = ranked.isEmpty ? allChannels : ranked
                isCheckingHealth = false
            }
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let channel = selectedChannel {
                LiveTVPlayerView(channel: channel)
            }
        }
    }

    // MARK: - Header / Search / Filters

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.Colors.surface, in: Circle())
            }
            .buttonStyle(PressableScaleStyle())

            Spacer()

            VStack(spacing: 2) {
                Text("📺 Live TV")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                    Text("\(filteredChannels.count) channels live")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button { viewMode = mode } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(viewMode == mode ? .white : AppTheme.Colors.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(viewMode == mode ? Color.black : AppTheme.Colors.surface, in: Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.Colors.textSecondary)

            TextField("Search channels...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 16))

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.surface))
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "All (\(allChannels.count))", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(LiveTVChannel.ChannelCategory.allCases, id: \.self) { category in
                    let count = channelCount(for: category)
                    if count > 0 {
                        chip(title: "\(category.displayName) (\(count))", selected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.black : AppTheme.Colors.surface, in: Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions

    private func playChannel(_ channel: LiveTVChannel) {
        print("📺 Playing channel: \(channel.name)")
        print("   Stream URL: \(channel.streamURL)")
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Create video object from channel
        let video = Video(
            title: channel.name,
            description: channel.description,
            thumbnailURL: channel.logoURL,
            videoURL: channel.streamURL,
            duration: 0,
            viewCount: channel.viewerCount,
            likeCount: 0,
            creator: User.defaultUser,
            category: mapCategory(channel.category),
            tags: [channel.category.rawValue],
            isPublic: true,
            quality: [.quality720p, .quality1080p],
            aspectRatio: .landscape,
            isLiveStream: true,
            contentSource: nil,
            contentRating: nil,
            language: channel.language,
            isVerified: true
        )
        
        // Use GlobalVideoPlayerManager to play
        GlobalVideoPlayerManager.shared.playVideo(video, showFullscreen: true)
        
        // Post notification to present fullscreen player
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(
                name: NSNotification.Name("PresentVideoDetailFromMiniPlayer"),
                object: nil
            )
        }
    }

    private func mapCategory(_ c: LiveTVChannel.ChannelCategory) -> VideoCategory {
        switch c {
        case .news: return .news
        case .sports: return .sports
        case .entertainment: return .entertainment
        case .movies: return .movies
        case .music: return .music
        case .kids: return .kids
        case .documentary: return .documentaries
        case .lifestyle: return .lifestyle
        case .business: return .news
        case .international: return .news
        }
    }
}

// MARK: - Minimal Grid Card (matches Home style)
private struct MinimalGridChannelCard: View {
    let channel: LiveTVChannel
    let action: () -> Void

    @State private var showPreview = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    if showPreview {
                        LiveChannelThumbnailView(
                            streamURL: channel.streamURL, 
                            posterURL: channel.logoURL, 
                            fallbackStreamURL: channel.previewFallbackURL
                        )
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        // Show channel logo as fallback
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            channel.category.color.opacity(0.2),
                                            channel.category.color.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            AsyncImage(url: URL(string: channel.logoURL)) { image in
                                image.resizable().scaledToFit()
                                    .padding(12)
                            } placeholder: { 
                                VStack(spacing: 4) {
                                    Image(systemName: "tv.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(channel.category.color)
                                    Text(String(channel.name.prefix(3)).uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(channel.category.color)
                                }
                            }
                        }
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    // Play button overlay
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .opacity(isPressed ? 1.0 : 0.8)

                    // LIVE badge
                    if channel.isLive {
                        HStack(spacing: 4) {
                            Circle().fill(.white).frame(width: 4, height: 4)
                            Text("LIVE").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.9)))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    
                    // Quality badge
                    Text(channel.quality)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .onAppear { showPreview = true }
                .onDisappear { showPreview = false }

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(formatViewerCount(channel.viewerCount)) viewers")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }

    private func formatViewerCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Minimal List Card
private struct MinimalListChannelCard: View {
    let channel: LiveTVChannel
    let action: () -> Void

    @State private var showPreview = false
    @State private var isPressed = false
    private let thumbSize = CGSize(width: 160, height: 90)
    private let rowHeight: CGFloat = 114

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    LiveChannelThumbnailView(
                        streamURL: channel.streamURL, 
                        posterURL: channel.logoURL, 
                        fallbackStreamURL: channel.previewFallbackURL
                    )
                    .opacity(showPreview ? 1 : 0)

                    // Fallback logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        channel.category.color.opacity(0.2),
                                        channel.category.color.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        AsyncImage(url: URL(string: channel.logoURL)) { image in
                            image.resizable().scaledToFit()
                                .padding(12)
                        } placeholder: { 
                            VStack(spacing: 4) {
                                Image(systemName: "tv.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(channel.category.color)
                                Text(String(channel.name.prefix(3)).uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(channel.category.color)
                            }
                        }
                    }
                    .opacity(showPreview ? 0 : 1)
                    
                    // Play button
                    Circle()
                        .fill(.white.opacity(0.9))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.black)
                        )

                    // LIVE badge overlay
                    if channel.isLive {
                        HStack(spacing: 4) {
                            Circle().fill(.white).frame(width: 4, height: 4)
                            Text("LIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.red.opacity(0.9)))
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .frame(width: thumbSize.width, height: thumbSize.height)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Text area
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(channel.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        // Category badge
                        Text(channel.category.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(channel.category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(channel.category.color.opacity(0.15))
                            )
                        
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(formatViewerCount(channel.viewerCount)) • \(channel.quality)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: rowHeight, alignment: .center)
            .contentShape(Rectangle())
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.surface)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onAppear { showPreview = true }
        .onDisappear { showPreview = false }
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }

    private func formatViewerCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

#Preview("Live TV - All Channels") {
    LiveTVChannelsView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}
