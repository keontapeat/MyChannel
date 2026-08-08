//
//  SubscriptionsView.swift
//  MyChannel
//
//  Nuclear-level subscriptions feed — 100% YouTube parity 🔥
//

import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SubscriptionsViewModel()
    @State private var showSortSheet = false
    
    // Direct navigation (replaces broken NotificationCenter hops)
    @State private var videoToOpen: Video?
    @State private var channelToOpen: User?
    @State private var moreOptionsVideo: Video?
    @State private var showManageSheet = false
    
    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                UnauthenticatedPromptView(promptType: .subscriptions) {
                    NotificationCenter.default.post(name: .presentSignInSheet, object: nil)
                }
            } else {
                subscriptionsContent
            }
        }
    }
    
    private var subscriptionsContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header (title + tools)
                header
                
                // Tab Navigation
                tabNavigation
                
                // Content
                Group {
                    if viewModel.isLoading && viewModel.videos.isEmpty {
                        loadingView
                    } else if viewModel.subscribedChannels.isEmpty && viewModel.videos.isEmpty {
                        emptyStateView
                    } else {
                        switch viewModel.selectedTab {
                        case .feed:
                            feedTab
                        case .channels:
                            channelsTab
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSortSheet) { sortSheet }
            .sheet(isPresented: $showManageSheet) { manageSubscriptionsSheet }
            .sheet(item: $moreOptionsVideo) { video in
                VideoMoreOptionsSheet(
                    video: video,
                    isSubscribed: .constant(true),
                    isWatchLater: .constant(appState.isVideoInWatchLater(video.id))
                )
                .environmentObject(authManager)
                .environmentObject(appState)
            }
            .fullScreenCover(item: $videoToOpen) { video in
                VideoDetailView(video: video)
                    .environmentObject(appState)
            }
            .fullScreenCover(item: $channelToOpen) { channel in
                NavigationStack {
                    PublicProfileView(user: channel)
                        .environmentObject(authManager)
                        .environmentObject(appState)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { channelToOpen = nil } label: {
                                    Image(systemName: "xmark")
                                }
                            }
                        }
                }
            }
            .task {
                if let userId = authManager.currentUser?.id {
                    await viewModel.loadSubscribedChannels(userId: userId)
                    await viewModel.loadSubscribedVideos(userId: userId)
                    await viewModel.loadPosts(userId: userId)
                }
            }
            .refreshable {
                if let userId = authManager.currentUser?.id {
                    await viewModel.refreshFeed(userId: userId)
                }
            }
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack(spacing: 14) {
            Text("Subscriptions")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            // Layout toggle (grid ⇄ list)
            Button {
                HapticManager.shared.impact(style: .light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.toggleLayout()
                }
            } label: {
                Image(systemName: viewModel.layout.toggleIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            // Sort
            Button {
                HapticManager.shared.impact(style: .light)
                showSortSheet = true
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            // Manage subscriptions
            Button {
                HapticManager.shared.impact(style: .light)
                showManageSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Tab Navigation
    private var tabNavigation: some View {
        HStack(spacing: 12) {
            ForEach(SubscriptionsViewModel.SubscriptionTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
            
            Spacer()
            
            // New uploads pill
            if viewModel.selectedTab == .feed && viewModel.newUploadCount > 0 {
                Button {
                    HapticManager.shared.impact(style: .light)
                    viewModel.markFeedAsSeen()
                } label: {
                    HStack(spacing: 5) {
                        Circle().fill(AppTheme.Colors.primary).frame(width: 6, height: 6)
                        Text("\(viewModel.newUploadCount) new")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppTheme.Colors.primary.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.Colors.background)
    }
    
    private func tabButton(for tab: SubscriptionsViewModel.SubscriptionTab) -> some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedTab = tab
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(tab.rawValue)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(viewModel.selectedTab == tab ? .white : AppTheme.Colors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(viewModel.selectedTab == tab ? AppTheme.Colors.primary : AppTheme.Colors.surface)
            )
            .scaleEffect(viewModel.selectedTab == tab ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.selectedTab)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Channel avatars row (YouTube parity: avatars + notification dots, "All" right-aligned)
    private var channelAvatarsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(viewModel.subscribedChannels) { channel in
                    channelAvatar(channel)
                }
                
                // "All" as right-side text link (YouTube parity)
                Button {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        viewModel.focusedChannelId = nil
                    }
                } label: {
                    Text("All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private func channelAvatar(_ channel: User) -> some View {
        let isFocused = viewModel.focusedChannelId == channel.id
        let notifLevel = viewModel.notificationSettings[channel.id] ?? .all
        let hasNotif = notifLevel != .none
        
        return Button {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                viewModel.focus(on: channel.id)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: URL(string: channel.profileImageURL ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            )
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isFocused ? AppTheme.Colors.primary : Color.clear, lineWidth: 2.5)
                            .padding(-3)
                    )
                    
                    // YouTube-style notification dot (blue dot bottom-right)
                    if hasNotif {
                        Circle()
                            .fill(Color(hexString: "3EA6FF"))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(AppTheme.Colors.background, lineWidth: 1.5))
                            .offset(x: 2, y: 2)
                    }
                }
                
                Text(channel.displayName)
                    .font(.system(size: 11, weight: isFocused ? .semibold : .regular))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(width: 52)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Filter Chips (YouTube parity — no icons, text only)
    private var subsFilterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // YouTube chip order: All, Today, Videos, Shorts, Live, Posts/Podcasts, Continue watching, Unwatched
                let chipOrder: [SubscriptionsViewModel.FilterOption] = [
                    .all, .today, .videos, .flicks, .live, .posts, .continueWatching, .unwatched
                ]
                ForEach(chipOrder, id: \.self) { option in
                    if option != .posts || viewModel.hasPosts {
                        Button {
                            HapticManager.shared.impact(style: .light)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                viewModel.filterOption = option
                            }
                        } label: {
                            Text(option.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(viewModel.filterOption == option ? AppTheme.Colors.background : AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(viewModel.filterOption == option
                                              ? AppTheme.Colors.textPrimary
                                              : AppTheme.Colors.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Feed Tab
    private var feedTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                // Channel avatars focus row
                if !viewModel.subscribedChannels.isEmpty {
                    channelAvatarsRow
                    Divider().background(AppTheme.Colors.divider)
                }
                
                // Filter chips
                subsFilterChipsBar
                    .padding(.top, 8)
                
                // POSTS filter → show only posts
                if viewModel.filterOption == .posts {
                    postsSection
                } else {
                    // Live videos — full-width cards at the top of feed (YouTube parity)
                    if viewModel.filterOption == .all || viewModel.filterOption == .live,
                       !viewModel.liveNow.isEmpty {
                        liveVideoCards
                    }
                    
                    // Shorts shelf (compact horizontal rail, shown for All + Flicks filter)
                    if viewModel.filterOption == .all || viewModel.filterOption == .flicks,
                       !viewModel.filteredShorts.isEmpty {
                        SubscriptionShortsShelf(shorts: Array(viewModel.filteredShorts.prefix(12))) { short in
                            videoToOpen = short
                        }
                        Divider()
                            .background(AppTheme.Colors.divider)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }
                    
                    // Main video feed (live streams are already shown as full-width
                    // cards above, so skip the "Most relevant" list for the Live filter)
                    if viewModel.filterOption != .live {
                        videoFeed
                    } else if viewModel.liveNow.isEmpty {
                        inlineEmptyFilterState
                    }
                    
                    // "Community posts you may like" carousel — inline after videos (YouTube parity)
                    if viewModel.filterOption == .all, !viewModel.posts.isEmpty {
                        communityPostsCarousel
                    }
                }
            }
            .padding(.bottom, 96)
            .iPadReadableWidth()
        }
    }
    
    @ViewBuilder
    private var videoFeed: some View {
        let videos = viewModel.filteredVideos
        if videos.isEmpty {
            inlineEmptyFilterState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // "Most relevant" section label — YouTube parity
                Text("Most relevant")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                switch viewModel.layout {
                case .grid:
                    // YouTube-style 2-column grid
                    let columns = [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ]
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(videos) { video in
                            SubscriptionGridVideoCard(
                                video: video,
                                progress: viewModel.progress(for: video.id),
                                isNew: viewModel.isNewUpload(video),
                                onMore: { moreOptionsVideo = video }
                            )
                            .onTapGesture {
                                HapticManager.shared.impact(style: .light)
                                videoToOpen = video
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                case .list:
                    LazyVStack(spacing: 4) {
                        ForEach(videos) { video in
                            SubscriptionVideoListRow(
                                video: video,
                                progress: viewModel.progress(for: video.id),
                                isNew: viewModel.isNewUpload(video),
                                onMore: { moreOptionsVideo = video }
                            )
                            .onTapGesture {
                                HapticManager.shared.impact(style: .light)
                                videoToOpen = video
                            }
                            Divider().background(AppTheme.Colors.divider)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Live Video Cards (full-width, YouTube parity)
    // YouTube shows live streams as full-width cards inline at the top of the feed,
    // not a horizontal shelf. Each card: 16:9 thumbnail with LIVE badge, channel avatar,
    // title, channel name · views · time, ⋮ menu.
    private var liveVideoCards: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.liveNow) { live in
                liveFullWidthCard(live)
                    .onTapGesture {
                        HapticManager.shared.impact(style: .light)
                        videoToOpen = live
                    }
                Divider().background(AppTheme.Colors.divider)
            }
        }
        .padding(.top, 8)
    }
    
    private func liveFullWidthCard(_ live: Video) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width 16:9 thumbnail with LIVE badge.
            // Container must use .fit — .fill inside ScrollView expands unboundedly.
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: URL(string: live.thumbnailURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.surface)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                
                // LIVE badge top-left
                HStack(spacing: 4) {
                    Circle().fill(Color.white).frame(width: 5, height: 5)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.red))
                .padding(8)
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()
            
            // Info row
            HStack(alignment: .top, spacing: 10) {
                // Channel avatar
                CachedAsyncImage(url: URL(string: live.creator.profileImageURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(AppTheme.Colors.surface)
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(live.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        Text(live.creator.displayName)
                        if live.creator.shouldShowVerificationBadge {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                        }
                        Text("·")
                        Text("\(live.formattedViewCount) watching")
                        Text("·")
                        Text(live.timeAgo)
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .light)
                    moreOptionsVideo = live
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Community Posts Carousel (YouTube "Community posts you may like" parity)
    // Appears inline in the feed after the main video list. Horizontal swipe carousel.
    private var communityPostsCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community posts you may like")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(viewModel.posts.prefix(6)) { item in
                        communityPostCard(item)
                            .frame(width: UIScreen.main.bounds.width - 64)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 12)
    }
    
    private func communityPostCard(_ item: SubscriptionPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: avatar + name + handle + time + ⋮
            HStack(alignment: .center, spacing: 10) {
                Button {
                    HapticManager.shared.impact(style: .light)
                    channelToOpen = item.author
                } label: {
                    CachedAsyncImage(url: URL(string: item.author.profileImageURL ?? "")) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle().fill(AppTheme.Colors.surface)
                            .overlay(Image(systemName: "person.fill")
                                .foregroundColor(AppTheme.Colors.textTertiary))
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.author.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text("@\(item.author.username)")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("·")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        Text(item.post.createdAt.timeAgoDisplay)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            
            // Post text content
            if !item.post.content.isEmpty {
                Text(item.post.content)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Image attachment
            if let imageURL = item.post.imageURLs.first, !imageURL.isEmpty {
                CachedAsyncImage(url: URL(string: imageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.surface).overlay(ProgressView())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Engagement row — thumbs up/down + comment count (YouTube style)
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.thumbsup")
                        .font(.system(size: 15, weight: .medium))
                    Text(formatPostCount(item.post.likeCount))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
                
                Image(systemName: "hand.thumbsdown")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 15, weight: .medium))
                    Text(formatPostCount(item.post.commentCount))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatPostCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
    
    // MARK: - Posts Section
    @ViewBuilder
    private var postsSection: some View {
        if viewModel.isLoadingPosts && viewModel.posts.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if viewModel.posts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                Text("No posts yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("Community posts from your channels show up here.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
            .padding(.horizontal, 40)
        } else {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.posts) { item in
                    SubscriptionPostCard(item: item) { author in
                        channelToOpen = author
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
    
    // MARK: - Channels Tab
    private var channelsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Summary header
                HStack {
                    Text("\(viewModel.subscribedChannels.count) subscriptions")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Spacer()
                    Button {
                        HapticManager.shared.impact(style: .light)
                        showManageSheet = true
                    } label: {
                        Text("Manage all")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
                
                ForEach(viewModel.subscribedChannels) { channel in
                    SubscribedChannelCard(
                        channel: channel,
                        notificationLevel: viewModel.notificationSettings[channel.id] ?? .all,
                        onUnsubscribe: {
                            if let userId = authManager.currentUser?.id {
                                Task { await viewModel.unsubscribe(from: channel.id, userId: userId) }
                            }
                        },
                        onNotificationChange: { level in
                            Task { await viewModel.updateNotificationLevel(channelId: channel.id, level: level) }
                        },
                        onOpen: { channelToOpen = channel }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 96)
            .iPadReadableWidth()
        }
    }
    
    // MARK: - Inline empty state for active filter
    private var inlineEmptyFilterState: some View {
        VStack(spacing: 10) {
            Image(systemName: viewModel.filterOption.icon)
                .font(.system(size: 36))
                .foregroundColor(AppTheme.Colors.textTertiary)
            Text(emptyFilterTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text(emptyFilterSubtitle)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
        .padding(.horizontal, 40)
    }
    
    private var emptyFilterTitle: String {
        switch viewModel.filterOption {
        case .continueWatching: return "Nothing to continue"
        case .unwatched: return "All caught up"
        case .today: return "Nothing new today"
        case .live: return "No one's live"
        case .flicks: return "No Flicks yet"
        case .videos: return "No videos yet"
        default: return "Nothing here yet"
        }
    }
    
    private var emptyFilterSubtitle: String {
        switch viewModel.filterOption {
        case .continueWatching: return "Videos you've started watching will appear here."
        case .unwatched: return "You've watched everything from your subscriptions. Nice."
        case .today: return "Check back later for fresh uploads."
        case .live: return "When your channels go live, you'll see them here."
        case .flicks: return "Flicks from your subscriptions will show up here."
        case .videos: return "New videos from your subscriptions will appear here."
        default: return "Try a different filter or pull to refresh."
        }
    }
    
    // MARK: - Empty State (no subscriptions)
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 56, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            VStack(spacing: 8) {
                Text("No Subscriptions Yet")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Subscribe to channels you love to build your own ad‑free home feed.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                HapticManager.shared.impact(style: .medium)
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
            } label: {
                Text("Discover creators")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(AppTheme.Colors.primary))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading subscriptions...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
    }
    
    // MARK: - Sort Sheet
    private var sortSheet: some View {
        NavigationStack {
            List {
                ForEach(SubscriptionsViewModel.SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        viewModel.sortOption = option
                        showSortSheet = false
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(viewModel.sortOption == option ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                .frame(width: 24)
                            Text(option.rawValue)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            Spacer()
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showSortSheet = false }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
    
    // MARK: - Manage Subscriptions Sheet (YouTube parity)
    private var manageSubscriptionsSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.subscribedChannels) { channel in
                        HStack(spacing: 12) {
                            CachedAsyncImage(url: URL(string: channel.profileImageURL ?? "")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(AppTheme.Colors.surface)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(channel.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                Text("@\(channel.username)")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // Notification level menu
                            Menu {
                                ForEach(SubscriptionsViewModel.NotificationLevel.allCases, id: \.self) { level in
                                    Button {
                                        Task { await viewModel.updateNotificationLevel(channelId: channel.id, level: level) }
                                    } label: {
                                        Label(level.rawValue, systemImage: level.icon)
                                    }
                                }
                            } label: {
                                Image(systemName: (viewModel.notificationSettings[channel.id] ?? .all).icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Button {
                                if let userId = authManager.currentUser?.id {
                                    Task { await viewModel.unsubscribe(from: channel.id, userId: userId) }
                                }
                            } label: {
                                Text("Unsub")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("\(viewModel.subscribedChannels.count) subscriptions")
                }
            }
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showManageSheet = false }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
}
