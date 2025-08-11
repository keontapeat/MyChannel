import SwiftUI

struct LiveTVChannelsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: LiveTVChannel.ChannelCategory? = nil
    @State private var searchText: String = ""
    @State private var viewMode: ViewMode = .grid
    
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
    
    private var allChannels: [LiveTVChannel] {
        // Later replace with LiveTVService.shared.fetchChannels()
        LiveTVChannel.sampleChannels + [
            // Additional sample channels for variety
            LiveTVChannel(
                id: "pluto-espn",
                name: "ESPN Classic",
                logoURL: "https://images.pluto.tv/channels/espn-classic/colorLogoPNG.png",
                streamURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/espn-classic/master.m3u8",
                category: .sports,
                description: "Classic sports moments and games",
                isLive: true,
                viewerCount: 25430,
                quality: "HD",
                language: "English",
                country: "US",
                epgURL: nil
            ),
            LiveTVChannel(
                id: "plex-bloomberg",
                name: "Bloomberg TV",
                logoURL: "https://provider-static.plex.tv/epg/images/ott_channels/logos/bloomberg-tv.png",
                streamURL: "https://bloomberg.com/media-manifest/streams/qt.m3u8",
                category: .business,
                description: "Financial news and market analysis",
                isLive: true,
                viewerCount: 12890,
                quality: "HD",
                language: "English",
                country: "US",
                epgURL: nil
            ),
            LiveTVChannel(
                id: "roku-kids-tv",
                name: "Kids TV",
                logoURL: "https://image.roku.com/developer_channels/prod/kids-tv-logo.png",
                streamURL: "https://service-stitcher.clusters.pluto.tv/stitch/hls/channel/kids-tv/master.m3u8",
                category: .kids,
                description: "Educational and entertaining content for children",
                isLive: true,
                viewerCount: 18750,
                quality: "HD",
                language: "English",
                country: "US",
                epgURL: nil
            )
        ]
    }
    
    private var filteredChannels: [LiveTVChannel] {
        var channels = allChannels
        
        // Filter by category
        if let category = selectedCategory {
            channels = channels.filter { $0.category == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            channels = channels.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return channels.sorted { $0.viewerCount > $1.viewerCount }
    }
    
    private var channelsByCategory: [LiveTVChannel.ChannelCategory: [LiveTVChannel]] {
        Dictionary(grouping: filteredChannels) { $0.category }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .background(
                                Circle()
                                    .fill(AppTheme.Colors.surface)
                                    .frame(width: 32, height: 32)
                            )
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("📺 Live TV")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                            
                            Text("\(filteredChannels.count) channels live")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // View Mode Toggle
                    HStack(spacing: 8) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Button(action: { viewMode = mode }) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(viewMode == mode ? .white : AppTheme.Colors.textSecondary)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(viewMode == mode ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    TextField("Search channels...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 16))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.surface)
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // All Categories Button
                        Button(action: { selectedCategory = nil }) {
                            HStack(spacing: 6) {
                                Text("📺 All Channels")
                                    .font(.system(size: 14, weight: .semibold))
                                
                                Text("(\(allChannels.count))")
                                    .font(.system(size: 12))
                                    .opacity(0.7)
                            }
                            .foregroundColor(selectedCategory == nil ? .white : AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == nil ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                            )
                        }
                        
                        ForEach(LiveTVChannel.ChannelCategory.allCases, id: \.self) { category in
                            let count = allChannels.filter { $0.category == category }.count
                            if count > 0 {
                                Button(action: { selectedCategory = category }) {
                                    HStack(spacing: 6) {
                                        Text(category.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                        
                                        Text("(\(count))")
                                            .font(.system(size: 12))
                                            .opacity(0.7)
                                    }
                                    .foregroundColor(selectedCategory == category ? .white : AppTheme.Colors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedCategory == category ? category.color : AppTheme.Colors.surface)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 16)
                
                // Channels Content
                ScrollView {
                    if viewMode == .grid {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(filteredChannels) { channel in
                                GridChannelCard(channel: channel) {
                                    play(channel)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredChannels) { channel in
                                ListChannelCard(channel: channel) {
                                    play(channel)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
        .background(AppTheme.Colors.background)
    }
    
    private func play(_ channel: LiveTVChannel) {
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
        GlobalVideoPlayerManager.shared.playVideo(video, showFullscreen: true)
        NotificationCenter.default.post(name: NSNotification.Name("PresentVideoDetailFromMiniPlayer"), object: nil)
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

// MARK: - Grid Channel Card
struct GridChannelCard: View {
    let channel: LiveTVChannel
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Channel Logo Container
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    channel.category.color.opacity(0.1),
                                    channel.category.color.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(channel.category.color.opacity(0.3), lineWidth: 1)
                        )
                    
                    VStack(spacing: 8) {
                        // Channel Logo
                        AsyncImage(url: URL(string: channel.logoURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 40)
                            case .failure(_):
                                VStack(spacing: 4) {
                                    Image(systemName: "tv")
                                        .font(.system(size: 24))
                                        .foregroundColor(channel.category.color)
                                    
                                    Text(channel.name.prefix(2).uppercased())
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(channel.category.color)
                                }
                            case .empty:
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: channel.category.color))
                            @unknown default:
                                EmptyView()
                            }
                        }
                        
                        // Live Badge
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.white)
                                .frame(width: 4, height: 4)
                                .scaleEffect(1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                            
                            Text("LIVE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.red)
                        )
                    }
                }
                
                // Channel Info
                VStack(spacing: 4) {
                    Text(channel.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text(channel.category.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(channel.category.color)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 8))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text("\(channel.viewerCount.formatted())")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text(channel.quality)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.surface)
                    .shadow(
                        color: AppTheme.Colors.textPrimary.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

// MARK: - List Channel Card
struct ListChannelCard: View {
    let channel: LiveTVChannel
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Channel Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(channel.category.color.opacity(0.1))
                        .frame(width: 80, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(channel.category.color.opacity(0.3), lineWidth: 1)
                        )
                    
                    AsyncImage(url: URL(string: channel.logoURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 35)
                        case .failure(_):
                            VStack(spacing: 2) {
                                Image(systemName: "tv")
                                    .font(.system(size: 16))
                                    .foregroundColor(channel.category.color)
                                
                                Text(channel.name.prefix(2).uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(channel.category.color)
                            }
                        case .empty:
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: channel.category.color))
                                .scaleEffect(0.8)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    // Live Badge
                    VStack {
                        HStack {
                            Spacer()
                            
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 3, height: 3)
                                
                                Text("LIVE")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(.red)
                            )
                        }
                        
                        Spacer()
                    }
                    .frame(width: 80, height: 60)
                    .padding(4)
                }
                
                // Channel Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(channel.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(channel.category.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(channel.category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(channel.category.color.opacity(0.1))
                            )
                    }
                    
                    Text(channel.description)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text("\(channel.viewerCount.formatted()) watching")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "tv")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text(channel.quality)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                }
                
                // Action Button
                VStack {
                    Button(action: action) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(AppTheme.Colors.primary)
                            )
                    }
                    
                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.surface)
                    .shadow(
                        color: AppTheme.Colors.textPrimary.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

#Preview {
    LiveTVChannelsView()
        .environmentObject(AppState())
}