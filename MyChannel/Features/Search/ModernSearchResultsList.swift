//
//  ModernSearchResultsList.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import SwiftUI

// 🔥 YouTube-Parity Search Results View
// Supports list/grid view modes with search corrections and related searches
struct ModernSearchResultsList: View {
    let results: [SearchResult]
    let searchCorrection: String?
    let relatedSearches: [String]
    let isLoadingMore: Bool
    let onCorrectionTap: (String) -> Void
    let onRelatedTap: (String) -> Void
    let onLoadMore: () -> Void
    
    @State private var viewMode: ViewMode = .list
    @State private var showingViewOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // View Mode Selector
            HStack {
                Text("\(results.count) results")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    showingViewOptions.toggle()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewMode.iconName)
                            .font(.system(size: 14))
                        
                        Text(viewMode.displayName)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Search Correction
                    if let correction = searchCorrection {
                        SearchCorrectionView(
                            correction: correction,
                            onTap: { onCorrectionTap(correction) }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    
                    // Search Results
                    if viewMode == .list {
                        ForEach(results.indices, id: \.self) { index in
                            SearchResultListRow(result: results[index])
                                .onAppear {
                                    if index == results.count - 3 {
                                        onLoadMore()
                                    }
                                }
                        }
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 16) {
                            ForEach(results.indices, id: \.self) { index in
                                SearchResultGridCard(result: results[index])
                                    .onAppear {
                                        if index == results.count - 3 {
                                            onLoadMore()
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Loading More Indicator
                    if isLoadingMore {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            
                            Text("Loading more...")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        .padding(.vertical, 20)
                    }
                    
                    // Related Searches
                    if !relatedSearches.isEmpty {
                        RelatedSearchesView(
                            searches: relatedSearches,
                            onTap: onRelatedTap
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    }
                }
            }
        }
        .actionSheet(isPresented: $showingViewOptions) {
            ActionSheet(
                title: Text("View Options"),
                buttons: [
                    .default(Text("List View")) {
                        viewMode = .list
                    },
                    .default(Text("Grid View")) {
                        viewMode = .grid
                    },
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - View Mode
enum ViewMode: String, CaseIterable {
    case list = "list"
    case grid = "grid"
    
    var displayName: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        }
    }
    
    var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

// MARK: - Search Correction View
private struct SearchCorrectionView: View {
    let correction: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Did you mean:")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text(correction)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.primary.opacity(0.1))
            .cornerRadius(AppTheme.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Result List Row
private struct SearchResultListRow: View {
    let result: SearchResult
    
    var body: some View {
        switch result {
        case .video(let videoResult):
            VideoSearchResultRow(result: videoResult)
        case .creator(let creatorResult):
            CreatorSearchResultRow(result: creatorResult)
        case .playlist(let playlistResult):
            PlaylistSearchResultRow(result: playlistResult)
        case .liveStream(let liveResult):
            LiveStreamSearchResultRow(result: liveResult)
        }
    }
}

// MARK: - Search Result Grid Card
private struct SearchResultGridCard: View {
    let result: SearchResult
    
    var body: some View {
        switch result {
        case .video(let videoResult):
            VideoSearchResultCard(result: videoResult)
        case .creator(let creatorResult):
            CreatorSearchResultCard(result: creatorResult)
        case .playlist(let playlistResult):
            PlaylistSearchResultCard(result: playlistResult)
        case .liveStream(let liveResult):
            LiveStreamSearchResultCard(result: liveResult)
        }
    }
}

// MARK: - Video Search Result Row
private struct VideoSearchResultRow: View {
    let result: VideoSearchResult
    
    var body: some View {
        NavigationLink(destination: VideoPlayerView(video: result.video)) {
            HStack(spacing: 12) {
                // Thumbnail
                AsyncImage(url: URL(string: result.video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "play.rectangle")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .frame(width: 120, height: 68)
                .cornerRadius(AppTheme.CornerRadius.sm)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.video.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(result.video.creator.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    HStack(spacing: 8) {
                        Text("\(result.video.viewCount.formatted()) views")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text(result.video.createdAt.timeAgoDisplay)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                    
                    // Relevance indicator
                    HStack(spacing: 4) {
                        Text("Match:")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("\(Int(result.relevanceScore * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Video Search Result Card
private struct VideoSearchResultCard: View {
    let result: VideoSearchResult
    
    var body: some View {
        NavigationLink(destination: VideoPlayerView(video: result.video)) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                AsyncImage(url: URL(string: result.video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "play.rectangle")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .cornerRadius(AppTheme.CornerRadius.sm)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.video.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(result.video.creator.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("\(result.video.viewCount.formatted()) views")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Creator Search Result Row
private struct CreatorSearchResultRow: View {
    let result: CreatorSearchResult
    
    var body: some View {
        NavigationLink(destination: ProfileView()) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: result.creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "person.circle")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.creator.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("@\(result.creator.username)")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    Text("\(result.creator.subscriberCount.formatted()) subscribers")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                Spacer()
                
                // Subscribe button
                Button("Subscribe") {
                    HapticManager.shared.impact(style: .light)
                    // Handle subscribe
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.Colors.primary)
                .cornerRadius(AppTheme.CornerRadius.sm)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Creator Search Result Card
private struct CreatorSearchResultCard: View {
    let result: CreatorSearchResult
    
    var body: some View {
        NavigationLink(destination: ProfileView()) {
            VStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: result.creator.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "person.circle")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                // Content
                VStack(spacing: 4) {
                    Text(result.creator.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(result.creator.subscriberCount.formatted()) subs")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Playlist Search Result Row
private struct PlaylistSearchResultRow: View {
    let result: PlaylistSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail stack
            ZStack {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 120, height: 68)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(result.playlist.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("Playlist")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("\(result.playlist.videoCount) videos")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Playlist Search Result Card
private struct PlaylistSearchResultCard: View {
    let result: PlaylistSearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(result.playlist.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(result.playlist.videoCount) videos")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
    }
}

// MARK: - Live Stream Search Result Row
private struct LiveStreamSearchResultRow: View {
    let result: LiveStreamSearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with live indicator
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: result.video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .frame(width: 120, height: 68)
                .cornerRadius(AppTheme.CornerRadius.sm)
                
                // Live badge
                Text("LIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.red)
                    .cornerRadius(4)
                    .offset(x: 8, y: 8)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(result.video.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text(result.video.creator.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text("\(result.viewerCount) watching")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Live Stream Search Result Card
private struct LiveStreamSearchResultCard: View {
    let result: LiveStreamSearchResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with live indicator
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: result.video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                        .overlay(
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        )
                }
                .cornerRadius(AppTheme.CornerRadius.sm)
                
                // Live badge
                Text("LIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.red)
                    .cornerRadius(2)
                    .offset(x: 6, y: 6)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(result.video.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text("\(result.viewerCount) watching")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Related Searches View
private struct RelatedSearchesView: View {
    let searches: [String]
    let onTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Related Searches")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            LazyVStack(spacing: 8) {
                ForEach(searches, id: \.self) { search in
                    Button(action: { onTap(search) }) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .frame(width: 20)
                            
                            Text(search)
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(AppTheme.CornerRadius.md)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

#Preview {
    ModernSearchResultsList(
        results: [],
        searchCorrection: "iPhone review",
        relatedSearches: ["iPhone 15", "iPhone vs Android", "Best phone 2024"],
        isLoadingMore: false,
        onCorrectionTap: { _ in },
        onRelatedTap: { _ in },
        onLoadMore: {}
    )
}
