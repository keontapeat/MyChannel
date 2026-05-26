//
//  PixabayService.swift
//  MyChannel
//
//  Pixabay API integration for free stock images/videos.
//  Search, category browsing, editorial picks.
//

import Foundation

struct PixabayImage: Codable, Identifiable {
    let id: Int
    let tags: String
    let previewURL: String
    let webFormatURL: String
    let largeImageURL: String
    let views: Int
    let downloads: Int
    let user: String
}

@MainActor
final class PixabayService: ObservableObject {
    static let shared = PixabayService()
    private let apiKey = (ProcessInfo.processInfo.environment["PIXABAY_API_KEY"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    private init() {}
    @Published private(set) var images: [PixabayImage] = []

    func search(query: String, perPage: Int = 20, imageType: String = "photo") async throws {
        guard !apiKey.isEmpty else { return }
        var components = URLComponents(string: "https://pixabay.com/api/")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "image_type", value: imageType)
        ]
        let (data, _) = try await URLSession.configured.data(from: components.url!)
        struct Raw: Decodable { let hits: [RawH]? }
        struct RawH: Decodable { let id: Int; let tags: String; let previewURL: String; let webformatURL: String; let largeImageURL: String; let views: Int; let downloads: Int; let user: String }
        let r = try JSONDecoder().decode(Raw.self, from: data)
        images = (r.hits ?? []).map { PixabayImage(id: $0.id, tags: $0.tags, previewURL: $0.previewURL, webFormatURL: $0.webformatURL, largeImageURL: $0.largeImageURL, views: $0.views, downloads: $0.downloads, user: $0.user) }
    }
}
