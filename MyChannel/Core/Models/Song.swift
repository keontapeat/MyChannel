//
//  Song.swift
//  MyChannel
//
//  Core music track model for MyChannel Music.
//

import Foundation

/// Core domain model representing a single music track.
struct Song: Identifiable, Codable, Equatable {
    enum AudioQuality: String, Codable, CaseIterable {
        case standard
        case high
        case lossless
    }
    
    let id: String
    let title: String
    let artistIds: [String]
    let primaryArtistId: String
    let albumId: String?
    
    let duration: TimeInterval
    let artworkURL: URL?
    let previewArtworkURL: URL?
    
    /// Primary HLS or file URL for playback.
    let streamURL: URL?
    
    /// Optional alternate streams for adaptive bitrate.
    let alternateStreamURLs: [URL]
    
    let isExplicit: Bool
    let releaseDate: Date?
    let genre: String?
    
    // Credits
    let producer: String?
    let songwriters: [String]
    let featuredArtists: [String]
    
    // Analytics / library metadata
    let playCount: Int
    let likeCount: Int
    let isLiked: Bool
    let isDownloaded: Bool
    
    let preferredQuality: AudioQuality
    
    init(
        id: String = UUID().uuidString,
        title: String,
        artistIds: [String],
        primaryArtistId: String,
        albumId: String? = nil,
        duration: TimeInterval,
        artworkURL: URL? = nil,
        previewArtworkURL: URL? = nil,
        streamURL: URL? = nil,
        alternateStreamURLs: [URL] = [],
        isExplicit: Bool = false,
        releaseDate: Date? = nil,
        genre: String? = nil,
        producer: String? = nil,
        songwriters: [String] = [],
        featuredArtists: [String] = [],
        playCount: Int = 0,
        likeCount: Int = 0,
        isLiked: Bool = false,
        isDownloaded: Bool = false,
        preferredQuality: AudioQuality = .standard
    ) {
        self.id = id
        self.title = title
        self.artistIds = artistIds
        self.primaryArtistId = primaryArtistId
        self.albumId = albumId
        self.duration = duration
        self.artworkURL = artworkURL
        self.previewArtworkURL = previewArtworkURL
        self.streamURL = streamURL
        self.alternateStreamURLs = alternateStreamURLs
        self.isExplicit = isExplicit
        self.releaseDate = releaseDate
        self.genre = genre
        self.producer = producer
        self.songwriters = songwriters
        self.featuredArtists = featuredArtists
        self.playCount = playCount
        self.likeCount = likeCount
        self.isLiked = isLiked
        self.isDownloaded = isDownloaded
        self.preferredQuality = preferredQuality
    }
    
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

