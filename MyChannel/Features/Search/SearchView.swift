//
//  SearchView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct SearchView: View {
    @State private var searchText: String = ""
    @State private var selectedScope: SearchScope = .all
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var recentSearches: [String] = ["SwiftUI", "iOS Development", "Gaming"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Professional search bar
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        TextField("Search videos, creators, and more...", text: $searchText)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .textFieldStyle(PlainTextFieldStyle())
                        
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
                    
                    // Search scopes
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SearchScope.allCases, id: \.self) { scope in
                                Button(scope.displayName) {
                                    selectedScope = scope
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
                        .padding(.horizontal)
                    }
                }
                .padding()
                
                // Search content
                if searchText.isEmpty {
                    SearchEmptyState(recentSearches: recentSearches) { search in
                        searchText = search
                    }
                } else if isSearching {
                    SearchLoadingState()
                } else {
                    SearchResultsList(results: searchResults)
                }
                
                Spacer()
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: searchText) { oldValue, newValue in
            if !newValue.isEmpty {
                performSearch(query: newValue)
            }
        }
    }
    
    private func performSearch(query: String) {
        isSearching = true
        
        // Simulate search delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            searchResults = SearchResult.mockResults(for: query, scope: selectedScope)
            isSearching = false
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

// MARK: - Search Results List
struct SearchResultsList: View {
    let results: [SearchResult]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(results) { result in
                    SearchResultCard(result: result)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let result: SearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: result.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
            }
            .frame(width: 120, height: 68)
            .cornerRadius(AppTheme.CornerRadius.sm)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(result.subtitle)
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(result.metadata)
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

// MARK: - Supporting Models
enum SearchScope: String, CaseIterable {
    case all = "all"
    case videos = "videos"
    case creators = "creators"
    case playlists = "playlists"
    case live = "live"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .videos: return "Videos"
        case .creators: return "Creators"
        case .playlists: return "Playlists"
        case .live: return "Live"
        }
    }
}

struct SearchResult: Identifiable {
    let id: String = UUID().uuidString
    let title: String
    let subtitle: String
    let metadata: String
    let thumbnailURL: String
    let type: SearchResultType
    
    enum SearchResultType {
        case video, creator, playlist, liveStream
    }
    
    static func mockResults(for query: String, scope: SearchScope) -> [SearchResult] {
        return [
            SearchResult(
                title: "\(query) Tutorial - Complete Guide",
                subtitle: "Tech Creator",
                metadata: "1.2M views • 2 days ago",
                thumbnailURL: "https://picsum.photos/400/225?random=1",
                type: .video
            ),
            SearchResult(
                title: "Advanced \(query) Techniques",
                subtitle: "Creative Artist",
                metadata: "856K views • 1 week ago",
                thumbnailURL: "https://picsum.photos/400/225?random=2",
                type: .video
            ),
            SearchResult(
                title: "\(query) Master Class",
                subtitle: "Gaming Pro",
                metadata: "2.1M subscribers",
                thumbnailURL: "https://picsum.photos/400/225?random=3",
                type: .creator
            )
        ]
    }
}

#Preview {
    SearchView()
}