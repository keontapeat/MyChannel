//
//  Album.swift
//  MyChannel
//
//  Core album / project model for MyChannel Music.
//

import Foundation

struct Album: Identifiable, Codable, Equatable {
    enum AlbumType: String, Codable {
        case album
        case ep
        case single
    }
    
    let id: String
    let title: String
    let artistId: String
    let type: AlbumType
    
    let artworkURL: URL?
    let heroArtworkURL: URL?
    
    let releaseDate: Date?
    let label: String?
    let genres: [String]
    
    /// Ordered list of song ids in the album.
    let trackIds: [String]
    
    let totalDuration: TimeInterval
    let playCount: Int
    let likeCount: Int
    
    let isExplicit: Bool
    
    init(
        id: String = UUID().uuidString,
        title: String,
        artistId: String,
        type: AlbumType,
        artworkURL: URL? = nil,
        heroArtworkURL: URL? = nil,
        releaseDate: Date? = nil,
        label: String? = nil,
        genres: [String] = [],
        trackIds: [String] = [],
        totalDuration: TimeInterval = 0,
        playCount: Int = 0,
        likeCount: Int = 0,
        isExplicit: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artistId = artistId
        self.type = type
        self.artworkURL = artworkURL
        self.heroArtworkURL = heroArtworkURL
        self.releaseDate = releaseDate
        self.label = label
        self.genres = genres
        self.trackIds = trackIds
        self.totalDuration = totalDuration
        self.playCount = playCount
        self.likeCount = likeCount
        self.isExplicit = isExplicit
    }
}

