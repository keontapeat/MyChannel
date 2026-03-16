//
//  Artist.swift
//  MyChannel
//
//  Core artist model for MyChannel Music.
//

import Foundation

struct Artist: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let slug: String
    
    let bio: String?
    let avatarURL: URL?
    let heroImageURL: URL?
    
    let followerCount: Int
    let monthlyListeners: Int
    
    let location: String?
    
    let topSongIds: [String]
    let albumIds: [String]
    let similarArtistIds: [String]
    
    let instagramURL: URL?
    let twitterURL: URL?
    let tiktokURL: URL?
    let websiteURL: URL?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        slug: String,
        bio: String? = nil,
        avatarURL: URL? = nil,
        heroImageURL: URL? = nil,
        followerCount: Int = 0,
        monthlyListeners: Int = 0,
        location: String? = nil,
        topSongIds: [String] = [],
        albumIds: [String] = [],
        similarArtistIds: [String] = [],
        instagramURL: URL? = nil,
        twitterURL: URL? = nil,
        tiktokURL: URL? = nil,
        websiteURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.bio = bio
        self.avatarURL = avatarURL
        self.heroImageURL = heroImageURL
        self.followerCount = followerCount
        self.monthlyListeners = monthlyListeners
        self.location = location
        self.topSongIds = topSongIds
        self.albumIds = albumIds
        self.similarArtistIds = similarArtistIds
        self.instagramURL = instagramURL
        self.twitterURL = twitterURL
        self.tiktokURL = tiktokURL
        self.websiteURL = websiteURL
    }
}

