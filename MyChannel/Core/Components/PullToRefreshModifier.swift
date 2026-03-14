//
//  PullToRefreshModifier.swift
//  MyChannel
//
//  Enhanced pull-to-refresh with haptic feedback and custom animations
//

import SwiftUI

// MARK: - Pull to Refresh Modifier
struct PullToRefreshModifier: ViewModifier {
    let action: () async -> Void
    let tintColor: Color
    
    @State private var isRefreshing = false
    @State private var pullProgress: CGFloat = 0
    
    init(
        tintColor: Color = AppTheme.Colors.primary,
        action: @escaping () async -> Void
    ) {
        self.tintColor = tintColor
        self.action = action
    }
    
    func body(content: Content) -> some View {
        content
            .refreshable {
                // Haptic feedback on pull
                HapticManager.shared.impact(style: .medium)
                
                isRefreshing = true
                await action()
                isRefreshing = false
                
                // Success haptic on complete
                HapticManager.shared.notification(type: .success)
            }
    }
}

// MARK: - Custom Pull to Refresh (for more control)
struct CustomPullToRefresh<Content: View>: View {
    let content: Content
    let action: () async -> Void
    let threshold: CGFloat
    let tintColor: Color
    
    @State private var isRefreshing = false
    @State private var pullOffset: CGFloat = 0
    @State private var showIndicator = false
    
    init(
        threshold: CGFloat = 80,
        tintColor: Color = AppTheme.Colors.primary,
        @ViewBuilder content: () -> Content,
        action: @escaping () async -> Void
    ) {
        self.threshold = threshold
        self.tintColor = tintColor
        self.content = content()
        self.action = action
    }
    
    private var progress: CGFloat {
        min(pullOffset / threshold, 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Refresh indicator
                if showIndicator || isRefreshing {
                    refreshIndicator
                        .frame(height: 60)
                        .offset(y: isRefreshing ? 0 : -60 + (pullOffset * 0.5))
                        .opacity(isRefreshing ? 1 : Double(progress))
                }
                
                // Content
                ScrollView {
                    content
                        .anchorPreference(key: ScrollOffsetPreferenceKey.self, value: .top) { anchor in
                            geometry[anchor].y
                        }
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    handleScrollOffset(offset)
                }
            }
        }
    }
    
    @ViewBuilder
    private var refreshIndicator: some View {
        HStack(spacing: 12) {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: tintColor))
                    .scaleEffect(1.2)
            } else {
                // Custom animated indicator
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tintColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.3), value: progress)
            }
            
            if isRefreshing {
                Text("Refreshing...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            } else if progress >= 1.0 {
                Text("Release to refresh")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    private func handleScrollOffset(_ offset: CGFloat) {
        pullOffset = max(0, offset)
        
        // Show indicator when pulling
        if pullOffset > 10 && !showIndicator {
            showIndicator = true
            HapticManager.shared.impact(style: .light)
        }
        
        // Trigger refresh when released past threshold
        if pullOffset >= threshold && !isRefreshing {
            triggerRefresh()
        }
        
        // Hide indicator when scrolled back
        if pullOffset <= 0 && !isRefreshing {
            showIndicator = false
        }
    }
    
    private func triggerRefresh() {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            await action()
            
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isRefreshing = false
                    showIndicator = false
                }
                HapticManager.shared.notification(type: .success)
            }
        }
    }
}

// MARK: - Scroll Offset Preference Key
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Extension
extension View {
    /// Adds pull-to-refresh with haptic feedback
    func pullToRefresh(
        tintColor: Color = AppTheme.Colors.primary,
        action: @escaping () async -> Void
    ) -> some View {
        modifier(PullToRefreshModifier(tintColor: tintColor, action: action))
    }
}

// MARK: - Refreshable List View
struct RefreshableListView<Content: View, Item: Identifiable>: View {
    let items: [Item]
    let isLoading: Bool
    let onRefresh: () async -> Void
    let onLoadMore: (() async -> Void)?
    let hasMore: Bool
    let content: (Item) -> Content
    
    @State private var isRefreshing = false
    
    init(
        items: [Item],
        isLoading: Bool = false,
        hasMore: Bool = true,
        onRefresh: @escaping () async -> Void,
        onLoadMore: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.isLoading = isLoading
        self.hasMore = hasMore
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    content(item)
                        .onAppear {
                            // Load more when reaching end
                            if item.id as AnyObject === items.last?.id as AnyObject {
                                loadMoreIfNeeded()
                            }
                        }
                }
                
                // Loading indicator at bottom
                if isLoading && !items.isEmpty {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                        Text("Loading more...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                
                // End of list indicator
                if !hasMore && !items.isEmpty {
                    Text("You've reached the end! 🎉")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
        .refreshable {
            HapticManager.shared.impact(style: .medium)
            await onRefresh()
            HapticManager.shared.notification(type: .success)
        }
    }
    
    private func loadMoreIfNeeded() {
        guard hasMore, !isLoading, let onLoadMore = onLoadMore else { return }
        
        Task {
            await onLoadMore()
        }
    }
}

// MARK: - Preview
#Preview("Pull to Refresh") {
    struct PreviewWrapper: View {
        @State private var items = Array(1...20)
        @State private var isLoading = false
        
        var body: some View {
            RefreshableListView(
                items: items.map { PreviewItem(id: $0, value: $0) },
                isLoading: isLoading,
                hasMore: items.count < 50,
                onRefresh: {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    items = Array(1...20)
                },
                onLoadMore: {
                    isLoading = true
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    let newItems = Array((items.count + 1)...(items.count + 10))
                    items.append(contentsOf: newItems)
                    isLoading = false
                }
            ) { item in
                Text("Item \(item.value)")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }
        }
    }
    
    struct PreviewItem: Identifiable {
        let id: Int
        let value: Int
    }
    
    return PreviewWrapper()
}






