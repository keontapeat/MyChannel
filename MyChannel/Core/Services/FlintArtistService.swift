//
//  FlintArtistService.swift
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
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Flint Artist Model

struct FlintArtist: Identifiable, Codable, Equatable {
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

struct FlintArtistTrack: Identifiable, Equatable {
    let id: String
    let track: MusicKitTrack
    let artist: FlintArtist
    
    var isFlintTrack: Bool { true }
    
    static func == (lhs: FlintArtistTrack, rhs: FlintArtistTrack) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Flint Artist Service

@MainActor
final class FlintArtistService: ObservableObject {
    static let shared = FlintArtistService()
    
    // MARK: - Published Properties
    @Published private(set) var artists: [FlintArtist] = []
    @Published private(set) var featuredArtists: [FlintArtist] = []
    @Published private(set) var risingArtists: [FlintArtist] = []
    @Published private(set) var verifiedArtists: [FlintArtist] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: String?
    
    // Cache
    private var artistCache: [String: FlintArtist] = [:]
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
            
            let fetchedArtists = snapshot.documents.compactMap { doc -> FlintArtist? in
                try? doc.data(as: FlintArtist.self)
            }
            
            artists = fetchedArtists
            updateArtistCategories()
            cacheArtists(fetchedArtists)
            lastFetchTime = Date()
            
            print("🔥 [FlintArtists] Fetched \(fetchedArtists.count) artists from Firestore")
        } catch {
            lastError = error.localizedDescription
            print("❌ [FlintArtists] Fetch error: \(error)")
            
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
    func fetchArtist(id: String) async -> FlintArtist? {
        // Check cache first
        if let cached = artistCache[id] {
            return cached
        }
        
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection(collectionName).document(id).getDocument()
            if let artist = try? doc.data(as: FlintArtist.self) {
                artistCache[id] = artist
                return artist
            }
        } catch {
            print("❌ [FlintArtists] Error fetching artist \(id): \(error)")
        }
        #endif
        
        // Check seed data
        return Self.seedArtists.first { $0.id == id }
    }
    
    /// Search Flint artists
    func searchArtists(query: String) async -> [FlintArtist] {
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
            
            return snapshot.documents.compactMap { doc -> FlintArtist? in
                try? doc.data(as: FlintArtist.self)
            }
        } catch {
            print("❌ [FlintArtists] Search error: \(error)")
        }
        #endif
        
        return []
    }
    
    // MARK: - Artist Management
    
    /// Register a new Flint artist (pending verification)
    func registerArtist(_ artist: FlintArtist) async throws {
        #if canImport(FirebaseFirestore)
        var newArtist = artist
        newArtist.memberSince = Date()
        newArtist.isVerified = false
        newArtist.verificationBadge = .rising
        
        try db.collection(collectionName).document(artist.id).setData(from: newArtist)
        
        // Add to local list
        artists.append(newArtist)
        updateArtistCategories()
        
        print("🔥 [FlintArtists] Registered new artist: \(artist.displayName)")
        #else
        throw FlintArtistError.firestoreNotAvailable
        #endif
    }
    
    /// Update artist profile
    func updateArtist(_ artist: FlintArtist) async throws {
        #if canImport(FirebaseFirestore)
        try db.collection(collectionName).document(artist.id).setData(from: artist, merge: true)
        
        // Update local cache
        if let index = artists.firstIndex(where: { $0.id == artist.id }) {
            artists[index] = artist
        }
        artistCache[artist.id] = artist
        updateArtistCategories()
        
        print("✅ [FlintArtists] Updated artist: \(artist.displayName)")
        #else
        throw FlintArtistError.firestoreNotAvailable
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
            print("❌ [FlintArtists] Error recording stream: \(error)")
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
            
            print("💰 [FlintArtists] Recorded tip of $\(amount) for artist \(artistID)")
        } catch {
            print("❌ [FlintArtists] Error recording tip: \(error)")
        }
        #endif
    }
    
    // MARK: - Track Integration
    
    /// Get tracks for a Flint artist from Apple Music
    func getArtistTracks(artist: FlintArtist) async -> [FlintArtistTrack] {
        guard let appleMusicID = artist.appleMusicArtistID else {
            return []
        }
        
        do {
            let musicKitService = MusicKitService.shared
            
            // Ensure authorized
            guard musicKitService.authorizationStatus == .authorized else {
                _ = await musicKitService.requestAuthorization()
                return []
            }
            
            // Search for artist's tracks
            let tracks = try await musicKitService.search(term: artist.displayName, limit: 20)
            
            return tracks.map { track in
                var modifiedTrack = track
                modifiedTrack.isFlintArtist = true
                modifiedTrack.flintArtistID = artist.id
                
                return FlintArtistTrack(
                    id: "\(artist.id)-\(track.id)",
                    track: modifiedTrack,
                    artist: artist
                )
            }
        } catch {
            print("❌ [FlintArtists] Error fetching tracks for \(artist.displayName): \(error)")
            return []
        }
    }
    
    /// Get all featured Flint tracks
    func getFeaturedTracks() async -> [FlintArtistTrack] {
        var allTracks: [FlintArtistTrack] = []
        
        for artist in featuredArtists.prefix(5) {
            let tracks = await getArtistTracks(artist: artist)
            allTracks.append(contentsOf: tracks.prefix(3))
        }
        
        return allTracks
    }
    
    // MARK: - Private Helpers
    
    private func updateArtistCategories() {
        featuredArtists = artists.filter { $0.isVerified && $0.totalStreams > 1000 }
            .sorted { $0.totalStreams > $1.totalStreams }
            .prefix(10)
            .map { $0 }
        
        risingArtists = artists.filter { $0.verificationBadge == .rising }
            .sorted { $0.memberSince > $1.memberSince }
            .prefix(10)
            .map { $0 }
        
        verifiedArtists = artists.filter { $0.isVerified }
            .sorted { $0.totalStreams > $1.totalStreams }
    }
    
    private func cacheArtists(_ artists: [FlintArtist]) {
        for artist in artists {
            artistCache[artist.id] = artist
        }
        
        // Persist to UserDefaults for offline access
        if let encoded = try? JSONEncoder().encode(artists) {
            UserDefaults.standard.set(encoded, forKey: "cached_flint_artists")
        }
    }
    
    private func loadCachedArtists() {
        if let data = UserDefaults.standard.data(forKey: "cached_flint_artists"),
           let cached = try? JSONDecoder().decode([FlintArtist].self, from: data) {
            artists = cached
            updateArtistCategories()
            
            for artist in cached {
                artistCache[artist.id] = artist
            }
        }
    }
    
    // MARK: - Seed Data (Flint Artists)
    
    static let seedArtists: [FlintArtist] = [
        FlintArtist(
            id: "flint-001",
            name: "Jon Connor",
            stageName: "Jon Connor",
            bio: "Flint's own lyrical powerhouse. Signed to Dr. Dre's Aftermath Entertainment.",
            genres: ["Hip-Hop", "Rap"],
            hometown: "Flint, MI",
            profileImageURL: nil,
            isVerified: true,
            verificationBadge: .platinum,
            totalStreams: 150000,
            monthlyListeners: 25000,
            followerCount: 50000
        ),
        FlintArtist(
            id: "flint-002",
            name: "Dayton Family",
            stageName: "Dayton Family",
            bio: "Legendary Flint hip-hop group. Pioneers of the Midwest sound.",
            genres: ["Hip-Hop", "Gangsta Rap"],
            hometown: "Flint, MI",
            isVerified: true,
            verificationBadge: .diamond,
            totalStreams: 500000,
            monthlyListeners: 15000,
            followerCount: 75000
        ),
        FlintArtist(
            id: "flint-003",
            name: "Killa Kyleon",
            stageName: "Killa Kyleon",
            bio: "Flint rapper bringing that raw street sound.",
            genres: ["Hip-Hop", "Trap"],
            hometown: "Flint, MI",
            isVerified: true,
            verificationBadge: .gold,
            totalStreams: 75000,
            monthlyListeners: 8000,
            followerCount: 20000
        ),
        FlintArtist(
            id: "flint-004",
            name: "Bootleg",
            stageName: "Bootleg",
            bio: "Member of Dayton Family. Flint hip-hop legend.",
            genres: ["Hip-Hop", "Gangsta Rap"],
            hometown: "Flint, MI",
            isVerified: true,
            verificationBadge: .platinum,
            totalStreams: 200000,
            monthlyListeners: 10000,
            followerCount: 35000
        ),
        FlintArtist(
            id: "flint-005",
            name: "MC Breed",
            stageName: "MC Breed",
            bio: "Flint hip-hop pioneer. 'Ain't No Future in Yo' Frontin'' legend.",
            genres: ["Hip-Hop", "G-Funk"],
            hometown: "Flint, MI",
            isVerified: true,
            verificationBadge: .diamond,
            totalStreams: 1000000,
            monthlyListeners: 50000,
            followerCount: 100000
        ),
        FlintArtist(
            id: "flint-006",
            name: "Young Rising Star",
            stageName: "YRS",
            bio: "New wave Flint artist. The future of 810 music.",
            genres: ["Hip-Hop", "Melodic Rap"],
            hometown: "Flint, MI",
            isVerified: false,
            verificationBadge: .rising,
            totalStreams: 500,
            monthlyListeners: 100,
            followerCount: 250
        ),
        FlintArtist(
            id: "flint-007",
            name: "810 Collective",
            stageName: "810 Collective",
            bio: "Flint's premier hip-hop collective. Representing the city.",
            genres: ["Hip-Hop", "Rap"],
            hometown: "Flint, MI",
            isVerified: true,
            verificationBadge: .verified,
            totalStreams: 25000,
            monthlyListeners: 3000,
            followerCount: 8000
        ),
        FlintArtist(
            id: "flint-008",
            name: "Flint Stone",
            stageName: "Flint Stone",
            bio: "Hard-hitting bars from the Vehicle City.",
            genres: ["Hip-Hop", "Boom Bap"],
            hometown: "Flint, MI",
            isVerified: true,
            verificationBadge: .gold,
            totalStreams: 45000,
            monthlyListeners: 5000,
            followerCount: 12000
        )
    ]
}

// MARK: - Errors

enum FlintArtistError: Error, LocalizedError {
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
extension FlintArtistService {
    static var preview: FlintArtistService {
        let service = FlintArtistService.shared
        service.artists = FlintArtistService.seedArtists
        service.updateArtistCategories()
        return service
    }
}
#endif




