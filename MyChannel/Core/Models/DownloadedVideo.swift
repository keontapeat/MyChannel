//
//  DownloadedVideo.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Download Quality

enum DownloadVideoQuality: String, Codable, CaseIterable {
    case low = "360p"
    case medium = "480p"
    case high = "720p"
    case hd = "1080p"
    case highest = "1440p"

    var displayName: String {
        switch self {
        case .low:     return "Low (360p)"
        case .medium:  return "Medium (480p)"
        case .high:    return "High (720p)"
        case .hd:      return "HD (1080p)"
        case .highest: return "Highest (1440p)"
        }
    }

    var color: Color {
        switch self {
        case .low:     return .gray
        case .medium:  return .blue
        case .high:    return .green
        case .hd:      return .purple
        case .highest: return .orange
        }
    }

    var estimatedSize: String {
        switch self {
        case .low:     return "~50MB per hour"
        case .medium:  return "~100MB per hour"
        case .high:    return "~200MB per hour"
        case .hd:      return "~400MB per hour"
        case .highest: return "~600MB per hour"
        }
    }
}

// MARK: - Typealiases for backward compatibility
typealias DownloadQuality = DownloadVideoQuality

// MARK: - Downloaded Video Model

struct DownloadedVideo: Identifiable, Codable {
    @DocumentID var id: String?

    let videoId: String
    let title: String
    let channelName: String
    let channelId: String
    let thumbnailUrl: String
    let duration: TimeInterval
    let viewCount: Int
    let localFilePath: String
    let downloadDate: Date
    let fileSize: Int64
    let quality: DownloadVideoQuality
    var lastWatchedPosition: TimeInterval?
    var isWatched: Bool

    // MARK: Nested typealias so call sites can write DownloadedVideo.VideoQuality
    typealias VideoQuality = DownloadVideoQuality

    // MARK: Backward-compatible computed properties
    var thumbnailURL: String { thumbnailUrl }

    init(
        id: String? = nil,
        videoId: String,
        title: String,
        channelName: String,
        channelId: String = "",
        thumbnailUrl: String,
        duration: TimeInterval,
        viewCount: Int = 0,
        localFilePath: String = "",
        downloadDate: Date = Date(),
        fileSize: Int64 = 0,
        quality: DownloadVideoQuality = .high,
        lastWatchedPosition: TimeInterval? = nil,
        isWatched: Bool = false
    ) {
        self.id = id
        self.videoId = videoId
        self.title = title
        self.channelName = channelName
        self.channelId = channelId
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.viewCount = viewCount
        self.localFilePath = localFilePath
        self.downloadDate = downloadDate
        self.fileSize = fileSize
        self.quality = quality
        self.lastWatchedPosition = lastWatchedPosition
        self.isWatched = isWatched
    }

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .binary)
    }

    var formattedViewCount: String {
        if viewCount >= 1_000_000 {
            return String(format: "%.1fM views", Double(viewCount) / 1_000_000)
        } else if viewCount >= 1_000 {
            return String(format: "%.1fK views", Double(viewCount) / 1_000)
        } else {
            return "\(viewCount) views"
        }
    }

    var downloadTimeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: downloadDate, relativeTo: Date())
    }
}

// MARK: - Recommended Download

struct RecommendedDownload: Codable, Identifiable {
    var id: String { videoId }
    let videoId: String
    let title: String
    let channelName: String
    let channelId: String
    let thumbnailUrl: String
    let duration: TimeInterval
    let viewCount: Int
    let mlScore: Double
    let recommendationReason: String

    var formattedDuration: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var formattedViewCount: String {
        if viewCount >= 1_000_000 {
            return String(format: "%.1fM views", Double(viewCount) / 1_000_000)
        } else if viewCount >= 1_000 {
            return String(format: "%.1fK views", Double(viewCount) / 1_000)
        } else {
            return "\(viewCount) views"
        }
    }
}

// MARK: - Sample Data

extension DownloadedVideo {
    static var sampleDownloads: [DownloadedVideo] {
        [
            DownloadedVideo(
                videoId: "1",
                title: "Swift UI Advanced Techniques",
                channelName: "Tech Channel",
                thumbnailUrl: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=500&h=281&fit=crop",
                duration: 1200,
                viewCount: 45000,
                fileSize: 250 * 1024 * 1024,
                quality: .high
            ),
            DownloadedVideo(
                videoId: "2",
                title: "iOS Development Best Practices",
                channelName: "Developer Hub",
                thumbnailUrl: "https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=500&h=281&fit=crop",
                duration: 900,
                viewCount: 120000,
                fileSize: 180 * 1024 * 1024,
                quality: .medium,
                isWatched: true
            ),
            DownloadedVideo(
                videoId: "3",
                title: "Building Modern Apps with SwiftUI",
                channelName: "Code Masters",
                thumbnailUrl: "https://images.unsplash.com/photo-1517077304055-6e89abbf09b0?w=500&h=281&fit=crop",
                duration: 1800,
                viewCount: 88000,
                fileSize: 450 * 1024 * 1024,
                quality: .hd
            ),
            DownloadedVideo(
                videoId: "4",
                title: "EPIC Gaming Moments Compilation",
                channelName: "Pro Gamer Elite",
                thumbnailUrl: "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?w=500&h=281&fit=crop",
                duration: 900,
                viewCount: 2_400_000,
                downloadDate: Calendar.current.date(byAdding: .hour, value: -12, to: Date()) ?? Date(),
                fileSize: 320 * 1024 * 1024,
                quality: .high
            ),
            DownloadedVideo(
                videoId: "5",
                title: "Chill Beats for Study & Relax",
                channelName: "Chill Vibes Music",
                thumbnailUrl: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&h=281&fit=crop",
                duration: 3600,
                viewCount: 5_100_000,
                downloadDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                fileSize: 280 * 1024 * 1024,
                quality: .medium,
                isWatched: true
            )
        ]
    }
}