//
//  FeaturedArtistService.swift
//  MyChannel
//
//  🔥🎵 FLINT ARTISTS SERVICE - 810 REPRESENT! 🎵🔥
//  Local artist database and discovery system
//  - Firestore-backed artist profiles
//  - Verified artist badges
//  - Priority placement in music hub
//  - Direct artist support and tips
//

import Foundation
import SwiftUI
import Combine
import MusicKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Flint Artist Model

struct FeaturedArtist: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var stageName: String?
    var bio: String?
    var genres: [String]
    var hometown: String // Should be "Flint, MI" or nearby
    var profileImageURL: String?
    var bannerImageURL: String?
    
    // Apple Music Integration
    var appleMusicArtistID: String?
    var appleMusicURL: String?
    
    // Social Links
    var instagramHandle: String?
    var twitterHandle: String?
    var tiktokHandle: String?
    var youtubeChannelID: String?
    var spotifyArtistID: String?
    var soundcloudURL: String?
    var websiteURL: String?
    
    // Verification & Status
    var isVerified: Bool
    var verifiedAt: Date?
    var verificationBadge: VerificationBadge
    var memberSince: Date
    var lastActive: Date?
    
    // Stats
    var totalStreams: Int
    var monthlyListeners: Int
    var followerCount: Int
    var totalTips: Double // In USD
    
    // Featured Content
    var featuredTrackIDs: [String] // Apple Music track IDs
    var featuredPlaylistID: String?
    var latestReleaseDate: Date?
    
    // MyChannel Integration
    var myChannelUserID: String? // Link to MyChannel account
    var myChannelVideos: [String] // Video IDs
    
    enum VerificationBadge: String, Codable, CaseIterable {
        case none = "none"
        case rising = "rising"        // New artist, < 1000 streams
        case verified = "verified"    // Verified Flint artist
        case gold = "gold"           // 10k+ streams
        case platinum = "platinum"   // 100k+ streams
        case diamond = "diamond"     // 1M+ streams
        
        var icon: String {
            switch self {
            case .none: return ""
            case .rising: return "arrow.up.circle.fill"
            case .verified: return "checkmark.seal.fill"
            case .gold: return "star.circle.fill"
            case .platinum: return "crown.fill"
            case .diamond: return "diamond.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .clear
            case .rising: return .green
            case .verified: return .blue
            case .gold: return .yellow
            case .platinum: return Color(red: 0.9, green: 0.9, blue: 0.95)
            case .diamond: return .cyan
            }
        }
        
        var displayName: String {
            switch self {
            case .none: return ""
            case .rising: return "Rising Artist"
            case .verified: return "Verified 810"
            case .gold: return "Gold Artist"
            case .platinum: return "Platinum Artist"
            case .diamond: return "Diamond Artist"
            }
        }
    }
    
    // Coding keys for Firestore
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case stageName = "stage_name"
        case bio
        case genres
        case hometown
        case profileImageURL = "profile_image_url"
        case bannerImageURL = "banner_image_url"
        case appleMusicArtistID = "apple_music_artist_id"
        case appleMusicURL = "apple_music_url"
        case instagramHandle = "instagram_handle"
        case twitterHandle = "twitter_handle"
        case tiktokHandle = "tiktok_handle"
        case youtubeChannelID = "youtube_channel_id"
        case spotifyArtistID = "spotify_artist_id"
        case soundcloudURL = "soundcloud_url"
        case websiteURL = "website_url"
        case isVerified = "is_verified"
        case verifiedAt = "verified_at"
        case verificationBadge = "verification_badge"
        case memberSince = "member_since"
        case lastActive = "last_active"
        case totalStreams = "total_streams"
        case monthlyListeners = "monthly_listeners"
        case followerCount = "follower_count"
        case totalTips = "total_tips"
        case featuredTrackIDs = "featured_track_ids"
        case featuredPlaylistID = "featured_playlist_id"
        case latestReleaseDate = "latest_release_date"
        case myChannelUserID = "mychannel_user_id"
        case myChannelVideos = "mychannel_videos"
    }
    
    // Default initializer
    init(
        id: String = UUID().uuidString,
        name: String,
        stageName: String? = nil,
        bio: String? = nil,
        genres: [String] = [],
        hometown: String = "Flint, MI",
        profileImageURL: String? = nil,
        bannerImageURL: String? = nil,
        appleMusicArtistID: String? = nil,
        appleMusicURL: String? = nil,
        instagramHandle: String? = nil,
        twitterHandle: String? = nil,
        tiktokHandle: String? = nil,
        youtubeChannelID: String? = nil,
        spotifyArtistID: String? = nil,
        soundcloudURL: String? = nil,
        websiteURL: String? = nil,
        isVerified: Bool = false,
        verifiedAt: Date? = nil,
        verificationBadge: VerificationBadge = .none,
        memberSince: Date = Date(),
        lastActive: Date? = nil,
        totalStreams: Int = 0,
        monthlyListeners: Int = 0,
        followerCount: Int = 0,
        totalTips: Double = 0,
        featuredTrackIDs: [String] = [],
        featuredPlaylistID: String? = nil,
        latestReleaseDate: Date? = nil,
        myChannelUserID: String? = nil,
        myChannelVideos: [String] = []
    ) {
        self.id = id
        self.name = name
        self.stageName = stageName
        self.bio = bio
        self.genres = genres
        self.hometown = hometown
        self.profileImageURL = profileImageURL
        self.bannerImageURL = bannerImageURL
        self.appleMusicArtistID = appleMusicArtistID
        self.appleMusicURL = appleMusicURL
        self.instagramHandle = instagramHandle
        self.twitterHandle = twitterHandle
        self.tiktokHandle = tiktokHandle
        self.youtubeChannelID = youtubeChannelID
        self.spotifyArtistID = spotifyArtistID
        self.soundcloudURL = soundcloudURL
        self.websiteURL = websiteURL
        self.isVerified = isVerified
        self.verifiedAt = verifiedAt
        self.verificationBadge = verificationBadge
        self.memberSince = memberSince
        self.lastActive = lastActive
        self.totalStreams = totalStreams
        self.monthlyListeners = monthlyListeners
        self.followerCount = followerCount
        self.totalTips = totalTips
        self.featuredTrackIDs = featuredTrackIDs
        self.featuredPlaylistID = featuredPlaylistID
        self.latestReleaseDate = latestReleaseDate
        self.myChannelUserID = myChannelUserID
        self.myChannelVideos = myChannelVideos
    }
    
    var displayName: String {
        stageName ?? name
    }
    
    var areaCode: String {
        "810" // Flint area code
    }
}

// MARK: - Flint Artist Track (combines Apple Music data with Flint artist info)

struct FeaturedArtistTrack: Identifiable, Equatable {
    let id: String
    let track: MusicKitTrack
    let artist: FeaturedArtist
    
    var isFeaturedTrack: Bool { true }
    
    static func == (lhs: FeaturedArtistTrack, rhs: FeaturedArtistTrack) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Flint Artist Service

@MainActor
final class FeaturedArtistService: ObservableObject {
    static let shared = FeaturedArtistService()
    
    // MARK: - Published Properties
    @Published private(set) var artists: [FeaturedArtist] = []
    @Published private(set) var featuredArtists: [FeaturedArtist] = []
    @Published private(set) var risingArtists: [FeaturedArtist] = []
    @Published private(set) var verifiedArtists: [FeaturedArtist] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?
    
    // Cache
    private var artistCache: [String: FeaturedArtist] = [:]
    private var lastFetchTime: Date?
    private let cacheExpirationMinutes: Double = 30
    
    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    private let collectionName = "flint-artists"
    #endif
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        // Load cached artists on init
        loadCachedArtists()
    }
    
    // MARK: - Fetch Artists
    
    /// Fetch all Flint artists from Firestore
    func fetchArtists() async {
        guard !isLoading else { return }
        
        // Check cache validity
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheExpirationMinutes * 60,
           !artists.isEmpty {
            return
        }
        
        isLoading = true
        lastError = nil
        
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection(collectionName)
                .order(by: "total_streams", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            let fetchedArtists = snapshot.documents.compactMap { doc -> FeaturedArtist? in
                try? doc.data(as: FeaturedArtist.self)
            }
            
            artists = fetchedArtists
            updateArtistCategories()
            cacheArtists(fetchedArtists)
            lastFetchTime = Date()
            
            print("🔥 [FeaturedArtists] Fetched \(fetchedArtists.count) artists from Firestore")
        } catch {
            lastError = error.localizedDescription
            print("❌ [FeaturedArtists] Fetch error: \(error)")
            
            // Fall back to seed data if Firestore fails
            if artists.isEmpty {
                artists = Self.seedArtists
                updateArtistCategories()
            }
        }
        #else
        // Use seed data if Firebase not available
        artists = Self.seedArtists
        updateArtistCategories()
        #endif
        
        isLoading = false
    }
    
    /// Fetch a single artist by ID
    func fetchArtist(id: String) async -> FeaturedArtist? {
        // Check cache first
        if let cached = artistCache[id] {
            return cached
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection(collectionName).document(id).getDocument()
            if let artist = try? doc.data(as: FeaturedArtist.self) {
                artistCache[id] = artist
                return artist
            }
        } catch {
            print("❌ [FeaturedArtists] Error fetching artist \(id): \(error)")
        }
        #endif
        
        // Check seed data
        return Self.seedArtists.first { $0.id == id }
    }
    
    /// Search featured artists
    func searchArtists(query: String) async -> [FeaturedArtist] {
        let lowercasedQuery = query.lowercased()
        
        // First search local cache
        let localResults = artists.filter { artist in
            artist.displayName.lowercased().contains(lowercasedQuery) ||
            artist.genres.contains { $0.lowercased().contains(lowercasedQuery) }
        }
        
        if !localResults.isEmpty {
            return localResults
        }
        
        #if canImport(FirebaseFirestore)
        // If no local results, search Firestore
        do {
            let snapshot = try await db.collection(collectionName)
                .whereField("name", isGreaterThanOrEqualTo: query)
                .whereField("name", isLessThanOrEqualTo: query + "\u{f8ff}")
                .limit(to: 20)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> FeaturedArtist? in
                try? doc.data(as: FeaturedArtist.self)
            }
        } catch {
            print("❌ [FeaturedArtists] Search error: \(error)")
        }
        #endif
        
        return []
    }
    
    // MARK: - Artist Management
    
    /// Register a new featured artist (pending verification)
    func registerArtist(_ artist: FeaturedArtist) async throws {
        #if canImport(FirebaseFirestore)
        var newArtist = artist
        newArtist.memberSince = Date()
        newArtist.isVerified = false
        newArtist.verificationBadge = .rising
        
        try db.collection(collectionName).document(artist.id).setData(from: newArtist)
        
        // Add to local list
        artists.append(newArtist)
        updateArtistCategories()
        
        print("🔥 [FeaturedArtists] Registered new artist: \(artist.displayName)")
        #else
        throw FeaturedArtistError.firestoreNotAvailable
        #endif
    }
    
    /// Update artist profile
    func updateArtist(_ artist: FeaturedArtist) async throws {
        #if canImport(FirebaseFirestore)
        try db.collection(collectionName).document(artist.id).setData(from: artist, merge: true)
        
        // Update local cache
        if let index = artists.firstIndex(where: { $0.id == artist.id }) {
            artists[index] = artist
        }
        artistCache[artist.id] = artist
        updateArtistCategories()
        
        print("✅ [FeaturedArtists] Updated artist: \(artist.displayName)")
        #else
        throw FeaturedArtistError.firestoreNotAvailable
        #endif
    }
    
    /// Record a stream for an artist
    func recordStream(artistID: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection(collectionName).document(artistID).updateData([
                "total_streams": FieldValue.increment(Int64(1)),
                "last_active": FieldValue.serverTimestamp()
            ])
            
            // Update local cache
            if var artist = artistCache[artistID] {
                artist.totalStreams += 1
                artist.lastActive = Date()
                artistCache[artistID] = artist
                
                if let index = artists.firstIndex(where: { $0.id == artistID }) {
                    artists[index] = artist
                }
            }
        } catch {
            print("❌ [FeaturedArtists] Error recording stream: \(error)")
        }
        #endif
    }
    
    /// Record a tip for an artist
    func recordTip(artistID: String, amount: Double) async {
        #if canImport(FirebaseFirestore)
        do {
            try await db.collection(collectionName).document(artistID).updateData([
                "total_tips": FieldValue.increment(amount),
                "last_active": FieldValue.serverTimestamp()
            ])
            
            print("💰 [FeaturedArtists] Recorded tip of $\(amount) for artist \(artistID)")
        } catch {
            print("❌ [FeaturedArtists] Error recording tip: \(error)")
        }
        #endif
    }
    
    // MARK: - Track Integration
    
    /// Get tracks for a Flint artist from Apple Music using their artist ID
    func getArtistTracks(artist: FeaturedArtist) async -> [FeaturedArtistTrack] {
        guard let appleMusicID = artist.appleMusicArtistID else {
            return []
        }
        
        let musicKitService = MusicKitService.shared
        
        // Ensure authorized
        if musicKitService.authorizationStatus != .authorized {
            _ = await musicKitService.requestAuthorization()
            guard musicKitService.authorizationStatus == .authorized else { return [] }
        }
        
        do {
            // Use the actual Apple Music artist ID for accurate top songs
            let itemID = MusicItemID(appleMusicID)
            let tracks = try await musicKitService.getArtistTopSongs(artistID: itemID, limit: 20)
            
            return tracks.map { track in
                var modifiedTrack = track
                modifiedTrack.isFeaturedArtist = true
                modifiedTrack.featuredArtistID = artist.id
                
                return FeaturedArtistTrack(
                    id: "\(artist.id)-\(track.id)",
                    track: modifiedTrack,
                    artist: artist
                )
            }
        } catch {
            // Fallback to search if artist ID lookup fails
            print("⚠️ [FeaturedArtists] Artist ID lookup failed for \(artist.displayName), falling back to search: \(error)")
            do {
                let tracks = try await musicKitService.search(term: artist.displayName, limit: 20)
                return tracks.map { track in
                    var modifiedTrack = track
                    modifiedTrack.isFeaturedArtist = true
                    modifiedTrack.featuredArtistID = artist.id
                    return FeaturedArtistTrack(
                        id: "\(artist.id)-\(track.id)",
                        track: modifiedTrack,
                        artist: artist
                    )
                }
            } catch {
                print("❌ [FeaturedArtists] Error fetching tracks for \(artist.displayName): \(error)")
                return []
            }
        }
    }
    
    /// Get all featured Flint tracks
    func getFeaturedTracks() async -> [FeaturedArtistTrack] {
        var allTracks: [FeaturedArtistTrack] = []
        
        for artist in featuredArtists.prefix(5) {
            let tracks = await getArtistTracks(artist: artist)
            allTracks.append(contentsOf: tracks.prefix(3))
        }
        
        return allTracks
    }
    
    // MARK: - Private Helpers
    
    private func updateArtistCategories() {
        // Featured = Top artists by streams
        featuredArtists = artists
            .sorted { $0.totalStreams > $1.totalStreams }
            .prefix(10)
            .map { $0 }
        
        // Rising = Newer artists with lower streams
        risingArtists = artists.filter { $0.totalStreams < 100000 }
            .sorted { $0.memberSince > $1.memberSince }
            .prefix(10)
            .map { $0 }
        
        // All verified artists
        verifiedArtists = artists.filter { $0.isVerified }
            .sorted { $0.totalStreams > $1.totalStreams }
    }
    
    private func cacheArtists(_ artists: [FeaturedArtist]) {
        for artist in artists {
            artistCache[artist.id] = artist
        }
        
        // Persist to UserDefaults for offline access
        if let encoded = try? JSONEncoder().encode(artists) {
            UserDefaults.standard.set(encoded, forKey: "cached_featured_artists")
        }
    }
    
    private func loadCachedArtists() {
        if let data = UserDefaults.standard.data(forKey: "cached_featured_artists"),
           let cached = try? JSONDecoder().decode([FeaturedArtist].self, from: data) {
            artists = cached
            updateArtistCategories()
            
            for artist in cached {
                artistCache[artist.id] = artist
            }
        }
    }
    
    // MARK: - Seed Data (Featured Artists)
    
    static let seedArtists: [FeaturedArtist] = [
        
        // ========== LEGENDS / OGs ==========
        
        FeaturedArtist(
            id: "flint-001",
            name: "MC Breed",
            stageName: "MC Breed",
            bio: "Flint hip-hop pioneer. 'Ain't No Future in Yo' Frontin'' put Flint on the map. RIP Legend.",
            genres: ["Hip-Hop", "G-Funk"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/3LfgZdZbv0I/hqdefault.jpg",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 5000000,
            monthlyListeners: 150000,
            followerCount: 250000
        ),
        FeaturedArtist(
            id: "flint-002",
            name: "Dayton Family",
            stageName: "Dayton Family",
            bio: "Legendary Flint hip-hop group. FBI album went gold. Midwest gangsta rap pioneers.",
            genres: ["Hip-Hop", "Gangsta Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/gPft7MPWq0k/hqdefault.jpg",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 3000000,
            monthlyListeners: 80000,
            followerCount: 175000
        ),
        FeaturedArtist(
            id: "flint-003",
            name: "Bootleg",
            stageName: "Bootleg",
            bio: "Dayton Family member. Flint gangsta rap legend.",
            genres: ["Hip-Hop", "Gangsta Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/8xQMfcR_Txw/hqdefault.jpg",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 600000,
            monthlyListeners: 25000,
            followerCount: 65000
        ),
        FeaturedArtist(
            id: "flint-004",
            name: "Shoestring",
            stageName: "Shoestring",
            bio: "Dayton Family founding member. Flint rap pioneer.",
            genres: ["Hip-Hop", "Gangsta Rap"],
            hometown: "Flint, MI",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 400000,
            monthlyListeners: 12000,
            followerCount: 35000
        ),
        FeaturedArtist(
            id: "flint-005",
            name: "Big Herk",
            stageName: "Big Herk",
            bio: "Flint OG. Street legend.",
            genres: ["Hip-Hop", "Gangsta Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/W8CiGjLlHDs/hqdefault.jpg",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 500000,
            monthlyListeners: 15000,
            followerCount: 40000
        ),
        
        // ========== CURRENT GENERATION ==========
        
        FeaturedArtist(
            id: "flint-006",
            name: "YN Jay",
            stageName: "YN Jay",
            bio: "The Coochie Man. Viral sensation. Flint's biggest current artist.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/pnQ0BXTfBjk/hqdefault.jpg",
            appleMusicArtistID: "1474729367",
            instagramHandle: "yn_jay",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 50000000,
            monthlyListeners: 800000,
            followerCount: 500000
        ),
        FeaturedArtist(
            id: "flint-007",
            name: "Rio Da Yung OG",
            stageName: "Rio Da Yung OG",
            bio: "Flint street rap king. Raw 810 energy.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/6DZSh9vqlWc/hqdefault.jpg",
            appleMusicArtistID: "1459166831",
            instagramHandle: "riodayungog",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 2500000,
            monthlyListeners: 250000,
            followerCount: 350000
        ),
        FeaturedArtist(
            id: "flint-008",
            name: "Jon Connor",
            stageName: "Jon Connor",
            bio: "Signed to Dr. Dre's Aftermath Entertainment. Lyrical powerhouse.",
            genres: ["Hip-Hop", "Conscious Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/0zq7cRFyCpU/hqdefault.jpg",
            appleMusicArtistID: "421440126",
            instagramHandle: "jonconnormusic",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 800000,
            monthlyListeners: 45000,
            followerCount: 95000
        ),
        FeaturedArtist(
            id: "flint-009",
            name: "RMC Mike",
            stageName: "RMC Mike",
            bio: "Viral freestyles. Comedy and hard bars. Flint favorite.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/x_E1bq1sYdY/hqdefault.jpg",
            appleMusicArtistID: "1467627944",
            instagramHandle: "rmcmike",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 5000000,
            monthlyListeners: 150000,
            followerCount: 180000
        ),
        FeaturedArtist(
            id: "flint-010",
            name: "Louie Ray",
            stageName: "Louie Ray",
            bio: "Flint's melodic king. Smooth flows over hard beats.",
            genres: ["Hip-Hop", "Melodic Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/oVP_aK7JzDw/hqdefault.jpg",
            appleMusicArtistID: "1452673627",
            instagramHandle: "louieray",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 3000000,
            monthlyListeners: 120000,
            followerCount: 140000
        ),
        FeaturedArtist(
            id: "flint-011",
            name: "KrispyLife Kidd",
            stageName: "KrispyLife Kidd",
            bio: "KrispyLife gang. Consistent drops. Real 810.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/xv88_-pLqz8/hqdefault.jpg",
            appleMusicArtistID: "1487654432",
            instagramHandle: "krispylifekidd",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 2000000,
            monthlyListeners: 80000,
            followerCount: 90000
        ),
        FeaturedArtist(
            id: "flint-012",
            name: "YSR Gramz",
            stageName: "YSR Gramz",
            bio: "Flint rapper. Street anthems. YSR gang.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://i.ytimg.com/vi/HqC7Ov7sCwA/hqdefault.jpg",
            appleMusicArtistID: "1474729367",
            appleMusicURL: "https://music.apple.com/us/artist/ysr-gramz/1474729367",
            instagramHandle: "ysrgramz",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 1500000,
            monthlyListeners: 60000,
            followerCount: 75000
        ),

        // ========== FEATURED ARTISTS ==========

        FeaturedArtist(
            id: "feat-mia-ghost",
            name: "MIA Ghost",
            stageName: "MIA Ghost",
            bio: "REALITY CHECK (2026). Top tracks: GAME 7, FAKE & REAL, BEETLEJUICE. 7 albums deep.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "MIA",
            appleMusicArtistID: "1582746406",
            appleMusicURL: "https://music.apple.com/us/artist/mia-ghost/1582746406",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 800000,
            monthlyListeners: 35000,
            followerCount: 50000
        ),
        FeaturedArtist(
            id: "feat-mia-getem",
            name: "MIA Getem",
            stageName: "MIA Getem",
            bio: "Take A Gamble (2026). Top tracks: BEETLEJUICE, SCORE, BUMP, SOS. Strictly entertainment.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "MIA",
            appleMusicArtistID: "1798000837",
            appleMusicURL: "https://music.apple.com/us/artist/mia-getem/1798000837",
            isVerified: true,
            verificationBadge: .rising,
            totalStreams: 300000,
            monthlyListeners: 15000,
            followerCount: 20000
        ),
        FeaturedArtist(
            id: "feat-bk-babydumpper",
            name: "Bk BabyDumpper",
            stageName: "Bk BabyDumpper",
            bio: "The Dumpp Zone. Raw street music.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            appleMusicArtistID: "1709296525",
            appleMusicURL: "https://music.apple.com/us/artist/bk-babydumpper/1709296525",
            isVerified: true,
            verificationBadge: .rising,
            totalStreams: 100000,
            monthlyListeners: 8000,
            followerCount: 12000
        ),
        FeaturedArtist(
            id: "feat-lil-donny",
            name: "Lil Donny",
            stageName: "Lil Donny",
            bio: "Lead Baby (2026). Latest drop: So Gone. Smooth with the melodies.",
            genres: ["Hip-Hop", "Melodic Rap"],
            hometown: "Michigan",
            appleMusicURL: "https://music.apple.com/us/album/so-gone/1882571908?i=1882572102",
            isVerified: true,
            verificationBadge: .rising,
            totalStreams: 150000,
            monthlyListeners: 10000,
            followerCount: 15000
        ),
        FeaturedArtist(
            id: "feat-hotboy-curry",
            name: "Hotboy Curry",
            stageName: "Hotboy Curry",
            bio: "Pressin Curry (2025). Top tracks: Qurom, Whoopty Doo, Saved By The Bell. 7 albums. Gangaroni time.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            appleMusicArtistID: "1771099410",
            appleMusicURL: "https://music.apple.com/us/artist/hotboy-curry/1771099410",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 600000,
            monthlyListeners: 25000,
            followerCount: 35000
        ),
        FeaturedArtist(
            id: "feat-ysr-loski",
            name: "Ysr Loski",
            stageName: "Ysr Loski",
            bio: "Wtf Loski ? 2 (2025). Top tracks: Beecher Mafia, Miami Nights, Energy. 7 albums. YSR label.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            appleMusicArtistID: "1511351716",
            appleMusicURL: "https://music.apple.com/us/artist/ysr-loski/1511351716",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 500000,
            monthlyListeners: 20000,
            followerCount: 30000
        ),
        FeaturedArtist(
            id: "feat-luh-monti",
            name: "Luh Monti",
            stageName: "Luh Monti",
            bio: "Like That (2026). Top tracks: Dr Dolittle, 679, All Facts. 5 albums. Olympic Shit Talking.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            appleMusicArtistID: "1656612386",
            appleMusicURL: "https://music.apple.com/us/artist/luh-monti/1656612386",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 400000,
            monthlyListeners: 18000,
            followerCount: 25000
        ),
        FeaturedArtist(
            id: "feat-babyfxce-e",
            name: "Babyfxce E",
            stageName: "Babyfxce E",
            bio: "Da Realest (2026). Top tracks: Die Bout It, Trackhawk, The Big 3, PTP. 6 albums. Real striker music.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            appleMusicArtistID: "1573432856",
            appleMusicURL: "https://music.apple.com/us/artist/babyfxce-e/1573432856",
            isVerified: true,
            verificationBadge: .gold,
            totalStreams: 2000000,
            monthlyListeners: 80000,
            followerCount: 100000
        ),
        FeaturedArtist(
            id: "feat-3200-tre",
            name: "3200 Tre",
            stageName: "3200 Tre",
            bio: "679 feat. Luh Monti (2026). Top tracks: Duffy, Open A Bank, I'm With 30. 7 albums. Real Mitten Baby.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            appleMusicArtistID: "1491631657",
            appleMusicURL: "https://music.apple.com/us/artist/3200-tre/1491631657",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 700000,
            monthlyListeners: 30000,
            followerCount: 40000
        ),
        FeaturedArtist(
            id: "feat-ktrip",
            name: "Ktrip",
            stageName: "Ktrip",
            bio: "Life After Death (2021). Top tracks: No shoes, Young Goat Shit, Be Still. Speaking from Experience.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            appleMusicArtistID: "1484873437",
            appleMusicURL: "https://music.apple.com/us/artist/ktrip/1484873437",
            isVerified: true,
            verificationBadge: .rising,
            totalStreams: 200000,
            monthlyListeners: 10000,
            followerCount: 15000
        ),
        FeaturedArtist(
            id: "feat-baby-ju",
            name: "Baby Ju",
            stageName: "Baby Ju",
            bio: "27 Nights (2022). Top tracks: Chrome Heart, Fully Mode, Cash Back. D-Rob Gang.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            appleMusicArtistID: "1649723396",
            appleMusicURL: "https://music.apple.com/us/artist/baby-ju/1649723396",
            isVerified: true,
            verificationBadge: .rising,
            totalStreams: 150000,
            monthlyListeners: 8000,
            followerCount: 12000
        ),
        FeaturedArtist(
            id: "feat-ftos-twan",
            name: "Ftos Twan",
            stageName: "Ftos Twan",
            bio: "Unk & Neph (2026). Top tracks: Perk Talk, Tom Hanson, 4 Headed Goat. 7 albums. Chess Not Checkers.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            appleMusicArtistID: "1527300992",
            appleMusicURL: "https://music.apple.com/us/artist/ftos-twan/1527300992",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 500000,
            monthlyListeners: 20000,
            followerCount: 30000
        ),
        FeaturedArtist(
            id: "feat-scatz",
            name: "Scatz",
            stageName: "Scatz",
            bio: "Free Ghost (2026). Top tracks: Rice St, Benjamin Button, Free Da Yung OG. Six Ward Lord.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            appleMusicArtistID: "904008025",
            appleMusicURL: "https://music.apple.com/us/artist/scatz/904008025",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 400000,
            monthlyListeners: 18000,
            followerCount: 25000
        ),
        FeaturedArtist(
            id: "feat-baby-ghost",
            name: "Baby Ghost",
            stageName: "Baby Ghost",
            bio: "Hurting Bad (2026). Top tracks: BOW, 3 Kills, Wham!, Elvis Presley. Gho Krazy series.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            appleMusicArtistID: "1507813989",
            appleMusicURL: "https://music.apple.com/us/artist/baby-ghost/1507813989",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 600000,
            monthlyListeners: 25000,
            followerCount: 35000
        ),
        FeaturedArtist(
            id: "feat-way-p",
            name: "Way P",
            stageName: "Way P",
            bio: "Prolly feat. FblManny (2025). Top tracks: Gang baby, Probably, All Rise, Broad Day.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            appleMusicArtistID: "1524383650",
            appleMusicURL: "https://music.apple.com/us/artist/way-p/1524383650",
            isVerified: true,
            verificationBadge: .rising,
            totalStreams: 100000,
            monthlyListeners: 5000,
            followerCount: 8000
        )
    ]
}

// MARK: - Errors

enum FeaturedArtistError: Error, LocalizedError {
    case firestoreNotAvailable
    case artistNotFound
    case updateFailed
    case registrationFailed
    
    var errorDescription: String? {
        switch self {
        case .firestoreNotAvailable:
            return "Database connection not available."
        case .artistNotFound:
            return "Artist not found."
        case .updateFailed:
            return "Failed to update artist profile."
        case .registrationFailed:
            return "Failed to register artist."
        }
    }
}

// MARK: - Preview

#if DEBUG
extension FeaturedArtistService {
    static var preview: FeaturedArtistService {
        let service = FeaturedArtistService.shared
        service.artists = FeaturedArtistService.seedArtists
        service.updateArtistCategories()
        return service
    }
}
#endif







