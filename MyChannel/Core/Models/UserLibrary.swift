//
//  UserLibrary.swift
//  MyChannel
//
//  Aggregated music library state for a listener.
//

import Foundation

struct UserLibrary: Codable, Equatable {
    var likedSongIds: Set<String>
    var savedAlbumIds: Set<String>
    var followedArtistIds: Set<String>
    var playlistIds: Set<String>
    var downloadedSongIds: Set<String>
    var recentlyPlayedSongIds: [String]
    
    init(
        likedSongIds: Set<String> = [],
        savedAlbumIds: Set<String> = [],
        followedArtistIds: Set<String> = [],
        playlistIds: Set<String> = [],
        downloadedSongIds: Set<String> = [],
        recentlyPlayedSongIds: [String] = []
    ) {
        self.likedSongIds = likedSongIds
        self.savedAlbumIds = savedAlbumIds
        self.followedArtistIds = followedArtistIds
        self.playlistIds = playlistIds
        self.downloadedSongIds = downloadedSongIds
        self.recentlyPlayedSongIds = recentlyPlayedSongIds
    }
}

