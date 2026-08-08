// ⚡ PERFORMANCE: Extracted from SearchView.swift — independent compilation unit.
// AI search, result cards, voice search compile in parallel with the 632-line main SearchView.
import SwiftUI

// MARK: - Conversational AI View
struct ConversationalAIView: View {
    let query: String
    let aiResult: SearchV3Result?
    let isThinking: Bool
    var conversationHistory: [ConversationalSearchService.HistoryTurn] = []
    let onFollowUp: (String) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {

                // Prior conversation turns
                ForEach(conversationHistory) { turn in
                    // User bubble
                    HStack {
                        Spacer()
                        Text(turn.userText)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(AppTheme.Colors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal)
                    }
                    // Assistant bubble
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                            .font(.system(size: 18))
                            .padding(.top, 4)
                        Text(turn.assistantText)
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(12)
                            .background(AppTheme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // Current query bubble
                HStack {
                    Spacer()
                    Text(query)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal)
                }

                // AI Response
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 20))
                        .padding(.top, 4)

                    if isThinking {
                        HStack(spacing: 4) {
                            Circle().fill(Color.purple).frame(width: 8, height: 8)
                                .scaleEffect(isThinking ? 1 : 0.5)
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: isThinking)
                            Circle().fill(Color.purple).frame(width: 8, height: 8)
                                .scaleEffect(isThinking ? 1 : 0.5)
                                .animation(.easeInOut(duration: 0.5).repeatForever().delay(0.2), value: isThinking)
                            Circle().fill(Color.purple).frame(width: 8, height: 8)
                                .scaleEffect(isThinking ? 1 : 0.5)
                                .animation(.easeInOut(duration: 0.5).repeatForever().delay(0.4), value: isThinking)
                        }
                        .padding(12)
                        .background(AppTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else if let result = aiResult, let card = result.answerCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(card.summary)
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.textPrimary)

                            if !card.citations.isEmpty {
                                Divider()
                                Text("Sources:")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                ForEach(card.citations) { citation in
                                    HStack {
                                        Image(systemName: "play.rectangle.fill")
                                        Text(citation.title)
                                            .lineLimit(1)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                }
                            }

                            if !result.followUpSuggestions.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(result.followUpSuggestions, id: \.self) { suggestion in
                                            Button(action: { onFollowUp(suggestion) }) {
                                                Text(suggestion)
                                                    .font(.caption)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.purple.opacity(0.1))
                                                    .foregroundColor(.purple)
                                                    .cornerRadius(12)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(12)
                        .background(AppTheme.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

// MARK: - Supporting Views and Models (unchanged)
struct LegacySearchEmptyState: View {
    let recentSearches: [String]
    let onSearchTap: (String) -> Void
    @StateObject private var trendingService = TrendingSearchService.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Recent Searches
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Searches")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        VStack(spacing: 12) {
                            ForEach(recentSearches.prefix(5), id: \.self) { search in
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
                }
                
                // Trending Searches (Real-time)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Trending Searches")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Spacer()
                        
                        // Live indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .opacity(trendingService.isLoading ? 0.5 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: trendingService.isLoading)
                            
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(trendingService.trendingSearches) { trend in
                            Button(action: { onSearchTap(trend.term) }) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .font(.caption)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(trend.term)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                            .lineLimit(1)
                                        
                                        Text("\(trend.searchCount) searches")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.Colors.textTertiary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppTheme.Colors.surface)
                                .cornerRadius(AppTheme.CornerRadius.sm)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct LegacySearchLoadingState: View {
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

struct LegacySearchResultsList: View {
    let results: [SearchResult]
    let searchCorrection: String?
    let relatedSearches: [String]
    let isLoadingMore: Bool
    let onCorrectionTap: (String) -> Void
    let onRelatedTap: (String) -> Void
    let onLoadMore: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Search Correction (if no results)
                if results.isEmpty && searchCorrection != nil {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        Text("No results found")
                            .font(AppTheme.Typography.headline)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        if let correction = searchCorrection {
                            VStack(spacing: 12) {
                                Text("Did you mean:")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                
                                Button(action: { onCorrectionTap(correction) }) {
                                    Text(correction)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.primary)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(
                                            Capsule()
                                                .fill(AppTheme.Colors.primary.opacity(0.1))
                                        )
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.top, 60)
                    .padding(.horizontal)
                }
                
                // Search Results
                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                    ModernSearchResultCard(result: result)
                        .padding(.horizontal)
                        .onAppear {
                            // Infinite scroll - load more when near end
                            if index == results.count - 3 {
                                onLoadMore()
                            }
                        }
                }
                
                // Loading More Indicator
                if isLoadingMore {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                        
                        Text("Loading more results...")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .padding(.vertical, 20)
                }
                
                // Related Searches (at bottom)
                if !relatedSearches.isEmpty && !results.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()
                            .padding(.vertical, 8)
                        
                        Text("Related Searches")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(relatedSearches, id: \.self) { related in
                                Button(action: { onRelatedTap(related) }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.Colors.primary)
                                        
                                        Text(related)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                            .lineLimit(1)
                                        
                                        Spacer()
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
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .padding(.vertical)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

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
    @EnvironmentObject private var appState: AppState
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail with poster candidates support
            ZStack(alignment: .bottomTrailing) {
                SearchVideoThumbnail(video: videoResult.video)
                    .frame(width: 120, height: 68)
                    .cornerRadius(AppTheme.CornerRadius.sm)
                    .clipped()
                
                // Duration badge
                Text(videoResult.video.formattedDuration)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.8))
                    .cornerRadius(3)
                    .padding(4)
            }
            
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
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .medium)
            // 🔥 Navigate to video player
            GlobalVideoPlayerManager.shared.playVideo(videoResult.video, showFullscreen: true)
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }) { }
        .accessibilityLabel("Video: \(videoResult.video.title) by \(videoResult.video.creator.displayName)")
        .accessibilityHint("Double tap to play")
    }
}

// MARK: - Search Video Thumbnail (Handles poster candidates)
private struct SearchVideoThumbnail: View {
    let video: Video
    @State private var currentIndex = 0
    
    private var thumbnailURLs: [URL] {
        // Try poster candidates first, then fall back to thumbnailURL
        var urls = video.posterCandidates
        if urls.isEmpty, let url = URL(string: video.thumbnailURL) {
            urls = [url]
        }
        return urls
    }
    
    var body: some View {
        if thumbnailURLs.isEmpty {
            placeholder
        } else {
            AsyncImage(url: thumbnailURLs[currentIndex]) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    if currentIndex < thumbnailURLs.count - 1 {
                        Color.clear.onAppear { currentIndex += 1 }
                    } else {
                        placeholder
                    }
                case .empty:
                    shimmer
                @unknown default:
                    placeholder
                }
            }
        }
    }
    
    private var placeholder: some View {
        Rectangle()
            .fill(AppTheme.Colors.surface)
            .overlay(
                Image(systemName: "play.rectangle.fill")
                    .foregroundColor(AppTheme.Colors.textTertiary)
            )
    }
    
    private var shimmer: some View {
        Rectangle()
            .fill(AppTheme.Colors.surface)
            .overlay(
                ProgressView()
                    .tint(AppTheme.Colors.textTertiary)
            )
    }
}

struct CreatorSearchCard: View {
    let creatorResult: CreatorSearchResult
    @EnvironmentObject private var appState: AppState
    @State private var isPressed = false
    @State private var showingProfile = false
    @State private var isSubscribed = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            AsyncImage(url: URL(string: creatorResult.creator.profileImageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        Text(creatorResult.creator.displayName.prefix(1).uppercased())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                // Verified badge if creator is verified
                Group {
                    if creatorResult.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white, AppTheme.Colors.primary)
                            .offset(x: 20, y: 20)
                    }
                }
            )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(creatorResult.creator.displayName)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if creatorResult.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
                
                Text("@\(creatorResult.creator.username)")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 4) {
                    Text(formatSubscriberCount(creatorResult.creator.subscriberCount))
                    Text("subscribers")
                    
                    if creatorResult.creator.videoCount > 0 {
                        Text("•")
                        Text("\(creatorResult.creator.videoCount) videos")
                    }
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
                
                if let bio = creatorResult.creator.bio, !bio.isEmpty {
                    Text(bio)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Subscribe Button
            Button {
                HapticManager.shared.impact(style: .medium)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isSubscribed.toggle()
                }
                appState.toggleSubscription(for: creatorResult.creator.id)
            } label: {
                Text(isSubscribed ? "Subscribed" : "Subscribe")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isSubscribed ? AppTheme.Colors.surface : AppTheme.Colors.primary)
                    .foregroundColor(isSubscribed ? AppTheme.Colors.textPrimary : .white)
                    .cornerRadius(AppTheme.CornerRadius.sm)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
            // 🔥 Navigate to creator's public profile
            showingProfile = true
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }) { }
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                PublicProfileView(user: creatorResult.creator)
            }
        }
        .onAppear {
            isSubscribed = appState.isSubscribedTo(creatorResult.creator.id)
        }
        .accessibilityLabel("Channel: \(creatorResult.creator.displayName)")
        .accessibilityHint("Double tap to view channel")
    }
    
    private func formatSubscriberCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
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
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
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
                    Rectangle().fill(AppTheme.Colors.surface)
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
                    Circle().fill(Color.red).frame(width: 8, height: 8)
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
        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Helper Methods
func convertToAdvancedFilters(_ filters: SearchFilters) -> AdvancedSearchFilters {
    var advancedFilters = AdvancedSearchFilters()
    
    // Map upload date via rawValue
    if let uploadDate = filters.uploadDate,
       let mapped = AdvancedSearchFilters.UploadDateFilter(rawValue: uploadDate.rawValue) {
        advancedFilters.uploadDate = mapped
    }
    
    // Map duration via rawValue
    if let duration = filters.duration,
       let mapped = AdvancedSearchFilters.DurationFilter(rawValue: duration.rawValue) {
        advancedFilters.duration = mapped
    }
    
    // Map content type via rawValue
    if let contentType = filters.contentType,
       let mapped = AdvancedSearchFilters.ContentType(rawValue: contentType.rawValue) {
        advancedFilters.contentType = mapped
    }
    
    // Map features via rawValue
    advancedFilters.features = Set(filters.features.compactMap {
        AdvancedSearchFilters.FeatureFilter(rawValue: $0.rawValue)
    })
    
    return advancedFilters
}

// SearchFiltersView is now defined in its own file

// MARK: - Supporting Models
enum SearchScope: String, CaseIterable {
    case all = "all"
    case videos = "videos"
    case creators = "creators"
    case community = "community"
    case playlists = "playlists"
    case live = "live"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .videos: return "Videos"
        case .creators: return "Creators"
        case .community: return "Community"
        case .playlists: return "Playlists"
        case .live: return "Live"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "magnifyingglass"
        case .videos: return "play.rectangle"
        case .creators: return "person.circle"
        case .community: return "person.3"
        case .playlists: return "rectangle.stack"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
}

// MARK: - Voice Search Sheet
struct VoiceSearchSheet: View {
    @ObservedObject var voiceSearch: VoiceSearchService
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Animated waveform
                if voiceSearch.isListening {
                    WaveformView()
                        .frame(height: 80)
                        .padding(.horizontal, 40)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                
                // Status text
                Text(voiceSearch.isListening ? "Listening..." : "Tap to speak")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                // Transcribed text
                if !voiceSearch.transcribedText.isEmpty {
                    Text(voiceSearch.transcribedText)
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Error message
                if let error = voiceSearch.errorMessage {
                    Text(error)
                        .font(.system(size: 15))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Mic button
                Button(action: {
                    if voiceSearch.isListening {
                        voiceSearch.stopListening()
                        if !voiceSearch.transcribedText.isEmpty {
                            onComplete(voiceSearch.transcribedText)
                        }
                    } else {
                        Task {
                            try? await voiceSearch.startListening()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(voiceSearch.isListening ? Color.red : AppTheme.Colors.primary)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: voiceSearch.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Voice Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        voiceSearch.stopListening()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WaveformView: View {
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.3, count: 20)
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<amplitudes.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 4)
                    .frame(height: amplitudes[index] * 80)
                    .animation(
                        Animation.easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.05),
                        value: amplitudes[index]
                    )
            }
        }
        .onAppear {
            // Animate waveform
            for index in amplitudes.indices {
                amplitudes[index] = CGFloat.random(in: 0.3...1.0)
            }
        }
    }
}

// MARK: - Image Picker

#Preview {
    SearchView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}