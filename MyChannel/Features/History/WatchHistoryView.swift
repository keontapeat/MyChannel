//
//  WatchHistoryView.swift
//  MyChannel
//
//  Enhanced with YouTube parity features
//

import SwiftUI

struct WatchHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var selection = Set<String>()
    @State private var query: String = ""
    @State private var isLoading = false

    private var historyItems: [WatchHistoryItem] {
        appState.watchHistory
    }

    private var filtered: [WatchHistoryItem] {
        guard !query.isEmpty else { return historyItems }
        return historyItems.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.creatorName.localizedCaseInsensitiveContains(query)
        }
    }
    
    private var groupedHistory: [(String, [WatchHistoryItem])] {
        let sections = Dictionary(grouping: filtered) { $0.watchedAt.historySection }
        let order = ["Today", "Yesterday", "This Week", "This Month", "Older"]
        return order.compactMap { section in
            guard let items = sections[section], !items.isEmpty else { return nil }
            return (section, items)
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 30, height: 30)
                                .background(AppTheme.Colors.surface, in: Circle())
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    appState.watchHistory.removeAll()
                                }
                                if let userId = appState.currentUser?.id {
                                    Task {
                                        await HistoryService.shared.clearAll(userId: userId)
                                    }
                                }
                            } label: {
                                Label("Clear All History", systemImage: "trash")
                            }
                            if !selection.isEmpty {
                                Button(role: .destructive) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        let itemsToRemove = appState.watchHistory.filter { selection.contains($0.id) }
                                        appState.watchHistory.removeAll { selection.contains($0.id) }
                                        selection.removeAll()
                                        
                                        if let userId = appState.currentUser?.id {
                                            Task {
                                                for item in itemsToRemove {
                                                    await HistoryService.shared.removeItem(itemId: item.id, userId: userId)
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Remove Selected", systemImage: "trash.slash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            searchBar

            if filtered.isEmpty {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Videos you watch will appear here.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background.ignoresSafeArea())
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 56))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text("No History")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("Videos you watch will appear here.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.Colors.background.ignoresSafeArea())
                }
            } else {
                List(selection: $selection) {
                    ForEach(groupedHistory, id: \.0) { section, items in
                        Section {
                            ForEach(items) { item in
                                Button {
                                    HapticManager.shared.impact(style: .light)
                                    handleItemTap(item)
                                } label: {
                                    HistoryRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(AppTheme.Colors.background)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        removeItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(section)
                                .font(.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.plain)
                .background(AppTheme.Colors.background)
                .environment(\.defaultMinListRowHeight, 80)
            }
        }
        .background(AppTheme.Colors.background)
    }
    
    private func handleItemTap(_ item: WatchHistoryItem) {
        switch item.contentType {
        case .video, .flick:
            NotificationCenter.default.post(name: .openVideoFromHistory, object: item)
            dismiss()
        case .story:
            Foundation.NotificationCenter.default.post(name: .openStoryFromHistory, object: item)
            dismiss()
        case .liveTV:
            Foundation.NotificationCenter.default.post(name: .openLiveTVFromHistory, object: item)
            dismiss()
        }
    }
    
    private func removeItem(_ item: WatchHistoryItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            appState.watchHistory.removeAll { $0.id == item.id }
        }
        if let userId = appState.currentUser?.id {
            Task {
                await HistoryService.shared.removeItem(itemId: item.id, userId: userId)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.Colors.textSecondary)
            TextField("Search history", text: $query)
                .textFieldStyle(.plain)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

private struct HistoryRow: View {
    let item: WatchHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: item.thumbnailURL)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray6)
                }
                .frame(width: 130, height: 73)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 4) {
                        if item.contentType != .video {
                            Image(systemName: item.contentType.iconName)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(item.formattedDuration)
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(6)
                }
                
                if item.watchProgress > 0 {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geo.size.width * item.watchProgress, height: 3)
                    }
                    .frame(height: 3)
                }
            }
            .frame(width: 130, height: 73)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Text(item.creatorName)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    if item.watchProgress > 0 {
                        Text("•")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        if item.isCompleted {
                            Text("Watched")
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        } else {
                            Text("\(Int(item.watchProgress * 100))% watched")
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                .font(.caption)
                .lineLimit(1)
                
                Text(item.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .contentShape(Rectangle())
    }
}

#Preview("WatchHistoryView") {
    let state = AppState()
    let _ = {
        state.currentUser = User.sampleUsers.first
        state.watchHistory = Array(Video.sampleVideos.prefix(10)).enumerated().map { index, video in
            WatchHistoryItem.fromVideo(
                video,
                watchedAt: Date().addingTimeInterval(-Double(index) * 3600),
                progress: Double.random(in: 0.1...1.0),
                position: video.duration * Double.random(in: 0.1...0.9)
            )
        }
    }()
    WatchHistoryView()
        .environmentObject(state)
        .preferredColorScheme(.light)
}