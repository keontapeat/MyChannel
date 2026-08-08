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
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
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
    
    /// Register a new featured artist owned by the authenticated user.
    func registerArtist(_ artist: FeaturedArtist) async throws {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil,
              let userID = Auth.auth().currentUser?.uid else {
            throw FeaturedArtistError.notAuthenticated
        }

        let newArtist = FeaturedArtist(
            id: userID,
            name: artist.name,
            stageName: artist.stageName,
            bio: artist.bio,
            genres: artist.genres,
            hometown: artist.hometown,
            profileImageURL: artist.profileImageURL,
            bannerImageURL: artist.bannerImageURL,
            appleMusicArtistID: artist.appleMusicArtistID,
            appleMusicURL: artist.appleMusicURL,
            instagramHandle: artist.instagramHandle,
            twitterHandle: artist.twitterHandle,
            tiktokHandle: artist.tiktokHandle,
            youtubeChannelID: artist.youtubeChannelID,
            spotifyArtistID: artist.spotifyArtistID,
            soundcloudURL: artist.soundcloudURL,
            websiteURL: artist.websiteURL,
            isVerified: false,
            verifiedAt: nil,
            verificationBadge: .rising,
            memberSince: Date(),
            lastActive: nil,
            totalStreams: 0,
            monthlyListeners: 0,
            followerCount: 0,
            totalTips: 0,
            featuredTrackIDs: artist.featuredTrackIDs,
            featuredPlaylistID: artist.featuredPlaylistID,
            latestReleaseDate: artist.latestReleaseDate,
            myChannelUserID: userID,
            myChannelVideos: artist.myChannelVideos
        )

        try db.collection(collectionName).document(userID).setData(from: newArtist)

        if let index = artists.firstIndex(where: { $0.id == userID }) {
            artists[index] = newArtist
        } else {
            artists.append(newArtist)
        }
        artistCache[userID] = newArtist
        updateArtistCategories()

        print("🔥 [FeaturedArtists] Registered new artist: \(newArtist.displayName)")
        #else
        throw FeaturedArtistError.firestoreNotAvailable
        #endif
    }

    /// Update only owner-editable profile fields and preserve server-controlled state.
    func updateArtist(_ artist: FeaturedArtist) async throws {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil,
              let userID = Auth.auth().currentUser?.uid else {
            throw FeaturedArtistError.notAuthenticated
        }
        guard artist.id == userID else { throw FeaturedArtistError.ownershipMismatch }

        let reference = db.collection(collectionName).document(userID)
        let snapshot = try await reference.getDocument()
        guard snapshot.exists,
              let ownerID = snapshot.data()?["mychannel_user_id"] as? String else {
            throw FeaturedArtistError.artistNotFound
        }
        guard ownerID == userID else { throw FeaturedArtistError.ownershipMismatch }
        guard var updatedArtist = try? snapshot.data(as: FeaturedArtist.self) else {
            throw FeaturedArtistError.updateFailed
        }

        let updates: [String: Any] = [
            "name": artist.name,
            "stage_name": firestoreProfileValue(artist.stageName),
            "bio": firestoreProfileValue(artist.bio),
            "genres": artist.genres,
            "hometown": artist.hometown,
            "profile_image_url": firestoreProfileValue(artist.profileImageURL),
            "banner_image_url": firestoreProfileValue(artist.bannerImageURL),
            "apple_music_artist_id": firestoreProfileValue(artist.appleMusicArtistID),
            "apple_music_url": firestoreProfileValue(artist.appleMusicURL),
            "instagram_handle": firestoreProfileValue(artist.instagramHandle),
            "twitter_handle": firestoreProfileValue(artist.twitterHandle),
            "tiktok_handle": firestoreProfileValue(artist.tiktokHandle),
            "youtube_channel_id": firestoreProfileValue(artist.youtubeChannelID),
            "spotify_artist_id": firestoreProfileValue(artist.spotifyArtistID),
            "soundcloud_url": firestoreProfileValue(artist.soundcloudURL),
            "website_url": firestoreProfileValue(artist.websiteURL),
            "featured_track_ids": artist.featuredTrackIDs,
            "featured_playlist_id": firestoreProfileValue(artist.featuredPlaylistID),
            "latest_release_date": firestoreProfileValue(artist.latestReleaseDate),
            "mychannel_videos": artist.myChannelVideos
        ]
        try await reference.updateData(updates)

        updatedArtist.name = artist.name
        updatedArtist.stageName = artist.stageName
        updatedArtist.bio = artist.bio
        updatedArtist.genres = artist.genres
        updatedArtist.hometown = artist.hometown
        updatedArtist.profileImageURL = artist.profileImageURL
        updatedArtist.bannerImageURL = artist.bannerImageURL
        updatedArtist.appleMusicArtistID = artist.appleMusicArtistID
        updatedArtist.appleMusicURL = artist.appleMusicURL
        updatedArtist.instagramHandle = artist.instagramHandle
        updatedArtist.twitterHandle = artist.twitterHandle
        updatedArtist.tiktokHandle = artist.tiktokHandle
        updatedArtist.youtubeChannelID = artist.youtubeChannelID
        updatedArtist.spotifyArtistID = artist.spotifyArtistID
        updatedArtist.soundcloudURL = artist.soundcloudURL
        updatedArtist.websiteURL = artist.websiteURL
        updatedArtist.featuredTrackIDs = artist.featuredTrackIDs
        updatedArtist.featuredPlaylistID = artist.featuredPlaylistID
        updatedArtist.latestReleaseDate = artist.latestReleaseDate
        updatedArtist.myChannelVideos = artist.myChannelVideos

        if let index = artists.firstIndex(where: { $0.id == userID }) {
            artists[index] = updatedArtist
        }
        artistCache[userID] = updatedArtist
        updateArtistCategories()

        print("✅ [FeaturedArtists] Updated artist: \(updatedArtist.displayName)")
        #else
        throw FeaturedArtistError.firestoreNotAvailable
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func firestoreProfileValue(_ value: Any?) -> Any {
        value ?? FieldValue.delete()
    }
    #endif

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
            appleMusicArtistID: "1482962180",
            appleMusicURL: "https://music.apple.com/us/artist/yn-jay/1482962180",
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
            bio: "Harwood Blassic 2, Art of Spice Talk, Hablando Picante — Flint spice talk.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/81/a7/ef/81a7ef94-25da-9023-5605-c4bc32228387/0.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1477569694",
            appleMusicURL: "https://music.apple.com/us/artist/krispylife-kidd/1477569694",
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
            bio: "Auto Gramz 2, MAKE FLINT GREAT AGAIN, Lamelo Ball, White Runtz — Beecher / YSR.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/ee/c6/50/eec65020-6fe8-1fb2-b013-45151a3358c5/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1490787471",
            appleMusicURL: "https://music.apple.com/us/artist/ysr-gramz/1490787471",
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
            bio: "8Mile Run (2026). Dr Dolittle, 679, Youngest Shit Talker — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/de/e4/d6/dee4d6a0-ab09-f005-bff7-89f3af18d015/artwork.jpg/1000x1000bb.jpg",
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
            bio: "April Fools (2026). Open A Bank, Duffy, 3600, Real Mitten Baby — Flint 32.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/80/e3/f9/80e3f97a-8b05-5be4-00d8-1c213b8006b4/198309462473.png/1000x1000bb.jpg",
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
            bio: "Life After Death (2021). Young Goat Shit, Speaking from Experience, Be Still.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/a2/75/3c/a2753c0f-ac18-a4a9-c5b7-52d8517fc825/artwork.jpg/1000x1000bb.jpg",
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
            id: "feat-babii-moe",
            name: "Babii MOE",
            stageName: "Babii MOE",
            bio: "Fake Rich, Perfect Match, Free Mari — singles & EPs. Moeskii Vol. 1, Star Status.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/84/ae/b5/84aeb508-43fb-ddbd-c339-eef52d4f014d/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1507109510",
            appleMusicURL: "https://music.apple.com/us/artist/babii-moe/1507109510",
            instagramHandle: "babiimoe",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 800000,
            monthlyListeners: 22000,
            followerCount: 28000
        ),
        FeaturedArtist(
            id: "feat-ftos-twan",
            name: "Ftos Twan",
            stageName: "Ftos Twan",
            bio: "Unk & Neph (2026). Drug Abuse, Perk Talk, Chess Not Checkers — 7+ albums.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/be/0d/df/be0ddf50-b7d8-e222-d983-dee26af60055/artwork.jpg/1000x1000bb.jpg",
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
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/d6/5a/c8/d65ac829-bbbb-637c-825b-4ac71c76cb31/artwork.jpg/1000x1000bb.jpg",
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
            bio: "Hurting Bad (2026). Wham!, Gho Krazy, Free Da Yung Og — Gho Krazy series.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/ca/f7/e2/caf7e2d8-8f2c-30e7-64ff-d6cc60f05a11/725336485153_cover.jpg/1000x1000bb.jpg",
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
        ),
        FeaturedArtist(
            id: "feat-clean-up-man",
            name: "Clean Up Man",
            stageName: "Clean Up Man",
            bio: "Clean up Krew 2 (2025). Top tracks: Hit You with a 5Th, Mop stick Man, Choppa Baby. Six Ward / Flint energy.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/57/00/f3/5700f331-2d06-7f5d-cb98-43970fd52874/14UMGIM00860.rgb.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1538452293",
            appleMusicURL: "https://music.apple.com/us/artist/clean-up-man/1538452293",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 800000,
            monthlyListeners: 35000,
            followerCount: 50000
        ),
        FeaturedArtist(
            id: "feat-eightball-tank",
            name: "Eightball Tank",
            stageName: "Eightball Tank",
            bio: "FAR FROM OVER (2026). 8Ball Gramz, Mob Ties, Life Alert — Flint / YSR lane.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/80/43/67/80436720-e95e-2df6-6722-e54c4b61c3ae/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1492591865",
            appleMusicURL: "https://music.apple.com/us/artist/eightball-tank/1492591865",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 900000,
            monthlyListeners: 40000,
            followerCount: 55000
        ),
        FeaturedArtist(
            id: "feat-six-ward-von",
            name: "Six Ward Von",
            stageName: "Six Ward Von",
            bio: "NUN BIGGER (2026). Striker Musik, Underdog, Product of the 6 — Six Ward.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/ba/31/3a/ba313a57-7612-1c47-b561-94cac0c56825/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1564317122",
            appleMusicURL: "https://music.apple.com/us/artist/six-ward-von/1564317122",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 1100000,
            monthlyListeners: 45000,
            followerCount: 60000
        ),
        FeaturedArtist(
            id: "feat-mia-patman",
            name: "MIA Patman",
            stageName: "MIA Patman",
            bio: "Dope Boy Diary (2026). Pat Mahomes, Liquor Kickin In — MIA / 810.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "MIA",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/e0/7a/7d/e07a7d86-719e-5b9a-fbcc-dcc392cf58d9/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1548074075",
            appleMusicURL: "https://music.apple.com/us/artist/mia-patman/1548074075",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 950000,
            monthlyListeners: 38000,
            followerCount: 50000
        ),
        FeaturedArtist(
            id: "feat-lil-nook",
            name: "Lil Nook",
            stageName: "Lil Nook",
            bio: "I Hate The System, Slatt Go, All In (Bass Junky) — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Michigan",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/a3/ca/75/a3ca75b4-7328-8bf0-e8c3-995f79d4aa7e/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1763508797",
            appleMusicURL: "https://music.apple.com/us/artist/lil-nook/1763508797",
            isVerified: true,
            verificationBadge: .rising,
            totalStreams: 400000,
            monthlyListeners: 28000,
            followerCount: 35000
        ),
        FeaturedArtist(
            id: "feat-jeff-skigh",
            name: "Jeff Skigh",
            stageName: "Jeff Skigh",
            bio: "A Pretty Smooth Album (2025). Yeah I Know, Smokin' in Kanto, Sold feat. Ysr Gramz.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/ef/55/de/ef55de9e-ccb4-9094-a656-39e114a7b3a8/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "945119824",
            appleMusicURL: "https://music.apple.com/us/artist/jeff-skigh/945119824",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 750000,
            monthlyListeners: 32000,
            followerCount: 45000
        ),
        FeaturedArtist(
            id: "feat-homi-michel",
            name: "Homi Michel",
            stageName: "Homi Michel",
            bio: "THE 1317 (2024). Free Da Yung OG, 4 Headed Goat, Jokes On You with Baby Ghost.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/9e/06/21/9e0621d6-8252-fa1e-9018-d2373577f657/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1514456557",
            appleMusicURL: "https://music.apple.com/us/artist/homi-michel/1514456557",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 900000,
            monthlyListeners: 42000,
            followerCount: 55000
        ),
        FeaturedArtist(
            id: "feat-bbdr-tay",
            name: "BBDR Tay",
            stageName: "BBDR Tay",
            bio: "4 Headed Goat, 2Turnt, All the Smoke — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/46/4f/91/464f919a-1091-eb44-f450-5bbbb5b55b06/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1501537814",
            appleMusicURL: "https://music.apple.com/us/artist/bbdr-tay/1501537814",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 850000,
            monthlyListeners: 38000,
            followerCount: 50000
        ),
        FeaturedArtist(
            id: "feat-paidlife-zar",
            name: "PaidLife Zar",
            stageName: "PaidLife Zar",
            bio: "Sorry It Took So Long, Versatile, Opp Hunting Pt. 2 with BBDR Tay.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/a9/c3/b9/a9c3b97f-da2a-10fd-a6ab-1b0a9016d4fa/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1501538060",
            appleMusicURL: "https://music.apple.com/us/artist/paidlife-zar/1501538060",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 800000,
            monthlyListeners: 36000,
            followerCount: 48000
        ),
        FeaturedArtist(
            id: "feat-richvon23",
            name: "Richvon23",
            stageName: "Richvon23",
            bio: "Show No Mercy, Scams and Gramz, FTOS — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/4a/7d/a3/4a7da363-681c-53a6-9801-9adaa53f4598/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1531986560",
            appleMusicURL: "https://music.apple.com/us/artist/richvon23/1531986560",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 650000,
            monthlyListeners: 30000,
            followerCount: 42000
        ),
        FeaturedArtist(
            id: "feat-geeoutto",
            name: "Geeoutto",
            stageName: "Geeoutto",
            bio: "Beauty In Chaos (2025). Isolated Star, OuttoWRLD — MIA / 810.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "MIA",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/ce/f8/5d/cef85d09-00e9-fb80-5b50-87fd22a5b941/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1583072463",
            appleMusicURL: "https://music.apple.com/us/artist/geeoutto/1583072463",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 550000,
            monthlyListeners: 28000,
            followerCount: 38000
        ),
        FeaturedArtist(
            id: "feat-mia-curt",
            name: "Mia Curt",
            stageName: "Mia Curt",
            bio: "Locked In (2021), Missing Files EP — MIA.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "MIA",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/28/80/85/28808507-e934-39ab-1efc-e9ad16559a61/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1576989709",
            appleMusicURL: "https://music.apple.com/us/artist/mia-curt/1576989709",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 480000,
            monthlyListeners: 24000,
            followerCount: 32000
        ),
        FeaturedArtist(
            id: "feat-dee-grant",
            name: "Dee Grant",
            stageName: "Dee Grant",
            bio: "Know The Real You (2025). Treacherous, Less Pain, Wavy Baby — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/69/51/8f/69518f43-14af-7f5e-2230-196808e9c868/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1488384274",
            appleMusicURL: "https://music.apple.com/us/artist/dee-grant/1488384274",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 450000,
            monthlyListeners: 22000,
            followerCount: 30000
        ),
        FeaturedArtist(
            id: "feat-ftm-bear",
            name: "FTM Bear",
            stageName: "FTM Bear",
            bio: "Many Men (2025). Bear With Me, Section 8 Baby — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/35/8d/c6/358dc694-9e74-4b24-ec76-7967673cc7bb/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1483982707",
            appleMusicURL: "https://music.apple.com/us/artist/ftm-bear/1483982707",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 470000,
            monthlyListeners: 24000,
            followerCount: 31000
        ),
        FeaturedArtist(
            id: "feat-cliff-mac",
            name: "Cliff Mac",
            stageName: "Cliff Mac",
            bio: "V3 (2019). Calling Me, Fake Love — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music124/v4/62/9b/a5/629ba59a-6c8c-08f3-4a97-20854ecc77a0/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "964080263",
            appleMusicURL: "https://music.apple.com/us/artist/cliff-mac/964080263",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 420000,
            monthlyListeners: 20000,
            followerCount: 28000
        ),
        FeaturedArtist(
            id: "feat-obabe",
            name: "Obabe",
            stageName: "Obabe",
            bio: "O.M.A.R (2021). 2 Pennies 1 Phone, Pennies 2 Plenty — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/d2/6e/07/d26e0757-1906-3e11-70da-1b582201aef3/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1496302013",
            appleMusicURL: "https://music.apple.com/us/artist/obabe/1496302013",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 400000,
            monthlyListeners: 19000,
            followerCount: 26000
        ),
        FeaturedArtist(
            id: "feat-velly-beretta",
            name: "Velly Beretta",
            stageName: "Velly Beretta",
            bio: "One Deep In Deep Thought (2026). God Made Me Wait, Kitchen — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/19/4e/20/194e20d6-b961-bc15-6a24-9363e0c7ee5d/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1174001237",
            appleMusicURL: "https://music.apple.com/us/artist/velly-beretta/1174001237",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 520000,
            monthlyListeners: 26000,
            followerCount: 34000
        ),
        FeaturedArtist(
            id: "feat-king-cashes",
            name: "King Cashes",
            stageName: "King Cashes",
            bio: "Crab Rangoon (2025). Shipping & Handling Deluxe, Rockstar — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/43/10/ca/4310ca10-6cd5-cdfa-4c3d-aff43c8c6cc7/859715880588_cover.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1498000463",
            appleMusicURL: "https://music.apple.com/us/artist/king-cashes/1498000463",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 490000,
            monthlyListeners: 23000,
            followerCount: 31000
        ),
        FeaturedArtist(
            id: "feat-detwan-love",
            name: "Detwan Love",
            stageName: "Detwan Love",
            bio: "Keke Son (2020). Rick Ross, John Wall — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music114/v4/56/58/29/56582969-77c9-a9b0-a3c5-ce9e9c21dc58/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1155696158",
            appleMusicURL: "https://music.apple.com/us/artist/detwan-love/1155696158",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 460000,
            monthlyListeners: 21000,
            followerCount: 29000
        ),
        FeaturedArtist(
            id: "feat-real-jt",
            name: "Real JT",
            stageName: "Real JT",
            bio: "Time (2024). 614, Days Inn — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/23/84/04/23840407-851e-09a6-cdd9-2384ccab0cc3/198861062401.png/1000x1000bb.jpg",
            appleMusicArtistID: "1422427461",
            appleMusicURL: "https://music.apple.com/us/artist/real-jt/1422427461",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 440000,
            monthlyListeners: 20000,
            followerCount: 27000
        ),
        FeaturedArtist(
            id: "feat-lil-lik",
            name: "Lil Lik",
            stageName: "Lil Lik",
            bio: "Neglected Me (2025). 400 Shots, Im Trolling — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/9a/a4/72/9aa472a8-524c-ed20-4482-ca8b1b5f0520/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1725106609",
            appleMusicURL: "https://music.apple.com/us/artist/lil-lik/1725106609",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 380000,
            monthlyListeners: 17000,
            followerCount: 24000
        ),
        FeaturedArtist(
            id: "feat-stickz",
            name: "Stickz",
            stageName: "Stickz",
            bio: "1 of a kind (2025). Federal Indictments, Rich Off Bandlab — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/de/37/d9/de37d99c-c87d-f6a3-3bf4-5f8cd7fc9edc/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1676978658",
            appleMusicURL: "https://music.apple.com/us/artist/stickz/1676978658",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 360000,
            monthlyListeners: 16000,
            followerCount: 22000
        ),
        FeaturedArtist(
            id: "feat-mannykea",
            name: "MANNYKEA",
            stageName: "MANNYKEA",
            bio: "Concentration (2026). INSTITUIONALIZED, 60 onna P — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/c6/75/3c/c6753cfc-52d5-b997-7798-bf57165c4f3b/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1828612897",
            appleMusicURL: "https://music.apple.com/us/artist/mannykea/1828612897",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 340000,
            monthlyListeners: 15000,
            followerCount: 20000
        ),
        FeaturedArtist(
            id: "feat-ot-love",
            name: "Ot Love",
            stageName: "Ot Love",
            bio: "Mean nun (2026). Almost said Fcck Rap, Sad Punk — Flint.",
            genres: ["Hip-Hop", "Michigan Rap"],
            hometown: "Flint, MI",
            profileImageURL: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/87/be/f7/87bef762-24e7-2375-764c-65b92858489f/artwork.jpg/1000x1000bb.jpg",
            appleMusicArtistID: "1836358576",
            appleMusicURL: "https://music.apple.com/us/artist/ot-love/1836358576",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 320000,
            monthlyListeners: 14000,
            followerCount: 19000
        )
    ]
}

// MARK: - Errors

enum FeaturedArtistError: Error, LocalizedError {
    case firestoreNotAvailable
    case notAuthenticated
    case ownershipMismatch
    case artistNotFound
    case updateFailed
    case registrationFailed
    
    var errorDescription: String? {
        switch self {
        case .firestoreNotAvailable:
            return "Database connection not available."
        case .notAuthenticated:
            return "Sign in to manage your artist profile."
        case .ownershipMismatch:
            return "You can only manage the artist profile linked to your account."
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







