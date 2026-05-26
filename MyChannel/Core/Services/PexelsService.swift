//
//  PexelsService.swift
//  MyChannel
//
//  Pexels API integration for stock photos/videos.
//  Search, curated collections, popular content.
//

import Foundation

struct PexelsPhoto: Codable, Identifiable {
    let id: Int
    let width: Int
    let height: Int
    let photographer: String
    let srcMedium: String
    let srcLarge: String
    let alt: String
}

struct PexelsVideo: Codable, Identifiable {
    let id: Int
    let duration: TimeInterval
    let photographer: String
    let videoFiles: [VideoFile]
    struct VideoFile: Codable { let id: Int; let quality: String; let fileType: String; let link: String }
}

@MainActor
final class PexelsService: ObservableObject {
    static let shared = PexelsService()
    private let apiKey = (ProcessInfo.processInfo.environment["PEXELS_API_KEY"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    private init() {}
    @Published private(set) var photos: [PexelsPhoto] = []
    @Published private(set) var videos: [PexelsVideo] = []

    func searchPhotos(query: String, perPage: Int = 15) async throws {
        guard !apiKey.isEmpty else { return }
        var components = URLComponents(string: "https://api.pexels.com/v1/search")!
        components.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "per_page", value: String(perPage))]
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.configured.data(for: request)
        struct Raw: Decodable { let photos: [RawP]? }
        struct RawP: Decodable { let id: Int; let width: Int; let height: Int; let photographer: String; let alt: String?; let src: Src }
        struct Src: Decodable { let medium: String; let large: String }
        let r = try JSONDecoder().decode(Raw.self, from: data)
        photos = (r.photos ?? []).map { PexelsPhoto(id: $0.id, width: $0.width, height: $0.height, photographer: $0.photographer, srcMedium: $0.src.medium, srcLarge: $0.src.large, alt: $0.alt ?? "") }
    }

    func searchVideos(query: String, perPage: Int = 15) async throws {
        guard !apiKey.isEmpty else { return }
        var components = URLComponents(string: "https://api.pexels.com/videos/search")!
        components.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "per_page", value: String(perPage))]
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.configured.data(for: request)
        struct Raw: Decodable { let videos: [RawV]? }
        struct RawV: Decodable { let id: Int; let duration: Double; let user: User; let video_files: [VF]? }
        struct User: Decodable { let name: String }
        struct VF: Decodable { let id: Int; let quality: String?; let file_type: String?; let link: String }
        let r = try JSONDecoder().decode(Raw.self, from: data)
        videos = (r.videos ?? []).map { PexelsVideo(id: $0.id, duration: $0.duration, photographer: $0.user.name,
            videoFiles: ($0.video_files ?? []).map { PexelsVideo.VideoFile(id: $0.id, quality: $0.quality ?? "sd", fileType: $0.file_type ?? "mp4", link: $0.link) }) }
    }
}
