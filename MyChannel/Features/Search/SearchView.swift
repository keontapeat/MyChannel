//
//  SearchView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = AdvancedSearchService()
    @State private var searchText: String = ""
    @State private var selectedScope: SearchScope = .all
    @State private var isSearching: Bool = false
    @State private var recentSearches: [String] = ["SwiftUI", "iOS Development", "Gaming"]
    @State private var searchFilters = SearchFilters()
    @State private var showingFilters = false
    @FocusState private var isSearchFieldFocused: Bool  // Add focus state
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom header with back button
                HStack(spacing: 16) {
                    // Back/Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.Colors.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Professional search bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        TextField("Search videos, creators, and more...", text: $searchText)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .textFieldStyle(PlainTextFieldStyle())
                            .focused($isSearchFieldFocused)  // Bind focus state
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                            }
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    .padding()
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.md)
                    
                    // Filters button
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.Colors.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.background)
                
                // Search scopes
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SearchScope.allCases, id: \.self) { scope in
                            Button(scope.displayName) {
                                selectedScope = scope
                                if !searchText.isEmpty {
                                    performSearch()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedScope == scope ? AppTheme.Colors.primary : AppTheme.Colors.surface
                            )
                            .foregroundColor(
                                selectedScope == scope ? .white : AppTheme.Colors.textPrimary
                            )
                            .cornerRadius(AppTheme.CornerRadius.md)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)

                ZStack(alignment: .topLeading) {
                    if searchText.isEmpty {
                        SearchEmptyState(recentSearches: recentSearches) { search in
                            searchText = search
                            performSearch()
                        }
                    } else if isSearching {
                        SearchLoadingState()
                    } else {
                        ModernSearchResultsList(results: searchService.searchResults)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // Spacer()
            }
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .transaction { $0.animation = nil }
            .animation(.none, value: isSearching)
            .animation(.none, value: searchText)
            .animation(.none, value: selectedScope)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            // Auto-focus search bar when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSearchFieldFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusSearchBar"))) { _ in
            // Focus search bar when notification is received
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SearchClearAndReset"))) { _ in
            // Clear search and reset when tab is reselected
            searchText = ""
            selectedScope = .all
            isSearchFieldFocused = true
        }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersView(filters: $searchFilters) {
                if !searchText.isEmpty {
                    performSearch()
                }
            }
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty && newValue != oldValue {
                // Debounced search
                Task {
                    try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    if searchText == newValue { // Still the same query
                        await searchService.getSearchSuggestions(for: newValue)
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        
        Task {
            do {
                let _ = try await searchService.search(
                    query: searchText,
                    filters: searchFilters
                )
                
                // Add to recent searches
                if !recentSearches.contains(searchText) {
                    recentSearches.insert(searchText, at: 0)
                    if recentSearches.count > 10 {
                        recentSearches.removeLast()
                    }
                }
                
                await MainActor.run {
                    isSearching = false
                }
            } catch {
                print("Search error: \(error)")
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }
}

// MARK: - Search Empty State
struct SearchEmptyState: View {
    let recentSearches: [String]
    let onSearchTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recent Searches")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                VStack(spacing: 12) {
                    ForEach(recentSearches, id: \.self) { search in
                        Button(action: { onSearchTap(search) }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                
                                Text(search)
                                    .font(AppTheme.Typography.body)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.left")
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            .padding()
                            .background(AppTheme.Colors.surface)
                            .cornerRadius(AppTheme.CornerRadius.md)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Trending Searches")
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(["SwiftUI", "iOS 17", "Xcode", "macOS", "Flutter", "React"], id: \.self) { trend in
                        Button(action: { onSearchTap(trend) }) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .font(.caption)
                                
                                Text(trend)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.surface)
                            .cornerRadius(AppTheme.CornerRadius.sm)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Search Loading State
struct SearchLoadingState: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Modern Search Results List
struct ModernSearchResultsList: View {
    let results: [SearchResult]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    ModernSearchResultCard(result: result)
                        .padding(.horizontal)
                }
                
                if results.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("No results found")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text("Try adjusting your search terms or filters")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Modern Search Result Card
struct ModernSearchResultCard: View {
    let result: SearchResult
    
    var body: some View {
        switch result {
        case .video(let videoResult):
            VideoSearchCard(videoResult: videoResult)
        case .creator(let creatorResult):
            CreatorSearchCard(creatorResult: creatorResult)
        case .playlist(let playlistResult):
            PlaylistSearchCard(playlistResult: playlistResult)
        case .liveStream(let liveResult):
            LiveStreamSearchCard(liveResult: liveResult)
        }
    }
}

struct VideoSearchCard: View {
    let videoResult: VideoSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: videoResult.video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            .frame(width: 120, height: 68)
            .cornerRadius(AppTheme.CornerRadius.sm)
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(videoResult.video.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(videoResult.video.creator.displayName)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack {
                    Text("\(videoResult.video.viewCount) views")
                    Text("•")
                    Text(videoResult.video.createdAt, style: .relative)
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
                
                HStack {
                    Text("Relevance: \(Int(videoResult.relevanceScore * 100))%")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.primary.opacity(0.1))
                        .foregroundColor(AppTheme.Colors.primary)
                        .cornerRadius(4)
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

struct CreatorSearchCard: View {
    let creatorResult: CreatorSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: creatorResult.creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(creatorResult.creator.displayName)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("@\(creatorResult.creator.username)")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("\(creatorResult.creator.subscriberCount) subscribers")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
                
                if let bio = creatorResult.creator.bio {
                    Text(bio)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button("Subscribe") {
                // Handle subscription
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.CornerRadius.sm)
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

struct PlaylistSearchCard: View {
    let playlistResult: PlaylistSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 120, height: 68)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlistResult.playlist.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("By Creator")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("\(playlistResult.playlist.videoCount) videos")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

struct LiveStreamSearchCard: View {
    let liveResult: LiveStreamSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                AsyncImage(url: URL(string: liveResult.video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                }
                .frame(width: 120, height: 68)
                .cornerRadius(AppTheme.CornerRadius.sm)
                .clipped()
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("LIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                .padding(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(liveResult.video.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(liveResult.video.creator.displayName)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text("\(liveResult.viewerCount) watching")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Search Filters View
struct SearchFiltersView: View {
    @Binding var filters: SearchFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Content Type") {
                    Picker("Category", selection: $filters.category) {
                        Text("All Categories").tag(VideoCategory?.none)
                        ForEach(VideoCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category as VideoCategory?)
                        }
                    }
                }
                
                Section("Duration") {
                    Picker("Duration", selection: $filters.duration) {
                        Text("Any Duration").tag(SearchFilters.DurationFilter?.none)
                        ForEach(SearchFilters.DurationFilter.allCases, id: \.self) { duration in
                            Text(duration.rawValue).tag(duration as SearchFilters.DurationFilter?)
                        }
                    }
                }
                
                Section("Upload Date") {
                    Picker("Upload Date", selection: $filters.uploadDate) {
                        Text("Any Time").tag(SearchFilters.UploadDateFilter?.none)
                        ForEach(SearchFilters.UploadDateFilter.allCases, id: \.self) { date in
                            Text(date.rawValue).tag(date as SearchFilters.UploadDateFilter?)
                        }
                    }
                }
                
                Section("Sort By") {
                    Picker("Sort By", selection: $filters.sortBy) {
                        Text("Relevance").tag(SearchFilters.SortOption?.none)
                        ForEach(SearchFilters.SortOption.allCases, id: \.self) { sort in
                            Text(sort.rawValue).tag(sort as SearchFilters.SortOption?)
                        }
                    }
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Supporting Models
enum SearchScope: String, CaseIterable {
    case all = "all"
    case videos = "videos"
    case creators = "creators"
    case community = "community"  // Added Community
    case playlists = "playlists"
    case live = "live"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .videos: return "Videos"
        case .creators: return "Creators"
        case .community: return "Community"  // New scope
        case .playlists: return "Playlists"
        case .live: return "Live"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "magnifyingglass"
        case .videos: return "play.rectangle"
        case .creators: return "person.circle"
        case .community: return "person.3"  // Community icon
        case .playlists: return "rectangle.stack"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
}

#Preview {
    SearchView()
        .preferredColorScheme(.light)
}