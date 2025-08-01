//
//  SearchView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    @State private var selectedFilter: SearchFilter = .all
    @State private var recentSearches: [String] = ["SwiftUI tutorial", "iOS development", "Xcode tips"]
    @State private var trendingSearches: [String] = ["WWDC 2024", "iPhone 16", "iOS 18 features", "Swift 6.0"]
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var showingFilters: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Header
                SearchHeader(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    showingFilters: $showingFilters,
                    onSearch: performSearch
                )
                
                if searchText.isEmpty {
                    // Empty state with suggestions
                    SearchSuggestions(
                        recentSearches: recentSearches,
                        trendingSearches: trendingSearches,
                        onSearchTap: { search in
                            searchText = search
                            performSearch()
                        }
                    )
                } else if isSearching {
                    // Loading state
                    SearchLoadingView()
                } else {
                    // Search results
                    SearchResultsList(
                        results: searchResults,
                        selectedFilter: selectedFilter
                    )
                }
                
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationBarHidden(true)
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty && newValue != oldValue {
                // Debounce search
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if searchText == newValue {
                        performSearch()
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        // Add to recent searches
        if !recentSearches.contains(searchText) {
            recentSearches.insert(searchText, at: 0)
            recentSearches = Array(recentSearches.prefix(5))
        }
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            searchResults = SearchResult.mockResults(for: searchText)
            isSearching = false
        }
    }
}

struct SearchHeader: View {
    @Binding var searchText: String
    @Binding var selectedFilter: SearchFilter
    @Binding var showingFilters: Bool
    let onSearch: () -> Void
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    TextField("Search videos, creators, topics...", text: $searchText)
                        .focused($isSearchFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            onSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.lg)
                
                // Filter button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingFilters.toggle()
                    }
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(showingFilters ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(showingFilters ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Filter chips
            if showingFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SearchFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                icon: filter.iconName,
                                isSelected: selectedFilter == filter,
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedFilter = filter
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(AppTheme.Colors.background)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface
            )
            .foregroundColor(
                isSelected ? .white : AppTheme.Colors.textPrimary
            )
            .cornerRadius(AppTheme.CornerRadius.lg)
            .shadow(
                color: isSelected ? AppTheme.Colors.primary.opacity(0.3) : .clear,
                radius: isSelected ? 4 : 0,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct SearchSuggestions: View {
    let recentSearches: [String]
    let trendingSearches: [String]
    let onSearchTap: (String) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Recent searches
                if !recentSearches.isEmpty {
                    SearchSuggestionsSection(
                        title: "Recent Searches",
                        icon: "clock",
                        searches: recentSearches,
                        onSearchTap: onSearchTap
                    )
                }
                
                // Trending searches
                SearchSuggestionsSection(
                    title: "Trending",
                    icon: "flame",
                    searches: trendingSearches,
                    onSearchTap: onSearchTap
                )
                
                // Quick actions
                QuickActionsSection()
            }
            .padding()
        }
    }
}

struct SearchSuggestionsSection: View {
    let title: String
    let icon: String
    let searches: [String]
    let onSearchTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text(title)
                    .font(AppTheme.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: 0) {
                ForEach(Array(searches.enumerated()), id: \.offset) { index, search in
                    Button(action: {
                        onSearchTap(search)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: icon == "clock" ? "clock" : "arrow.up.right")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                                .frame(width: 20)
                            
                            Text(search)
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .padding()
                        .background(AppTheme.Colors.background)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if index < searches.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.lg)
        }
    }
}

struct QuickActionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(AppTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                QuickActionCard(
                    icon: "camera.fill",
                    title: "Go Live",
                    description: "Start streaming now",
                    color: AppTheme.Colors.primary
                ) {
                    // Start live stream
                }
                
                QuickActionCard(
                    icon: "bolt.fill",
                    title: "Create Short",
                    description: "Quick video creation",
                    color: AppTheme.Colors.secondary
                ) {
                    // Create short
                }
                
                QuickActionCard(
                    icon: "music.note",
                    title: "Browse Music",
                    description: "Find trending sounds",
                    color: .purple
                ) {
                    // Browse music
                }
                
                QuickActionCard(
                    icon: "star.fill",
                    title: "Featured",
                    description: "Editor's picks",
                    color: .orange
                ) {
                    // Show featured content
                }
            }
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                .scaleEffect(1.2)
            
            Text("Searching...")
                .font(AppTheme.Typography.subheadline)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchResultsList: View {
    let results: [SearchResult]
    let selectedFilter: SearchFilter
    
    var filteredResults: [SearchResult] {
        if selectedFilter == .all {
            return results
        } else {
            return results.filter { $0.type == selectedFilter.resultType }
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredResults) { result in
                    SearchResultRow(result: result)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail/Avatar
            AsyncImage(url: URL(string: result.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                            .scaleEffect(0.8)
                    )
            }
            .frame(
                width: result.type == .creator ? 50 : 120,
                height: result.type == .creator ? 50 : 68
            )
            .clipShape(
                result.type == .creator ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 8))
            )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(AppTheme.Typography.headline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    Image(systemName: result.type.iconName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                    
                    Text(result.metadata)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            
            Spacer()
            
            // Action button
            Button(action: {}) {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.lg)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Supporting Types

enum SearchFilter: String, CaseIterable {
    case all = "all"
    case videos = "videos"
    case shorts = "shorts"
    case creators = "creators"
    case playlists = "playlists"
    case live = "live"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .videos: return "Videos"
        case .shorts: return "Shorts"
        case .creators: return "Creators"
        case .playlists: return "Playlists"
        case .live: return "Live"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .videos: return "play.rectangle"
        case .shorts: return "bolt"
        case .creators: return "person.circle"
        case .playlists: return "list.bullet"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
    
    var resultType: SearchResultType? {
        switch self {
        case .all: return nil
        case .videos: return .video
        case .shorts: return .short
        case .creators: return .creator
        case .playlists: return .playlist
        case .live: return .live
        }
    }
}

enum SearchResultType: String, CaseIterable {
    case video = "video"
    case short = "short"
    case creator = "creator"
    case playlist = "playlist"
    case live = "live"
    
    var iconName: String {
        switch self {
        case .video: return "play.rectangle"
        case .short: return "bolt"
        case .creator: return "person.circle"
        case .playlist: return "list.bullet"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
}

struct SearchResult: Identifiable {
    let id: String
    let type: SearchResultType
    let title: String
    let subtitle: String?
    let thumbnailURL: String
    let metadata: String
    
    init(
        id: String = UUID().uuidString,
        type: SearchResultType,
        title: String,
        subtitle: String? = nil,
        thumbnailURL: String,
        metadata: String
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
        self.metadata = metadata
    }
}

extension SearchResult {
    static func mockResults(for query: String) -> [SearchResult] {
        [
            SearchResult(
                type: .video,
                title: "Advanced \(query) Techniques",
                subtitle: "Tech Creator",
                thumbnailURL: "https://picsum.photos/120/68?random=\(Int.random(in: 1...100))",
                metadata: "45K views • 2 days ago"
            ),
            SearchResult(
                type: .creator,
                title: "Tech Creator",
                subtitle: "125K subscribers",
                thumbnailURL: "https://picsum.photos/50/50?random=\(Int.random(in: 1...100))",
                metadata: "Verified creator"
            ),
            SearchResult(
                type: .short,
                title: "Quick \(query) Tip",
                subtitle: "Creative Artist",
                thumbnailURL: "https://picsum.photos/120/68?random=\(Int.random(in: 1...100))",
                metadata: "2.3M views • 1 hour ago"
            ),
            SearchResult(
                type: .playlist,
                title: "\(query) Complete Course",
                subtitle: "24 videos",
                thumbnailURL: "https://picsum.photos/120/68?random=\(Int.random(in: 1...100))",
                metadata: "Updated yesterday"
            ),
            SearchResult(
                type: .live,
                title: "Live \(query) Session",
                subtitle: "Gaming Pro",
                thumbnailURL: "https://picsum.photos/120/68?random=\(Int.random(in: 1...100))",
                metadata: "1.2K watching now"
            )
        ]
    }
}

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

#Preview {
    SearchView()
}