//
//  SubscriptionsView.swift
//  MyChannel
//
//  Nuclear-level subscriptions feed (better than YouTube)
//

import SwiftUI

struct SubscriptionsView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var viewModel = SubscriptionsViewModel()
    @State private var showFilterSheet = false
    @State private var showSortSheet = false
    
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
                // Tab Navigation
                tabNavigation
                
                // Content
                Group {
                    if viewModel.isLoading && viewModel.videos.isEmpty {
                        loadingView
                    } else if viewModel.videos.isEmpty && viewModel.selectedTab == .feed {
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
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarButtons
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                filterSheet
            }
            .sheet(isPresented: $showSortSheet) {
                sortSheet
            }
            .task {
                if let userId = authManager.currentUser?.id {
                    await viewModel.loadSubscribedVideos(userId: userId)
                    await viewModel.loadSubscribedChannels(userId: userId)
                }
            }
            .refreshable {
                if let userId = authManager.currentUser?.id {
                    await viewModel.refreshFeed(userId: userId)
                }
            }
        }
    }
    
    // MARK: - Tab Navigation
    private var tabNavigation: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SubscriptionsViewModel.SubscriptionTab.allCases, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(AppTheme.Colors.background)
    }
    
    // 🔥 PREMIUM: Tab button with haptic and scale animation
    private func tabButton(for tab: SubscriptionsViewModel.SubscriptionTab) -> some View {
        Button(action: {
            // 🔥 PREMIUM: Haptic on tab change
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
            // 🔥 PREMIUM: Scale animation for selected state
            .scaleEffect(viewModel.selectedTab == tab ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: viewModel.selectedTab)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 🔥 PREMIUM: Toolbar with haptics
    private var toolbarButtons: some View {
        HStack(spacing: 16) {
            // Filter button
            Button(action: {
                HapticManager.shared.impact(style: .light)
                showFilterSheet = true
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            // Sort button
            Button(action: {
                HapticManager.shared.impact(style: .light)
                showSortSheet = true
            }) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
        }
    }
    
    // MARK: - 🔥 PREMIUM: Feed Tab with staggered animations
    private var feedTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(viewModel.filteredVideos.enumerated()), id: \.element.id) { index, video in
                    SubscriptionVideoCard(video: video)
                        .onTapGesture {
                            // 🔥 PREMIUM: Haptic on video tap
                            HapticManager.shared.impact(style: .light)
                            NotificationCenter.default.post(
                                name: NSNotification.Name("NavigateToVideo"),
                                object: video.id
                            )
                        }
                        // 🔥 PREMIUM: Staggered appear animation
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Channels Tab
    private var channelsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.subscribedChannels) { channel in
                    SubscribedChannelCard(
                        channel: channel,
                        notificationLevel: viewModel.notificationSettings[channel.id] ?? .all,
                        onUnsubscribe: {
                            if let userId = authManager.currentUser?.id {
                                Task {
                                    await viewModel.unsubscribe(from: channel.id, userId: userId)
                                }
                            }
                        },
                        onNotificationChange: { level in
                            Task {
                                await viewModel.updateNotificationLevel(channelId: channel.id, level: level)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.square.stack")
                .font(.system(size: 60, weight: .thin))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("No Subscriptions Yet")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Subscribe to your favorite creators to see their latest videos here.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
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
    
    // MARK: - Filter Sheet
    private var filterSheet: some View {
        NavigationStack {
            List {
                ForEach(SubscriptionsViewModel.FilterOption.allCases, id: \.self) { option in
                    Button(action: {
                        viewModel.filterOption = option
                        showFilterSheet = false
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(viewModel.filterOption == option ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                .frame(width: 24)
                            
                            Text(option.rawValue)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Spacer()
                            
                            if viewModel.filterOption == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFilterSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
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
                    Button("Done") {
                        showSortSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(AppState())
}
