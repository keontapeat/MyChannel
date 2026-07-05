import SwiftUI

// MARK: - Premium Live TV Section
struct PremiumLiveTVSection: View {
    let onChannelTap: (LiveTVChannel) -> Void
    
    @State private var selectedCategory: LiveTVChannel.ChannelCategory = .news
    @State private var isShowingAllChannels: Bool = false
    @State private var pulse: Bool = false
    @StateObject private var healthAgent = StreamHealthMLAgent.shared
    @StateObject private var liveTVManager = LiveTVManager.shared
    
    private var channels: [LiveTVChannel] {
        // 🔥 Use LiveTVManager for dynamic channels (24/7 reliability)
        let allChannels = liveTVManager.channels.isEmpty ? LiveTVChannel.sampleChannels : liveTVManager.channels
        
        // Filter to only healthy channels if health check has run
        let healthyIds = healthAgent.healthyChannelIds
        if healthyIds.isEmpty {
            return allChannels
        }
        return allChannels.filter { healthyIds.contains($0.id) || liveTVManager.isChannelHealthy($0.id) }
    }
    
    private var filteredChannels: [LiveTVChannel] {
        channels.filter { $0.category == selectedCategory }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header with Live Indicator
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .scaleEffect(pulse ? 1.15 : 0.9)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                        
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 8)
                            .frame(width: 20, height: 20)
                            .scaleEffect(pulse ? 1.4 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
                    }
                    .onAppear { pulse = true }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("📺 Live TV")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("\(liveTVManager.channels.isEmpty ? LiveTVChannel.sampleChannels.count : liveTVManager.channels.count)+ Free Channels")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Button("See All") {
                    isShowingAllChannels = true
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            
            // Channel Categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LiveTVChannel.ChannelCategory.allCases, id: \.self) { category in
                        LiveTVCategoryChip(
                            category: category,
                            isSelected: selectedCategory == category,
                            channelCount: channels.filter { $0.category == category }.count
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedCategory = category
                            }
                            
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            
            // Live Channel Grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(filteredChannels.prefix(8).enumerated()), id: \.element.id) { index, channel in
                        PremiumChannelCard(channel: channel, showPreview: true) {
                            onChannelTap(channel)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            
            // Trending Now Banner
            TrendingLiveBanner()
                .padding(.horizontal, AppTheme.Spacing.md)
        }
        .padding(.vertical, AppTheme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.Colors.background,
                    AppTheme.Colors.background.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .fullScreenCover(isPresented: $isShowingAllChannels) {
            LiveTVChannelsView()
        }
    }
}

// MARK: - Category Chip
struct LiveTVCategoryChip: View {
    let category: LiveTVChannel.ChannelCategory
    let isSelected: Bool
    let channelCount: Int
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(category.displayName)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("(\(channelCount))")
                        .font(.system(size: 12))
                        .opacity(0.7)
                }
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                
                if isSelected {
                    Rectangle()
                        .fill(.white)
                        .frame(height: 2)
                        .cornerRadius(1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        LinearGradient(
                            colors: [category.color, category.color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        AppTheme.Colors.surface
                    }
                    
                    if isPressed {
                        Color.black.opacity(0.1)
                    }
                }
            )
            .cornerRadius(AppTheme.CornerRadius.md)
            .shadow(
                color: isSelected ? category.color.opacity(0.3) : .clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: 2
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
    }
}

// MARK: - Premium Channel Card
struct PremiumChannelCard: View {
    let channel: LiveTVChannel
    var showPreview: Bool = false
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    @State private var isHovered: Bool = false
    @State private var streamReady: Bool = false
    @State private var streamFailed: Bool = false
    
    var body: some View {
        // 🔥 Always show channel - use static thumbnail as fallback
        Button(action: {
            print("📺 LIVE TV CLICKED: \(channel.name)")
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 12) {
                // Channel Live Video
                ZStack {
                    // Thumbnail - show live stream or fallback to static image
                    if streamFailed {
                        AsyncImage(url: URL(string: channel.logoURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(channel.category.color.opacity(0.3))
                                .overlay(
                                    Image(systemName: "tv.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(channel.category.color)
                                )
                        }
                        .frame(width: 120, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            channel.category.color.opacity(0.3),
                                            channel.category.color.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    } else {
                        LiveChannelThumbnailView(
                            streamURL: channel.streamURL,
                            posterURL: channel.logoURL,
                            fallbackStreamURL: channel.previewFallbackURL,
                            channelCategory: channel.category,
                            channelName: channel.name,
                            channelId: channel.id,
                            onStreamFailed: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamFailed = true
                                }
                            },
                            onStreamReady: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    streamReady = true
                                }
                            },
                            cornerRadius: 16
                        )
                        .frame(width: 120, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            channel.category.color.opacity(0.3),
                                            channel.category.color.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    
                    // Play button overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            Spacer()
                        }
                        Spacer()
                    }
                    .opacity(isPressed ? 1.0 : 0.8)
                    
                    // LIVE Badge
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 4, height: 4)
                                Text("LIVE")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(.red)
                                    .shadow(color: .red.opacity(0.4), radius: 2, x: 0, y: 1)
                            )
                        }
                        Spacer()
                    }
                    .frame(width: 120, height: 80)
                    .padding(6)
                }
                
                // Channel Info
                VStack(spacing: 4) {
                    Text(channel.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                            
                            Text("\(channel.viewerCount.formatted())")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text(channel.quality)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(channel.category.color)
                    }
                }
                .frame(width: 120)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
        .onPressGesture(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("\(channel.name) live channel")
        .accessibilityHint("Double tap to watch live")
    }
}

// MARK: - Trending Live Banner
struct TrendingLiveBanner: View {
    @State private var currentIndex: Int = 0
    @State private var timer: Timer?
    @StateObject private var liveTVManager = LiveTVManager.shared
    
    private var trendingChannels: [LiveTVChannel] {
        let source = liveTVManager.channels.isEmpty ? LiveTVChannel.sampleChannels : liveTVManager.channels
        return Array(source.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🔥 Trending Live")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    ForEach(0..<trendingChannels.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(index == currentIndex ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentIndex)
                    }
                }
            }
            
            if !trendingChannels.isEmpty {
                let channel = trendingChannels[currentIndex]
                
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: channel.logoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.surface)
                    }
                    .frame(width: 40, height: 28)
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(channel.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text(channel.description)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button("Watch") {
                        // Handle watch action
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
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
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            let count = trendingChannels.count
            guard count > 0 else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % count
            }
        }
    }
}

#Preview {
    PremiumLiveTVSection { channel in
        print("Selected channel: \(channel.name)")
    }
    .environmentObject(AppState())
}