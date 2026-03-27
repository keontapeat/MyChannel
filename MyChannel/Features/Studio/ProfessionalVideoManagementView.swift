//
//  ProfessionalVideoManagementView.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import SwiftUI

// 📹 Professional YouTube-Style Video Management Interface
// Industry-standard video management with enterprise features
struct ProfessionalVideoManagementView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var videoService = EnhancedVideoManagementService.shared
    @State private var selectedVideos: Set<String> = []
    @State private var showingBulkActions = false
    @State private var showingFilters = false
    @State private var showingSortOptions = false
    @State private var searchText = ""
    @State private var showingVideoDetails: EnhancedVideo?
    @State private var showingScheduleSheet = false
    @State private var showingVisibilitySheet = false
    
    // Search and filter state
    @State private var searchResults: [EnhancedVideo] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Professional Header with Search and Actions
                headerSection
                
                // Filter Tabs (YouTube Style)
                filterTabsSection
                
                // Toolbar with Sort, View Mode, and Bulk Actions
                toolbarSection
                
                // Video List/Grid
                videoContentSection
            }
            .navigationTitle("Content")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Upload video", systemImage: "plus") {
                            // Handle video upload
                        }
                        Button("Go live", systemImage: "dot.radiowaves.left.and.right") {
                            // Handle live streaming
                        }
                        Button("Create playlist", systemImage: "list.bullet.rectangle") {
                            // Handle playlist creation
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                    }
                }
            }
            .task {
                await loadVideos()
            }
            .refreshable {
                await loadVideos()
            }
            .sheet(item: $showingVideoDetails) { video in
                VideoDetailsSheet(video: video)
            }
            .sheet(isPresented: $showingScheduleSheet) {
                VideoScheduleSheet(selectedVideos: Array(selectedVideos))
            }
            .sheet(isPresented: $showingVisibilitySheet) {
                VideoVisibilitySheet(selectedVideos: Array(selectedVideos))
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("Search your videos", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { newValue in
                            if newValue.isEmpty {
                                searchResults = []
                                isSearching = false
                            } else if newValue.count >= 2 {
                                performSearch()
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                            isSearching = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Filter Button
                Button(action: {
                    showingFilters.toggle()
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            
            // Quick Stats (YouTube Style)
            if !videoService.videos.isEmpty {
                quickStatsSection
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var quickStatsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                QuickStatCard(
                    title: "Total videos",
                    value: "\(videoService.videos.count)",
                    icon: "play.rectangle",
                    color: .blue
                )
                
                QuickStatCard(
                    title: "Total views",
                    value: formatNumber(videoService.videos.reduce(0) { $0 + $1.viewCount }),
                    icon: "eye",
                    color: .green
                )
                
                QuickStatCard(
                    title: "Public",
                    value: "\(videoService.videos.filter { $0.visibility == .publicVideo }.count)",
                    icon: "globe",
                    color: .orange
                )
                
                QuickStatCard(
                    title: "Scheduled",
                    value: "\(videoService.videos.filter { $0.isScheduled }.count)",
                    icon: "calendar",
                    color: .purple
                )
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Filter Tabs Section
    
    private var filterTabsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(VideoManagementFilter.allCases, id: \.self) { filter in
                    FilterTabButton(
                        filter: filter,
                        isSelected: videoService.selectedFilter == filter,
                        count: getFilterCount(filter)
                    ) {
                        videoService.applyFilter(filter)
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Toolbar Section
    
    private var toolbarSection: some View {
        HStack {
            // Bulk Selection
            if !selectedVideos.isEmpty {
                Button("Select all") {
                    if selectedVideos.count == videoService.filteredVideos.count {
                        selectedVideos.removeAll()
                    } else {
                        selectedVideos = Set(videoService.filteredVideos.map { $0.id })
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                
                Text("(\(selectedVideos.count) selected)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Text("\(videoService.filteredVideos.count) videos")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Bulk Actions
            if !selectedVideos.isEmpty {
                HStack(spacing: 12) {
                    Button(action: {
                        showingVisibilitySheet = true
                    }) {
                        Image(systemName: "eye")
                            .font(.system(size: 16))
                    }
                    
                    Button(action: {
                        showingScheduleSheet = true
                    }) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16))
                    }
                    
                    Button(action: {
                        Task {
                            await bulkDeleteVideos()
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    // Sort Menu
                    Menu {
                        ForEach(VideoSortOption.allCases, id: \.self) { option in
                            Button(action: {
                                videoService.applySorting(option)
                            }) {
                                HStack {
                                    Text(option.displayName)
                                    if videoService.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16))
                    }
                    
                    // View Mode Toggle
                    Button(action: {
                        videoService.viewMode = videoService.viewMode == .list ? .grid : .list
                    }) {
                        Image(systemName: videoService.viewMode == .list ? "square.grid.2x2" : "list.bullet")
                            .font(.system(size: 16))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Video Content Section
    
    private var videoContentSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let videosToShow = isSearching ? searchResults : videoService.filteredVideos
                
                if videosToShow.isEmpty {
                    emptyStateView
                } else {
                    if videoService.viewMode == .list {
                        ForEach(videosToShow) { video in
                            VideoListRow(
                                video: video,
                                isSelected: selectedVideos.contains(video.id),
                                onSelectionChanged: { isSelected in
                                    if isSelected {
                                        selectedVideos.insert(video.id)
                                    } else {
                                        selectedVideos.remove(video.id)
                                    }
                                },
                                onTap: {
                                    showingVideoDetails = video
                                }
                            )
                            .padding(.horizontal, 16)
                            
                            Divider()
                                .padding(.leading, 80)
                        }
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(videosToShow) { video in
                                ManagementVideoGridCard(
                                    video: video,
                                    isSelected: selectedVideos.contains(video.id),
                                    onSelectionChanged: { isSelected in
                                        if isSelected {
                                            selectedVideos.insert(video.id)
                                        } else {
                                            selectedVideos.remove(video.id)
                                        }
                                    },
                                    onTap: {
                                        showingVideoDetails = video
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .refreshable {
            await loadVideos()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No videos found")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(isSearching ? "Try adjusting your search terms" : "Upload your first video to get started")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !isSearching {
                Button("Upload video") {
                    // Handle video upload
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 60)
    }
    
    // MARK: - Actions
    
    private func loadVideos() async {
        guard let creatorId = appState.currentUser?.id else { return }
        
        do {
            let _ = try await videoService.loadVideos(creatorId: creatorId, filter: videoService.selectedFilter)
        } catch {
            print("Failed to load videos: \(error)")
        }
    }
    
    private func performSearch() {
        isSearching = !searchText.isEmpty
        if isSearching {
            searchResults = videoService.searchVideos(query: searchText)
        }
    }
    
    private func getFilterCount(_ filter: VideoManagementFilter) -> Int {
        switch filter {
        case .all:
            return videoService.videos.count
        case .publicVideos:
            return videoService.videos.filter { $0.visibility == .publicVideo }.count
        case .unlisted:
            return videoService.videos.filter { $0.visibility == .unlisted }.count
        case .privateVideos:
            return videoService.videos.filter { $0.visibility == .privateVideo }.count
        case .scheduled:
            return videoService.videos.filter { $0.isScheduled }.count
        case .drafts:
            return videoService.videos.filter { $0.status == .draft }.count
        case .live:
            return videoService.videos.filter { $0.isLive }.count
        }
    }
    
    private func bulkDeleteVideos() async {
        do {
            try await videoService.bulkDelete(videoIds: Array(selectedVideos))
            selectedVideos.removeAll()
        } catch {
            print("Failed to delete videos: \(error)")
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
}

// MARK: - Supporting Views

struct FilterTabButton: View {
    let filter: VideoManagementFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(filter.displayName)
                    .font(.system(size: 14, weight: .medium))
                
                if count > 0 {
                    Text("(\(count))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 100)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct VideoListRow: View {
    let video: EnhancedVideo
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection Checkbox
            Button(action: {
                onSelectionChanged(!isSelected)
                HapticManager.shared.impact(style: .light)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            
            // Thumbnail
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 120, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                // Duration Badge
                Text(video.formattedDuration)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(2)
                    .padding(4),
                alignment: .bottomTrailing
            )
            
            // Video Info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    // Visibility Icon
                    Image(systemName: video.visibilityIcon)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(video.visibility.rawValue.capitalized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(video.formattedViewCount)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    // Status Badge
                    Text(video.status.rawValue.capitalized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(video.statusColor))
                        .cornerRadius(4)
                    
                    if let publishedAt = video.publishedAt {
                        Text(RelativeDateTimeFormatter().localizedString(for: publishedAt, relativeTo: Date()))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else if video.isScheduled, let scheduledAt = video.scheduledAt {
                        Text("Scheduled for \(scheduledAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Performance Indicators
            VStack(alignment: .trailing, spacing: 4) {
                if video.performanceScore > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("\(Int(video.performanceScore * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
                
                Button(action: onTap) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct ManagementVideoGridCard: View {
    let video: EnhancedVideo
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Thumbnail
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    // Duration Badge
                    Text(video.formattedDuration)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(2)
                        .padding(4),
                    alignment: .bottomTrailing
                )
                
                // Selection Checkbox
                Button(action: {
                    onSelectionChanged(!isSelected)
                    HapticManager.shared.impact(style: .light)
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .accentColor : .white)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: 24, height: 24)
                        )
                }
                .padding(8)
            }
            
            // Video Info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: video.visibilityIcon)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(video.formattedViewCount)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if video.performanceScore > 0 {
                        Text("\(Int(video.performanceScore * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Sheet Views

struct VideoDetailsSheet: View {
    let video: EnhancedVideo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Video Preview
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(16/9, contentMode: .fit)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Video Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text(video.title)
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text(video.description)
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        // Stats Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            StatItem(title: "Views", value: video.formattedViewCount)
                            StatItem(title: "Likes", value: "\(video.likeCount)")
                            StatItem(title: "Comments", value: "\(video.commentCount)")
                            StatItem(title: "Shares", value: "\(video.shareCount)")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Video Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct VideoScheduleSheet: View {
    let selectedVideos: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var scheduledDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Schedule \(selectedVideos.count) video(s)")
                    .font(.system(size: 18, weight: .semibold))
                
                DatePicker("Scheduled Date", selection: $scheduledDate, in: Date()...)
                    .datePickerStyle(.wheel)
                
                Button("Schedule Videos") {
                    // Handle scheduling
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("Schedule Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct VideoVisibilitySheet: View {
    let selectedVideos: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVisibility: VideoVisibility = .publicVideo
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Change visibility for \(selectedVideos.count) video(s)")
                    .font(.system(size: 18, weight: .semibold))
                
                VStack(spacing: 12) {
                    ForEach(VideoVisibility.allCases, id: \.self) { visibility in
                        Button(action: {
                            selectedVisibility = visibility
                        }) {
                            HStack {
                                Image(systemName: getVisibilityIcon(visibility))
                                    .font(.system(size: 16))
                                
                                VStack(alignment: .leading) {
                                    Text(visibility.rawValue.capitalized)
                                        .font(.system(size: 16, weight: .medium))
                                    Text(getVisibilityDescription(visibility))
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedVisibility == visibility {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Button("Update Visibility") {
                    // Handle visibility update
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .navigationTitle("Video Visibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getVisibilityIcon(_ visibility: VideoVisibility) -> String {
        switch visibility {
        case .publicVideo: return "globe"
        case .unlisted: return "link"
        case .privateVideo: return "lock"
        }
    }
    
    private func getVisibilityDescription(_ visibility: VideoVisibility) -> String {
        switch visibility {
        case .publicVideo: return "Anyone can search for and view"
        case .unlisted: return "Anyone with the link can view"
        case .privateVideo: return "Only you can view"
        }
    }
}

#Preview {
    ProfessionalVideoManagementView()
        .environmentObject(AppState())
}
