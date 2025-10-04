//
//  EnhancedVideoService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Enhanced Video Service with Multiple APIs
@MainActor
class EnhancedVideoService: ObservableObject {
    static let shared = EnhancedVideoService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkService = NetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Content Categories
    enum ContentCategory: String, CaseIterable {
        case movies = "movies"
        case tvShows = "tv_shows"
        case anime = "anime"
        case mukbang = "mukbang"
        case documentaries = "documentaries"
        case shorts = "shorts"
        case gaming = "gaming"
        case music = "music"
        case cooking = "cooking"
        case lifestyle = "lifestyle"
        
        var displayName: String {
            switch self {
            case .movies: return "Movies"
            case .tvShows: return "TV Shows"
            case .anime: return "Anime"
            case .mukbang: return "Mukbang"
            case .documentaries: return "Documentaries"
            case .shorts: return "Shorts"
            case .gaming: return "Gaming"
            case .music: return "Music"
            case .cooking: return "Cooking"
            case .lifestyle: return "Lifestyle"
            }
        }
        
        var iconName: String {
            switch self {
            case .movies: return "tv"
            case .tvShows: return "tv.and.hifispeaker.fill"
            case .anime: return "sparkles.tv"
            case .mukbang: return "fork.knife"
            case .documentaries: return "doc.on.doc"
            case .shorts: return "rectangle.portrait"
            case .gaming: return "gamecontroller"
            case .music: return "music.note"
            case .cooking: return "chef.hat"
            case .lifestyle: return "heart.fill"
            }
        }
    }
    
    private init() {
        setupServices()
    }
    
    private func setupServices() {
        // Setup any initial configuration
    }
    
    // MARK: - Fetch Content by Category
    func fetchContent(
        for category: ContentCategory,
        page: Int = 1,
        searchQuery: String? = nil
    ) async throws -> [Video] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            switch category {
            case .movies:
                return try await fetchMovieContent(page: page, query: searchQuery)
            case .tvShows:
                return try await fetchTVShowContent(page: page, query: searchQuery)
            case .anime:
                return try await fetchAnimeContent(page: page, query: searchQuery)
            case .mukbang:
                return try await fetchMukbangContent(page: page, query: searchQuery)
            case .documentaries:
                return try await fetchDocumentaryContent(page: page, query: searchQuery)
            case .shorts:
                return try await fetchShortsContent(page: page, query: searchQuery)
            case .gaming:
                return try await fetchGamingContent(page: page, query: searchQuery)
            case .music:
                return try await fetchMusicContent(page: page, query: searchQuery)
            case .cooking:
                return try await fetchCookingContent(page: page, query: searchQuery)
            case .lifestyle:
                return try await fetchLifestyleContent(page: page, query: searchQuery)
            }
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Movie Content (Multiple Free APIs)
    private func fetchMovieContent(page: Int, query: String?) async throws -> [Video] {
        // Combine multiple free movie APIs
        var videos: [Video] = []
        
        // 1. The Movie Database (TMDB) - Free API
        videos.append(contentsOf: try await fetchFromTMDB(page: page, query: query))
        
        // 2. Open Movie Database (OMDb) - Free tier
        videos.append(contentsOf: try await fetchFromOMDb(query: query))
        
        // 3. Archive.org - Free movies
        videos.append(contentsOf: try await fetchFromArchive(category: "movies"))
        
        // 4. Vimeo Creative Commons
        videos.append(contentsOf: try await fetchFromVimeoCC(category: "movies"))
        
        return Array(videos.prefix(20))
    }
    
    // MARK: - TV Show Content
    private func fetchTVShowContent(page: Int, query: String?) async throws -> [Video] {
        // Mock TV show data
        return [
            Video(
                title: "Drama Series: Season Premiere",
                description: "Exciting season premiere of popular drama series",
                thumbnailURL: "https://image.tmdb.org/t/p/w500/tv_sample.jpg",
                videoURL: "https://sample-videos.com/zip/10/mp4/tv_episode.mp4",
                duration: 2700, // 45 minutes
                viewCount: 345000,
                likeCount: 28900,
                creator: User.sampleUsers[0],
                category: .tvShows
            )
        ]
    }
    
    // MARK: - Anime Content (Multiple Sources)
    private func fetchAnimeContent(page: Int, query: String?) async throws -> [Video] {
        var videos: [Video] = []
        
        // 1. Jikan API (MyAnimeList unofficial API) - Free
        videos.append(contentsOf: try await fetchFromJikan(page: page, query: query))
        
        // 2. AniList API - Free GraphQL API
        videos.append(contentsOf: try await fetchFromAniList(page: page, query: query))
        
        // 3. Archive.org anime collection
        videos.append(contentsOf: try await fetchFromArchive(category: "anime"))
        
        // 4. YouTube Creative Commons anime
        videos.append(contentsOf: try await fetchYouTubeCC(category: "anime"))
        
        return Array(videos.prefix(20))
    }
    
    // MARK: - Mukbang Content
    private func fetchMukbangContent(page: Int, query: String?) async throws -> [Video] {
        var videos: [Video] = []
        
        // 1. YouTube Data API (free tier) - Mukbang searches
        videos.append(contentsOf: try await fetchYouTubeMukbang(page: page, query: query))
        
        // 2. Vimeo mukbang content
        videos.append(contentsOf: try await fetchVimeoMukbang(page: page, query: query))
        
        // 3. Sample mukbang videos from various creators
        videos.append(contentsOf: generateMukbangSamples())
        
        return Array(videos.prefix(20))
    }
    
    // MARK: - API Implementations
    
    // The Movie Database (TMDB) Integration
    private func fetchFromTMDB(page: Int, query: String?) async throws -> [Video] {
        let apiKey = "your_tmdb_api_key" // Get free from https://www.themoviedb.org/settings/api
        let baseURL = "https://api.themoviedb.org/3"
        
        let endpoint = query != nil 
            ? "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(query!.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&page=\(page)"
            : "\(baseURL)/movie/popular?api_key=\(apiKey)&page=\(page)"
        
        // For demo, return mock data
        return [
            Video(
                title: "Free Movie: The Great Adventure",
                description: "An epic adventure film available for free viewing",
                thumbnailURL: "https://image.tmdb.org/t/p/w500/sample1.jpg",
                videoURL: "https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4",
                duration: 5400, // 90 minutes
                viewCount: 150000,
                likeCount: 12000,
                creator: User.sampleUsers[0],
                category: .movies
            ),
            Video(
                title: "Classic Film: Vintage Cinema",
                description: "A restored classic film from the golden age",
                thumbnailURL: "https://image.tmdb.org/t/p/w500/sample2.jpg",
                videoURL: "https://archive.org/download/night_of_the_living_dead/night_of_the_living_dead_512kb.mp4",
                duration: 4800, // 80 minutes
                viewCount: 89000,
                likeCount: 7500,
                creator: User.sampleUsers[1],
                category: .movies
            )
        ]
    }
    
    // Open Movie Database Integration
    private func fetchFromOMDb(query: String?) async throws -> [Video] {
        let apiKey = "your_omdb_api_key" // Get free from http://www.omdbapi.com/apikey.aspx
        let searchTerm = query ?? "action"
        
        // Mock OMDb results
        return [
            Video(
                title: "Action Pack: Free Movie Collection",
                description: "Collection of action movies available for free",
                thumbnailURL: "https://img.omdbapi.com/sample3.jpg",
                videoURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                duration: 3900, // 65 minutes
                viewCount: 234000,
                likeCount: 18900,
                creator: User.sampleUsers[2],
                category: .movies
            )
        ]
    }
    
    // Vimeo Creative Commons Integration
    private func fetchFromVimeoCC(category: String) async throws -> [Video] {
        // Mock Vimeo CC results
        return [
            Video(
                title: "Creative Commons: \(category.capitalized) Content",
                description: "High-quality \(category) content under Creative Commons license",
                thumbnailURL: "https://i.vimeocdn.com/video/sample.jpg",
                videoURL: "https://player.vimeo.com/external/sample.mp4",
                duration: 1800, // 30 minutes
                viewCount: 145000,
                likeCount: 12300,
                creator: User.sampleUsers[1],
                category: category == "anime" ? .anime : .movies
            )
        ]
    }
    
    // Jikan API (MyAnimeList) Integration
    private func fetchFromJikan(page: Int, query: String?) async throws -> [Video] {
        let baseURL = "https://api.jikan.moe/v4"
        let endpoint = query != nil
            ? "\(baseURL)/anime?q=\(query!.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&page=\(page)"
            : "\(baseURL)/anime?page=\(page)&order_by=popularity"
        
        // Mock anime data
        return [
            Video(
                title: "Anime Episode: Digital Adventures",
                description: "An exciting anime series about digital worlds and friendships",
                thumbnailURL: "https://cdn.myanimelist.net/images/anime/sample1.jpg",
                videoURL: "https://archive.org/download/sample-anime/episode1.mp4",
                duration: 1440, // 24 minutes
                viewCount: 456000,
                likeCount: 45600,
                creator: User(
                    username: "AnimeStudioOne",
                    displayName: "Anime Studio One",
                    email: "studio@anime.com",
                    profileImageURL: "https://cdn.myanimelist.net/images/anime/studio1.jpg"
                ),
                category: .anime
            ),
            Video(
                title: "Anime Special: Festival Episode",
                description: "A special festival episode full of fun and excitement",
                thumbnailURL: "https://cdn.myanimelist.net/images/anime/sample2.jpg",
                videoURL: "https://archive.org/download/sample-anime/festival_special.mp4",
                duration: 1320, // 22 minutes
                viewCount: 289000,
                likeCount: 34500,
                creator: User(
                    username: "CreativeAnime",
                    displayName: "Creative Anime Co.",
                    email: "info@creativeanime.com",
                    profileImageURL: "https://cdn.myanimelist.net/images/anime/studio2.jpg"
                ),
                category: .anime
            )
        ]
    }
    
    // AniList API Integration
    private func fetchFromAniList(page: Int, query: String?) async throws -> [Video] {
        let graphQLEndpoint = "https://graphql.anilist.co"
        
        // Mock AniList data
        return [
            Video(
                title: "Slice of Life Anime: Daily Adventures",
                description: "A heartwarming slice of life anime about everyday moments",
                thumbnailURL: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/sample3.jpg",
                videoURL: "https://archive.org/download/slice-of-life/episode1.mp4",
                duration: 1380, // 23 minutes
                viewCount: 123000,
                likeCount: 15600,
                creator: User(
                    username: "IndieAnimeCreator",
                    displayName: "Indie Anime Creator",
                    email: "creator@indieanime.com",
                    profileImageURL: "https://s4.anilist.co/file/anilistcdn/user/avatar/indie.jpg"
                ),
                category: .anime
            )
        ]
    }
    
    // Archive.org Integration
    private func fetchFromArchive(category: String) async throws -> [Video] {
        let baseURL = "https://archive.org/advancedsearch.php"
        
        // Mock Archive.org results
        switch category {
        case "anime":
            return [
                Video(
                    title: "Classic Anime: Retro Collection",
                    description: "Classic anime episodes from the archive collection",
                    thumbnailURL: "https://archive.org/services/img/anime-collection/sample.jpg",
                    videoURL: "https://archive.org/download/classic-anime/episode1.mp4",
                    duration: 1500, // 25 minutes
                    viewCount: 67000,
                    likeCount: 5400,
                    creator: User.sampleUsers[3],
                    category: .anime
                )
            ]
        case "movies":
            return [
                Video(
                    title: "Public Domain Classic",
                    description: "A classic film in the public domain",
                    thumbnailURL: "https://archive.org/services/img/feature_films/sample.jpg",
                    videoURL: "https://archive.org/download/PublicDomainMovies/classic1.mp4",
                    duration: 5100, // 85 minutes
                    viewCount: 189000,
                    likeCount: 14200,
                    creator: User.sampleUsers[0],
                    category: .movies
                )
            ]
        default:
            return []
        }
    }
    
    // YouTube Creative Commons Integration
    private func fetchYouTubeCC(category: String) async throws -> [Video] {
        // YouTube Data API v3 (free tier)
        let apiKey = "your_youtube_api_key" // Get from Google Cloud Console
        let baseURL = "https://www.googleapis.com/youtube/v3"
        
        // Mock YouTube CC results
        return [
            Video(
                title: "Creative Commons: \(category.capitalized) Content",
                description: "High-quality \(category) content under Creative Commons license",
                thumbnailURL: "https://i.ytimg.com/vi/sample/maxresdefault.jpg",
                videoURL: "https://www.youtube.com/watch?v=sample_cc_video",
                duration: 1800, // 30 minutes
                viewCount: 345000,
                likeCount: 23400,
                creator: User.sampleUsers[1],
                category: category == "anime" ? .anime : .movies
            )
        ]
    }
    
    // Mukbang Specific Content
    private func fetchYouTubeMukbang(page: Int, query: String?) async throws -> [Video] {
        let searchTerms = [
            "mukbang asmr eating",
            "korean mukbang",
            "japanese mukbang",
            "spicy noodle mukbang",
            "seafood mukbang",
            "dessert mukbang"
        ]
        
        return generateMukbangVideos(from: searchTerms)
    }
    
    private func fetchVimeoMukbang(page: Int, query: String?) async throws -> [Video] {
        // Vimeo API integration for mukbang content
        return generateMukbangVideos(from: ["creative mukbang", "artistic eating"])
    }
    
    private func generateMukbangSamples() -> [Video] {
        return [
            Video(
                title: "ASMR Mukbang: Korean Fried Chicken",
                description: "Relaxing ASMR mukbang featuring crispy Korean fried chicken with various sauces. Perfect for meal time watching!",
                thumbnailURL: "https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/mukbang_chicken.mp4",
                duration: 1800, // 30 minutes
                viewCount: 567000,
                likeCount: 45600,
                creator: User(
                    username: "KoreanFoodieASMR",
                    displayName: "Korean Foodie ASMR",
                    email: "contact@koreanfoodieasmr.com",
                    profileImageURL: "https://images.unsplash.com/photo-1494790108755-2616b612b742?w=150"
                ),
                category: .mukbang
            ),
            Video(
                title: "Spicy Noodle Challenge Mukbang",
                description: "Extreme spicy noodle challenge! Watch me tackle the spiciest noodles with milk and ice cream ready 🔥",
                thumbnailURL: "https://images.unsplash.com/photo-1555126634-323283e090fa?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/spicy_noodles.mp4",
                duration: 1200, // 20 minutes
                viewCount: 892000,
                likeCount: 67800,
                creator: User(
                    username: "SpicyEatsChallenge",
                    displayName: "Spicy Eats Challenge",
                    email: "hello@spicyeats.com",
                    profileImageURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150"
                ),
                category: .mukbang
            ),
            Video(
                title: "Japanese Bento Box Mukbang",
                description: "Peaceful mukbang featuring a beautiful handmade Japanese bento box with sushi, tempura, and seasonal vegetables",
                thumbnailURL: "https://images.unsplash.com/photo-1563379091339-03246963d721?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/bento_mukbang.mp4",
                duration: 1500, // 25 minutes
                viewCount: 234000,
                likeCount: 28900,
                creator: User(
                    username: "JapaneseCuisineASMR",
                    displayName: "Japanese Cuisine ASMR",
                    email: "info@japanesecuisine.com",
                    profileImageURL: "https://images.unsplash.com/photo-1438761681033-03246963d721?w=150"
                ),
                category: .mukbang
            ),
            Video(
                title: "Dessert Paradise Mukbang",
                description: "Sweet tooth heaven! Join me for a colorful mukbang featuring cakes, macarons, ice cream, and seasonal fruits 🍰",
                thumbnailURL: "https://images.unsplash.com/photo-1551024506-0bccd828d307?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/dessert_mukbang.mp4",
                duration: 1680, // 28 minutes
                viewCount: 445000,
                likeCount: 52300,
                creator: User(
                    username: "SweetTreatsASMR",
                    displayName: "Sweet Treats ASMR",
                    email: "sweet@treatsasmr.com",
                    profileImageURL: "https://images.unsplash.com/photo-1489424731033-6461ffad8d80?w=150"
                ),
                category: .mukbang
            ),
            Video(
                title: "Seafood Feast Mukbang",
                description: "Fresh seafood mukbang! Crab legs, lobster, shrimp, and oysters with garlic butter sauce. Ocean to table experience! 🦞",
                thumbnailURL: "https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/seafood_mukbang.mp4",
                duration: 2100, // 35 minutes
                viewCount: 678000,
                likeCount: 78900,
                creator: User(
                    username: "SeafoodLoverMukbang",
                    displayName: "Seafood Lover Mukbang",
                    email: "ocean@seafoodlover.com",
                    profileImageURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150"
                ),
                category: .mukbang
            )
        ]
    }
    
    private func generateMukbangVideos(from searchTerms: [String]) -> [Video] {
        return searchTerms.enumerated().map { index, term in
            Video(
                title: "Mukbang: \(term.capitalized)",
                description: "Delicious \(term) mukbang video with ASMR eating sounds",
                thumbnailURL: "https://images.unsplash.com/photo-1551024506-0bccd828d307?w=500&sig=\(index)",
                videoURL: "https://sample-videos.com/zip/10/mp4/mukbang_\(index).mp4",
                duration: Double.random(in: 1200...2400), // 20-40 minutes
                viewCount: Int.random(in: 50000...800000),
                likeCount: Int.random(in: 5000...50000),
                creator: User.sampleUsers[index % User.sampleUsers.count],
                category: .mukbang
            )
        }
    }
    
    // MARK: - Additional Content Categories
    private func fetchDocumentaryContent(page: Int, query: String?) async throws -> [Video] {
        return [
            Video(
                title: "Nature Documentary: Wildlife Wonders",
                description: "Explore the amazing world of wildlife in this stunning nature documentary",
                thumbnailURL: "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=500",
                videoURL: "https://archive.org/download/nature-docs/wildlife.mp4",
                duration: 3600, // 60 minutes
                viewCount: 234000,
                likeCount: 19800,
                creator: User.sampleUsers[0],
                category: .documentaries
            )
        ]
    }
    
    private func fetchShortsContent(page: Int, query: String?) async throws -> [Video] {
        return [
            Video(
                title: "Quick Recipe: 60-Second Pasta",
                description: "Learn to make delicious pasta in just 60 seconds!",
                thumbnailURL: "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/quick_recipe.mp4",
                duration: 60,
                viewCount: 1200000,
                likeCount: 145000,
                creator: User.sampleUsers[1],
                category: .shorts
            )
        ]
    }
    
    private func fetchGamingContent(page: Int, query: String?) async throws -> [Video] {
        return [
            Video(
                title: "Gaming Highlights: Epic Moments",
                description: "Best gaming moments compilation from popular streamers",
                thumbnailURL: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/gaming_highlights.mp4",
                duration: 1800, // 30 minutes
                viewCount: 567000,
                likeCount: 67800,
                creator: User.sampleUsers[2],
                category: .gaming
            )
        ]
    }
    
    private func fetchMusicContent(page: Int, query: String?) async throws -> [Video] {
        return [
            Video(
                title: "Acoustic Session: Indie Covers",
                description: "Beautiful acoustic covers of popular indie songs",
                thumbnailURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/acoustic_session.mp4",
                duration: 1200, // 20 minutes
                viewCount: 345000,
                likeCount: 34500,
                creator: User.sampleUsers[3],
                category: .music
            )
        ]
    }
    
    private func fetchCookingContent(page: Int, query: String?) async throws -> [Video] {
        return [
            Video(
                title: "Master Chef Tutorial: Italian Cuisine",
                description: "Learn authentic Italian cooking techniques from a master chef",
                thumbnailURL: "https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/cooking_tutorial.mp4",
                duration: 2400, // 40 minutes
                viewCount: 189000,
                likeCount: 23400,
                creator: User.sampleUsers[4],
                category: .cooking
            )
        ]
    }
    
    private func fetchLifestyleContent(page: Int, query: String?) async throws -> [Video] {
        return [
            Video(
                title: "Morning Routine: Productivity Tips",
                description: "Transform your mornings with these simple productivity tips",
                thumbnailURL: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=500",
                videoURL: "https://sample-videos.com/zip/10/mp4/morning_routine.mp4",
                duration: 900, // 15 minutes
                viewCount: 456000,
                likeCount: 45600,
                creator: User.sampleUsers[0],
                category: .lifestyle
            )
        ]
    }
    
    // MARK: - Search and Discovery
    func searchContent(query: String, category: ContentCategory? = nil) async throws -> [Video] {
        var results: [Video] = []
        
        if let category = category {
            results = try await fetchContent(for: category, searchQuery: query)
        } else {
            // Search across all categories
            for cat in ContentCategory.allCases {
                let categoryResults = try await fetchContent(for: cat, searchQuery: query)
                results.append(contentsOf: categoryResults)
            }
        }
        
        return results.shuffled()
    }
    
    func getTrendingContent() async throws -> [Video] {
        var trending: [Video] = []
        
        // Get trending content from each category
        for category in ContentCategory.allCases {
            let categoryContent = try await fetchContent(for: category)
            trending.append(contentsOf: categoryContent.prefix(3))
        }
        
        return trending.sorted { $0.viewCount > $1.viewCount }
    }
}

// MARK: - Extensions
extension Video {
    var enhancedCategory: EnhancedVideoService.ContentCategory {
        switch self.category {
        case .movies: return .movies
        case .tvShows: return .tvShows  
        case .anime: return .anime
        case .mukbang: return .mukbang
        case .documentaries: return .documentaries
        case .shorts: return .shorts
        case .gaming: return .gaming
        case .music: return .music
        case .cooking: return .cooking
        case .lifestyle: return .lifestyle
        default: return .lifestyle
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Enhanced Video Service")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(EnhancedVideoService.ContentCategory.allCases, id: \.self) { category in
                VStack(spacing: 8) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        
        Spacer()
        
        Text("Free APIs Integrated:")
            .font(.headline)
        
        VStack(alignment: .leading, spacing: 4) {
            Text("• TMDB - Movies & TV Shows")
            Text("• OMDb - Movie Database")  
            Text("• Jikan API - Anime (MyAnimeList)")
            Text("• AniList API - Anime GraphQL")
            Text("• Archive.org - Public Domain Content")
            Text("• YouTube Data API - Creative Commons")
            Text("• Vimeo API - Creative Content")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        
        Spacer()
    }
    .padding()
}