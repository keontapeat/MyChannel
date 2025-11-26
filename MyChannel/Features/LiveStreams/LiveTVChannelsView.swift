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
        
        // Set selected channel and show fullscreen player
        selectedChannel = channel
        showingPlayer = true
    }
}

// MARK: - Minimal Grid Card (matches Home style)
private struct MinimalGridChannelCard: View {
    let channel: LiveTVChannel
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    // Professional thumbnail with logo
                    channelThumbnail
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Play button overlay
                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                    // LIVE badge
                    if channel.isLive {
                        HStack(spacing: 4) {
                            Circle().fill(.white).frame(width: 5, height: 5)
                            Text("LIVE").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Capsule().fill(Color.red))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    
                    // Quality badge
                    Text(channel.quality)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.75)))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("\(formatViewerCount(channel.viewerCount)) viewers")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }
    
    // Professional channel thumbnail
    private var channelThumbnail: some View {
        ZStack {
            // Gradient background based on category
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            categoryBackgroundColor.opacity(0.15),
                            categoryBackgroundColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Subtle pattern overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface.opacity(0.5))
            
            // Channel logo or icon
            VStack(spacing: 6) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(categoryBackgroundColor.opacity(0.8))
                
                Text(channel.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
            }
        }
    }
    
    private var categoryBackgroundColor: Color {
        switch channel.category {
        case .news: return .red
        case .sports: return .green
        case .entertainment: return .purple
        case .movies: return .blue
        case .music: return .orange
        case .kids: return .yellow
        case .documentary: return .teal
        case .lifestyle: return .mint
        case .business: return .gray
        case .international: return .cyan
        }
    }
    
    private var categoryIcon: String {
        switch channel.category {
        case .news: return "newspaper.fill"
        case .sports: return "sportscourt.fill"
        case .entertainment: return "tv.fill"
        case .movies: return "film.fill"
        case .music: return "music.note.tv.fill"
        case .kids: return "figure.2.and.child.holdinghands"
        case .documentary: return "globe.americas.fill"
        case .lifestyle: return "house.fill"
        case .business: return "chart.line.uptrend.xyaxis"
        case .international: return "globe"
        }
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

    private let thumbSize = CGSize(width: 160, height: 90)
    private let rowHeight: CGFloat = 114

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack {
                    // Professional thumbnail
                    channelThumbnail
                    
                    // Play button
                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

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
                        .background(Capsule().fill(Color.red))
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .frame(width: thumbSize.width, height: thumbSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Text area
                VStack(alignment: .leading, spacing: 4) {
                    Text(channel.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(channel.description)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        // Category badge
                        Text(channel.category.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(categoryColor.opacity(0.12))
                            )
                        
                        Image(systemName: "eye.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("\(formatViewerCount(channel.viewerCount)) • \(channel.quality)")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textSecondary)
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
        .buttonStyle(PressableScaleStyle(scale: 0.98))
    }
    
    // Professional channel thumbnail
    private var channelThumbnail: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            categoryColor.opacity(0.15),
                            categoryColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Surface overlay
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface.opacity(0.5))
            
            // Category icon
            VStack(spacing: 4) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(categoryColor.opacity(0.8))
                
                Text(String(channel.name.prefix(8)))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
        }
    }
    
    private var categoryColor: Color {
        switch channel.category {
        case .news: return .red
        case .sports: return .green
        case .entertainment: return .purple
        case .movies: return .blue
        case .music: return .orange
        case .kids: return .yellow
        case .documentary: return .teal
        case .lifestyle: return .mint
        case .business: return .gray
        case .international: return .cyan
        }
    }
    
    private var categoryIcon: String {
        switch channel.category {
        case .news: return "newspaper.fill"
        case .sports: return "sportscourt.fill"
        case .entertainment: return "tv.fill"
        case .movies: return "film.fill"
        case .music: return "music.note.tv.fill"
        case .kids: return "figure.2.and.child.holdinghands"
        case .documentary: return "globe.americas.fill"
        case .lifestyle: return "house.fill"
        case .business: return "chart.line.uptrend.xyaxis"
        case .international: return "globe"
        }
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
