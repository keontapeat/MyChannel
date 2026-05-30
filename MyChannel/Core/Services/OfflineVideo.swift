//
//  OfflineVideo.swift
//  MyChannel
//
//  SwiftData Model for Local Persistence Engine
//  Allows for zero-latency offline home feeds
//

import Foundation
import SwiftData

@available(iOS 17, *)
@Model
final class OfflineVideo {
    @Attribute(.unique) var id: String
    var title: String
    var videoURL: String
    var thumbnailURL: String
    var creatorDisplayName: String
    var creatorProfileImage: String
    var savedAt: Date
    
    init(id: String, title: String, videoURL: String, thumbnailURL: String, creatorDisplayName: String, creatorProfileImage: String) {
        self.id = id
        self.title = title
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.creatorDisplayName = creatorDisplayName
        self.creatorProfileImage = creatorProfileImage
        self.savedAt = Date()
    }
}
