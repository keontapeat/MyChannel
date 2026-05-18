//
//  WatchHistoryView.swift
//  MyChannel
//
//  Enhanced with YouTube parity features
//

import SwiftUI
import UIKit

private enum HistoryTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case videos = "Videos"
    case shorts = "Shorts"
    case live = "Live"
    case posts = "Posts"
    
    var id: String { rawValue }
    
    func matches(_ item: WatchHistoryItem) -> Bool {
        switch self {
        case .all:
            return true
        case .videos:
            return item.contentType == .video
        case .shorts:
            return item.contentType == .flick || item.contentType == .story
        case .live:
            return item.contentType == .liveTV
        case .posts:
            return item.contentType == .post
        }
    }
}

struct WatchHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var historyService = HistoryService.shared

    @State private var selection = Set<String>()
    @State private var query: String = ""
    @State private var isLoading = false
    @State private var selectedFilter: HistoryTypeFilter = .all
    @State private var showShareSheet = false
    @State private var showAddToPlaylist = false
    @State private var shareItems: [Any] = []
    @State private var playlistVideoId: String = ""

    private var historyItems: [WatchHistoryItem] {
        appState.watchHistory
    }

    private var filtered: [WatchHistoryItem] {
        historyItems.filter { item in
            selectedFilter.matches(item) &&
            (query.isEmpty ||
             item.title.localizedCaseInsensitiveContains(query) ||
             item.creatorName.localizedCaseInsensitiveContains(query))
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
                            Button {
                                togglePauseHistory()
                            } label: {
                                Label(
                                    historyService.isWatchHistoryPaused ? "Resume Watch History" : "Pause Watch History",
                                    systemImage: historyService.isWatchHistoryPaused ? "play.circle" : "pause.circle"
                                )
                            }
                            
                            Button {
                                NotificationCenter.default.post(name: Notification.Name("OpenHistoryManagement"), object: nil)
                            } label: {
                                Label("Manage All History", systemImage: "slider.horizontal.3")
                            }
                            
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
        .sheet(isPresented: $showShareSheet) {
            VideoShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(videoId: playlistVideoId)
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            searchBar
            filterTabs
            pauseBanner

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
                HistoryUIKitList(
                    sections: groupedHistory,
                    onTap: handleItemTap,
                    onRemove: removeItem,
                    onQueue: addToQueue,
                    onPlaylist: saveToPlaylist,
                    onShare: shareItem,
                    onNotInterested: markNotInterested
                )
                .background(AppTheme.Colors.background)
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
        case .post:
            Foundation.NotificationCenter.default.post(name: Notification.Name("openPostFromHistory"), object: item)
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

    private func togglePauseHistory() {
        guard let userId = appState.currentUser?.id else { return }
        Task {
            await historyService.setPaused(!historyService.isWatchHistoryPaused, userId: userId)
        }
    }
    
    private func addToQueue(_ item: WatchHistoryItem) {
        guard item.contentType == .video || item.contentType == .flick else {
            NotificationManager.shared.showError("Only videos can be added to the queue")
            return
        }
        let video = Video(
            id: item.contentId,
            title: item.title,
            description: "",
            thumbnailURL: item.thumbnailURL,
            videoURL: "",
            duration: item.duration,
            viewCount: 0,
            likeCount: 0,
            dislikeCount: 0,
            commentCount: 0,
            createdAt: item.watchedAt,
            updatedAt: item.watchedAt,
            creator: User(
                id: item.creatorId,
                username: item.creatorName,
                displayName: item.creatorName,
                email: ""
            ),
            category: .entertainment,
            tags: [],
            isPublic: true
        )
        GlobalVideoPlayerManager.shared.addToQueue(video)
        NotificationManager.shared.showSuccess("Added to queue")
    }
    
    private func saveToPlaylist(_ item: WatchHistoryItem) {
        playlistVideoId = item.contentId
        showAddToPlaylist = true
    }
    
    private func shareItem(_ item: WatchHistoryItem) {
        shareItems = [URL(string: "https://mychannel.app/watch/\(item.contentId)") as Any].compactMap { $0 }
        showShareSheet = true
    }
    
    private func markNotInterested(_ item: WatchHistoryItem) {
        NotificationCenter.default.post(name: Notification.Name("HistoryItemNotInterested"), object: item)
        Task {
            guard let userId = appState.currentUser?.id else { return }
            await HistoryService.shared.saveNotInterested(item, userId: userId)
        }
        removeItem(item)
        NotificationManager.shared.showSuccess("We'll recommend fewer videos like this")
    }

    private var searchBar: some View {
        HistorySearchBar(text: $query, placeholder: "Search history")
            .frame(height: 44)
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryTypeFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selectedFilter == filter ? Color.white : AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? AppTheme.Colors.primary : AppTheme.Colors.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    @ViewBuilder
    private var pauseBanner: some View {
        if historyService.isWatchHistoryPaused {
            HStack(spacing: 10) {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(AppTheme.Colors.primary)
                Text("Watch history is paused")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                Button("Resume") {
                    togglePauseHistory()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primary)
            }
            .padding(12)
            .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

private struct HistorySearchBar: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = placeholder
        searchBar.autocapitalizationType = .none
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }
    
    final class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }
}

private struct HistoryUIKitList: UIViewRepresentable {
    let sections: [(String, [WatchHistoryItem])]
    let onTap: (WatchHistoryItem) -> Void
    let onRemove: (WatchHistoryItem) -> Void
    let onQueue: (WatchHistoryItem) -> Void
    let onPlaylist: (WatchHistoryItem) -> Void
    let onShare: (WatchHistoryItem) -> Void
    let onNotInterested: (WatchHistoryItem) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HistoryCell")
        return tableView
    }
    
    func updateUIView(_ uiView: UITableView, context: Context) {
        context.coordinator.parent = self
        uiView.reloadData()
    }
    
    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var parent: HistoryUIKitList
        
        init(parent: HistoryUIKitList) {
            self.parent = parent
        }
        
        func numberOfSections(in tableView: UITableView) -> Int {
            parent.sections.count
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            parent.sections[section].1.count
        }
        
        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            parent.sections[section].0
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            parent.onTap(parent.sections[indexPath.section].1[indexPath.row])
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
            let item = parent.sections[indexPath.section].1[indexPath.row]
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            cell.contentConfiguration = UIHostingConfiguration {
                HistoryRow(
                    item: item,
                    onRemove: { self.parent.onRemove(item) },
                    onQueue: { self.parent.onQueue(item) },
                    onPlaylist: { self.parent.onPlaylist(item) },
                    onShare: { self.parent.onShare(item) },
                    onNotInterested: { self.parent.onNotInterested(item) }
                )
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .margins(.all, 0)
            return cell
        }
        
        func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            let item = parent.sections[indexPath.section].1[indexPath.row]
            let delete = UIContextualAction(style: .destructive, title: "Remove") { _, _, completion in
                self.parent.onRemove(item)
                completion(true)
            }
            return UISwipeActionsConfiguration(actions: [delete])
        }
    }
}

private struct LegacyHistorySearchBar: View {
    @Binding var query: String
    
    var body: some View {
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
    let onRemove: () -> Void
    let onQueue: () -> Void
    let onPlaylist: () -> Void
    let onShare: () -> Void
    let onNotInterested: () -> Void

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
                
                if item.canResume {
                    Text("Resume")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Colors.primary, in: Capsule())
                        .padding(6)
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

            Menu {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove from watch history", systemImage: "trash")
                }
                Button(action: onQueue) {
                    Label("Add to queue", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                if item.contentType == .video || item.contentType == .flick {
                    Button(action: onPlaylist) {
                        Label("Save to playlist", systemImage: "text.badge.plus")
                    }
                }
                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button(action: onNotInterested) {
                    Label("Not interested", systemImage: "hand.thumbsdown")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
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