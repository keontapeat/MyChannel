import SwiftUI

struct LiveTVChannelsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var selectedCategory: LiveTVChannel.ChannelCategory? = nil
    @State private var searchText: String = ""
    @State private var viewMode: ViewMode = .grid
    @State private var showingPlayer = false
    @State private var selectedChannel: LiveTVChannel?
    @State private var heroIndex: Int = 0
    @State private var aiTrendingChannels: [LiveTVChannel] = []
    @State private var selectedTopTab: TopTab = .home
    @StateObject private var libraryStore = LiveTVLibraryStore.shared

    enum TopTab: String, CaseIterable {
        case library = "Library"
        case home = "Home"
        case live = "Live"
    }

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
        let managerChannels = LiveTVManager.shared.channels
        return managerChannels.isEmpty ? LiveTVChannel.sampleChannels : managerChannels
    }

    private var savedChannels: [LiveTVChannel] {
        allChannels.filter { libraryStore.savedChannelIds.contains($0.id) }
    }

    private var heroChannels: [LiveTVChannel] {
        let picks = [
            allChannels.first(where: { $0.id == "bob-ross" }),
            allChannels.first(where: { $0.id == "nba-tv" }),
            allChannels.first(where: { $0.id == "cbs-news" }),
            allChannels.first(where: { $0.id == "dragon-ball-z" }),
            allChannels.first(where: { $0.id == "nasa-tv" }),
            allChannels.first(where: { $0.id == "forensic-files" }),
        ].compactMap { $0 }
        return picks.isEmpty ? Array(allChannels.prefix(6)) : picks
    }

    private var filteredChannels: [LiveTVChannel] {
        var channels = allChannels
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
        // AI trending channels bubble to top
        let trendingIds = Set(aiTrendingChannels.prefix(10).map { $0.id })
        return channels.sorted {
            let aIsTrending = trendingIds.contains($0.id)
            let bIsTrending = trendingIds.contains($1.id)
            if aIsTrending != bIsTrending { return aIsTrending }
            return $0.viewerCount > $1.viewerCount
        }
    }

    private func channelCount(for category: LiveTVChannel.ChannelCategory) -> Int {
        allChannels.filter { $0.category == category }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                topTabs
                searchBar
                if selectedTopTab != .library {
                    categoryChips
                }

                ScrollView {
                    VStack(spacing: 0) {
                        if selectedTopTab == .library {
                            libraryContent
                        } else if selectedTopTab == .live {
                            liveGuideContent
                        } else if searchText.isEmpty && selectedCategory == nil {
                            heroBanner
                                .padding(.top, 16)

                            if !aiTrendingChannels.isEmpty {
                                trendingRow
                            }

                            channelGridOrList
                        } else {
                            channelGridOrList
                        }
                        Color.clear.frame(height: 32)
                    }
                }
            }
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            // AI trending sort - background only, never blocks UI
            let trending = await LiveTVIntelligenceAgent.shared.getTrendingChannels(limit: 15)
            let aiChannels = trending.map { $0.channel }
            // Fallback: if AI returns nothing, use top channels by viewer count
            aiTrendingChannels = aiChannels.isEmpty
                ? Array(allChannels.sorted { $0.viewerCount > $1.viewerCount }.prefix(15))
                : aiChannels
            await LiveTVManager.shared.initialize()
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let channel = selectedChannel {
                LiveTVPlayerView(channel: channel)
                    .environmentObject(appState)
                    .background(Color.black)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
    }

    // MARK: - Hero Banner
    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                        .scaleEffect(1.0).animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: true)
                    Text("FEATURED")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Color.red)
                        .kerning(1.5)
                }
                Spacer()
                Text("\(heroIndex + 1)/\(heroChannels.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 16)

            TabView(selection: $heroIndex) {
                ForEach(heroChannels.indices, id: \.self) { i in
                    HeroBannerCard(channel: heroChannels[i]) {
                        playChannel(heroChannels[i])
                    }
                    .tag(i)
                    .padding(.horizontal, 16)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200)
            .onAppear {
                startHeroTimer()
            }

            // Page dots
            HStack(spacing: 6) {
                ForEach(heroChannels.indices, id: \.self) { i in
                    Circle()
                        .fill(i == heroIndex ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: i == heroIndex ? 8 : 5, height: i == heroIndex ? 8 : 5)
                        .animation(.spring(response: 0.3), value: heroIndex)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Trending Row
    private var trendingRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🔥 Trending Now")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(aiTrendingChannels.prefix(12)) { channel in
                        TrendingChip(channel: channel) {
                            playChannel(channel)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Start hero auto-scroll
    private func startHeroTimer() {
        guard heroChannels.count > 1 else { return }
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                heroIndex = (heroIndex + 1) % heroChannels.count
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

    private var topTabs: some View {
        HStack(spacing: 0) {
            ForEach(TopTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedTopTab = tab
                        selectedCategory = nil
                        searchText = ""
                    }
                    HapticManager.shared.impact(style: .light)
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: selectedTopTab == tab ? .bold : .semibold))
                            .foregroundColor(selectedTopTab == tab ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                        Capsule()
                            .fill(selectedTopTab == tab ? AppTheme.Colors.textPrimary : Color.clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var channelGridOrList: some View {
        Group {
            if viewMode == .grid {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(filteredChannels) { channel in
                        TVGridCard(
                            channel: channel,
                            isTrending: aiTrendingChannels.prefix(10).contains(where: { $0.id == channel.id })
                        ) {
                            playChannel(channel)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredChannels) { channel in
                        TVListCard(
                            channel: channel
                        ) {
                            playChannel(channel)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }

    private var libraryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            libraryHeader
            if savedChannels.isEmpty {
                emptyLibraryView
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(savedChannels) { channel in
                        TVListCard(
                            channel: channel
                        ) {
                            playChannel(channel)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Live TV Library")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("Save channels and add them to your DVR-style lineup.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyLibraryView: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 42, weight: .light))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text("No saved channels yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("Tap the bookmark on any channel to build your library.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var liveGuideContent: some View {
        LazyVStack(spacing: 10, pinnedViews: []) {
            ForEach(filteredChannels) { channel in
                LiveTVGuideRow(
                    channel: channel,
                    isSaved: libraryStore.isSaved(channel),
                    isDVRAdded: libraryStore.isDVRAdded(channel),
                    onPlay: { playChannel(channel) },
                    onSave: { libraryStore.toggleSaved(channel) },
                    onDVR: { libraryStore.toggleDVR(channel) }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
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

// MARK: - Hero Banner Card (YouTube TV / Hulu style featured panel)
private struct HeroBannerCard: View {
    let channel: LiveTVChannel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: channel.logoURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Rectangle().fill(channelGradient)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 6) {
                    // LIVE badge
                    HStack(spacing: 5) {
                        Circle().fill(.white).frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .kerning(1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.red))

                    Text(channel.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(channel.category.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))

                        Text("•")
                            .foregroundColor(.white.opacity(0.5))

                        Image(systemName: "eye.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(formatCount(channel.viewerCount)) watching")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(16)

                // Play button - top right
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.black)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(height: 200)
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
    }

    private var categoryColor: Color { LiveTVChannelsView_categoryColor(channel.category) }

    private var channelGradient: LinearGradient {
        LinearGradient(colors: [categoryColor.opacity(0.8), categoryColor.opacity(0.4)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Trending Chip (horizontal scroll row)
private struct TrendingChip: View {
    let channel: LiveTVChannel
    let action: () -> Void

    private var categoryColor: Color { LiveTVChannelsView_categoryColor(channel.category) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: channel.logoURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Rectangle().fill(categoryColor.opacity(0.4))
                        }
                    }
                    .frame(width: 120, height: 68)
                    .clipped()

                    HStack(spacing: 3) {
                        Circle().fill(.white).frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Capsule().fill(Color.red))
                    .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(channel.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.95))
    }
}

// MARK: - TV Grid Card (always visible - YouTube TV style)
private struct TVGridCard: View {
    let channel: LiveTVChannel
    let isTrending: Bool
    let action: () -> Void

    private var categoryColor: Color { LiveTVChannelsView_categoryColor(channel.category) }
    private var categoryIcon: String { LiveTVChannelsView_categoryIcon(channel.category) }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topLeading) {
                    // Channel poster - always visible immediately
                    AsyncImage(url: URL(string: channel.logoURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .failure:
                            ZStack {
                                Rectangle().fill(channelGradient)
                                Image(systemName: categoryIcon)
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        case .empty:
                            ZStack {
                                Rectangle().fill(channelGradient)
                                ProgressView().tint(.white.opacity(0.6))
                            }
                        @unknown default:
                            Rectangle().fill(channelGradient)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipped()

                    // Gradient overlay for readability
                    LinearGradient(
                        colors: [.black.opacity(0.35), .clear],
                        startPoint: .top, endPoint: .center
                    )

                    // LIVE badge top-left
                    HStack(spacing: 4) {
                        Circle().fill(.white).frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Capsule().fill(Color.red))
                    .padding(8)

                    // Trending fire badge
                    if isTrending {
                        Text("🔥")
                            .font(.system(size: 14))
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }

                    // Play button center
                    Circle()
                        .fill(.black.opacity(0.45))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    // Quality bottom-right
                    Text(channel.quality)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                        .padding(7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Text(channel.category.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(categoryColor)
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("\(formatCount(channel.viewerCount)) watching")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
    }

    private var channelGradient: LinearGradient {
        LinearGradient(colors: [categoryColor.opacity(0.7), categoryColor.opacity(0.3)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - TV List Card (always visible - YouTube TV list style)
private struct TVListCard: View {
    let channel: LiveTVChannel
    let action: () -> Void

    private var categoryColor: Color { LiveTVChannelsView_categoryColor(channel.category) }
    private var categoryIcon: String { LiveTVChannelsView_categoryIcon(channel.category) }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    AsyncImage(url: URL(string: channel.logoURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        case .failure:
                            ZStack {
                                Rectangle().fill(channelGradient)
                                Image(systemName: categoryIcon)
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        default:
                            Rectangle().fill(channelGradient)
                        }
                    }
                    .frame(width: 152, height: 86)
                    .clipped()

                    HStack(spacing: 3) {
                        Circle().fill(.white).frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Capsule().fill(Color.red))
                    .padding(7)

                    Circle()
                        .fill(.black.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "play.fill").font(.system(size: 12)).foregroundColor(.white))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(channel.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(channel.description)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(channel.category.displayName)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(categoryColor.opacity(0.12)))

                        Image(systemName: "eye.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("\(formatCount(channel.viewerCount))")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.Colors.surface))
        }
        .buttonStyle(PressableScaleStyle(scale: 0.98))
    }

    private var channelGradient: LinearGradient {
        LinearGradient(colors: [categoryColor.opacity(0.7), categoryColor.opacity(0.3)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Shared helpers

// MARK: - Live TV Guide Row (lightweight placeholder)
private struct LiveTVGuideRow: View {
    let channel: LiveTVChannel
    let isSaved: Bool
    let isDVRAdded: Bool
    let onPlay: () -> Void
    let onSave: () -> Void
    let onDVR: () -> Void

    var body: some View {
        TVListCard(channel: channel) {
            onPlay()
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 12) {
                Button(action: onSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isSaved ? .yellow : AppTheme.Colors.textSecondary)
                }
                Button(action: onDVR) {
                    Image(systemName: isDVRAdded ? "record.circle.fill" : "record.circle")
                        .foregroundColor(isDVRAdded ? .red : AppTheme.Colors.textSecondary)
                }
            }
            .padding(10)
        }
    }
}
private func LiveTVChannelsView_categoryColor(_ category: LiveTVChannel.ChannelCategory) -> Color {
    switch category {
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
    case .anime: return .indigo
    case .scifi: return Color(red: 0.2, green: 0.5, blue: 0.9)
    case .comedy: return .orange
    case .reality: return .pink
    case .classic: return .brown
    }
}

private func LiveTVChannelsView_categoryIcon(_ category: LiveTVChannel.ChannelCategory) -> String {
    switch category {
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
    case .anime: return "sparkles.tv.fill"
    case .scifi: return "moon.stars.fill"
    case .comedy: return "face.smiling.fill"
    case .reality: return "video.fill"
    case .classic: return "clock.fill"
    }
}

private func formatCount(_ count: Int) -> String {
    if count >= 1_000_000 {
        return String(format: "%.1fM", Double(count) / 1_000_000.0)
    } else if count >= 1_000 {
        return String(format: "%.1fK", Double(count) / 1_000.0)
    }
    return "\(count)"
}

#Preview("Live TV - All Channels") {
    LiveTVChannelsView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}
