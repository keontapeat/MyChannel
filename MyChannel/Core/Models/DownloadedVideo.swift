//
//  DownloadedVideo.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import Foundation
import SwiftUI

// MARK: - Downloaded Video Model
struct DownloadedVideo: Identifiable, Codable {
    let id: String
    let title: String
    let channelName: String
    let thumbnailURL: String
    let duration: Int // in seconds
    let quality: DownloadQuality
    let fileSize: Int64 // in bytes
    let downloadDate: Date
    let isWatched: Bool
    
    init(
        id: String = UUID().uuidString,
        title: String,
        channelName: String,
        thumbnailURL: String,
        duration: Int,
        quality: DownloadQuality,
        fileSize: Int64,
        downloadDate: Date = Date(),
        isWatched: Bool = false
    ) {
        self.id = id
        self.title = title
        self.channelName = channelName
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.quality = quality
        self.fileSize = fileSize
        self.downloadDate = downloadDate
        self.isWatched = isWatched
    }
    
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .binary)
    }
    
    var downloadTimeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: downloadDate, relativeTo: Date())
    }
}

// MARK: - Download Quality Enum
enum DownloadQuality: String, CaseIterable, Codable {
    case low = "360p"
    case medium = "720p"
    case high = "1080p"
    case ultra = "4K"
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .low: return "Good for data saving"
        case .medium: return "Balanced quality and size"
        case .high: return "High quality, larger file"
        case .ultra: return "Ultra HD, very large file"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .orange
        case .medium: return .blue
        case .high: return .purple
        case .ultra: return .pink
        }
    }
}

// MARK: - Sample Data
extension DownloadedVideo {
    static var sampleDownloads: [DownloadedVideo] {
        return [
            DownloadedVideo(
                id: "1",
                title: "Swift UI Advanced Techniques",
                channelName: "Tech Channel",
                thumbnailURL: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=500&h=281&fit=crop",
                duration: 1200,
                quality: .high,
                fileSize: 250 * 1024 * 1024, // 250 MB
                downloadDate: Date(),
                isWatched: false
            ),
            DownloadedVideo(
                id: "2",
                title: "iOS Development Best Practices",
                channelName: "Developer Hub",
                thumbnailURL: "https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=500&h=281&fit=crop",
                duration: 900,
                quality: .medium,
                fileSize: 180 * 1024 * 1024, // 180 MB
                downloadDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                isWatched: true
            ),
            DownloadedVideo(
                id: "3",
                title: "Building Modern Apps with SwiftUI",
                channelName: "Code Masters",
                thumbnailURL: "https://images.unsplash.com/photo-1517077304055-6e89abbf09b0?w=500&h=281&fit=crop",
                duration: 1800,
                quality: .ultra,
                fileSize: 450 * 1024 * 1024, // 450 MB
                downloadDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                isWatched: false
            ),
            DownloadedVideo(
                id: "4",
                title: "EPIC Gaming Moments Compilation",
                channelName: "Pro Gamer Elite",
                thumbnailURL: "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?w=500&h=281&fit=crop",
                duration: 900,
                quality: .high,
                fileSize: 320 * 1024 * 1024, // 320 MB
                downloadDate: Calendar.current.date(byAdding: .hour, value: -12, to: Date()) ?? Date(),
                isWatched: false
            ),
            DownloadedVideo(
                id: "5",
                title: "Chill Beats for Study & Relax",
                channelName: "Chill Vibes Music",
                thumbnailURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&h=281&fit=crop",
                duration: 3600,
                quality: .medium,
                fileSize: 280 * 1024 * 1024, // 280 MB
                downloadDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                isWatched: true
            )
        ]
    }
}

#Preview {
    ScrollView {
        LazyVStack(spacing: 12) {
            Text("Downloaded Videos")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            ForEach(DownloadedVideo.sampleDownloads) { video in
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .overlay(
                                Image(systemName: "play.rectangle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            )
                    }
                    .frame(width: 80, height: 45)
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text(video.channelName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(video.quality.displayName)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(video.quality.color.opacity(0.2))
                                .foregroundColor(video.quality.color)
                                .cornerRadius(4)
                            
                            Text(video.formattedFileSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(video.formattedDuration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if video.isWatched {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}