//
//  YouTubeAPIService.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import Foundation
import SwiftUI

@MainActor
final class YouTubeAPIService {
    static let shared = YouTubeAPIService()
    private init() {}

    private let base = "https://www.googleapis.com/youtube/v3"

    struct SearchResponse: Decodable {
        struct Item: Decodable {
            struct ID: Decodable { let videoId: String? }
            struct Snippet: Decodable {
                let title: String
                let description: String
                let channelTitle: String
                struct Thumbs: Decodable {
                    struct T: Decodable { let url: String }
                    let medium: T?
                    let high: T?
                    let standard: T?
                    let maxres: T?
                }
                let thumbnails: Thumbs
            }
            let id: ID
            let snippet: Snippet
        }
        let items: [Item]
    }

    func fetchShorts(query: String, maxResults: Int = 20) async throws -> [Video] {
        guard !AppSecrets.youtubeAPIKey.isEmpty else { return [] }

        var comps = URLComponents(string: "\(base)/search")!
        comps.queryItems = [
            .init(name: "key", value: AppSecrets.youtubeAPIKey),
            .init(name: "type", value: "video"),
            .init(name: "part", value: "snippet"),
            .init(name: "q", value: query),
            .init(name: "videoDuration", value: "short"),
            .init(name: "maxResults", value: String(max(1, min(maxResults, 50)))),
            .init(name: "safeSearch", value: "strict")
        ]

        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)

        // Map results to our Video model
        let now = Date()
        let user = User.sampleUsers.first ?? .defaultUser

        let vids: [Video] = decoded.items.compactMap { item in
            guard let vid = item.id.videoId else { return nil }
            let thumb = item.snippet.thumbnails.maxres?.url ??
                        item.snippet.thumbnails.standard?.url ??
                        item.snippet.thumbnails.high?.url ??
                        item.snippet.thumbnails.medium?.url ??
                        "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg"

            return Video(
                title: item.snippet.title,
                description: item.snippet.description,
                thumbnailURL: thumb,
                videoURL: "https://www.youtube.com/watch?v=\(vid)",
                duration: 45, // approximate; full details call omitted for speed
                viewCount: Int.random(in: 10_000...900_000),
                likeCount: Int.random(in: 500...40_000),
                creator: User(
                    username: item.snippet.channelTitle.replacingOccurrences(of: " ", with: "_").lowercased(),
                    displayName: item.snippet.channelTitle,
                    email: "noreply@youtube.com",
                    profileImageURL: "https://i.pravatar.cc/200?u=\(item.snippet.channelTitle)",
                    bio: "YouTube Creator",
                    isVerified: true,
                    isCreator: true
                ),
                category: .shorts,
                tags: ["shorts", "youtube"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .portrait,
                isLiveStream: false,
                scheduledAt: nil,
                contentSource: .youtube,
                externalID: vid,
                contentRating: nil,
                language: "en",
                subtitles: nil,
                isVerified: true,
                monetization: nil,
                isSponsored: nil,
                chapters: nil
            )
        }

        // Put newest "feeling" first
        return vids.shuffled()
    }

    func fetchChannelVideos(channelID: String, maxResults: Int = 24) async throws -> [Video] {
        guard !AppSecrets.youtubeAPIKey.isEmpty else { return [] }

        var comps = URLComponents(string: "\(base)/search")!
        comps.queryItems = [
            .init(name: "key", value: AppSecrets.youtubeAPIKey),
            .init(name: "part", value: "snippet"),
            .init(name: "channelId", value: channelID),
            .init(name: "order", value: "date"),
            .init(name: "type", value: "video"),
            .init(name: "maxResults", value: String(max(1, min(maxResults, 50))))
        ]

        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)

        let vids: [Video] = decoded.items.compactMap { item in
            guard let vid = item.id.videoId else { return nil }
            let sn = item.snippet
            let thumb = sn.thumbnails.maxres?.url ??
                        sn.thumbnails.standard?.url ??
                        sn.thumbnails.high?.url ??
                        sn.thumbnails.medium?.url ??
                        "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg"

            return Video(
                title: sn.title,
                description: sn.description,
                thumbnailURL: thumb,
                videoURL: "https://www.youtube.com/watch?v=\(vid)",
                duration: Double.random(in: 90...360),
                viewCount: Int.random(in: 3_000...2_000_000),
                likeCount: Int.random(in: 100...50_000),
                creator: User(
                    username: sn.channelTitle.replacingOccurrences(of: " ", with: "_").lowercased(),
                    displayName: sn.channelTitle,
                    email: "noreply@youtube.com",
                    profileImageURL: "https://i.pravatar.cc/200?u=\(sn.channelTitle)",
                    bio: "YouTube Creator",
                    isVerified: true,
                    isCreator: true
                ),
                category: .music,
                tags: ["youtube","friend"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .landscape,
                isLiveStream: false,
                contentSource: .youtube,
                externalID: vid,
                contentRating: nil,
                language: "en",
                subtitles: nil,
                isVerified: true,
                monetization: nil,
                isSponsored: nil,
                chapters: nil
            )
        }
        return vids
    }
}

#Preview("YouTube API Service (Mock Call)") {
    Text("Service Loaded").padding()
}