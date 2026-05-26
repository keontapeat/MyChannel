//
//  NASAImagesService.swift
//  MyChannel
//
//  NASA Images API integration: APOD, Mars rover, gallery search.
//  Educational content for Flicks.
//

import Foundation

struct NASAImage: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let imageURL: String
    let thumbnailURL: String
    let date: String
    let center: String?
}

@MainActor
final class NASAImagesService: ObservableObject {
    static let shared = NASAImagesService()
    private let apiKey = "DEMO_KEY"
    private init() {}
    @Published private(set) var apod: NASAImage?
    @Published private(set) var searchResults: [NASAImage] = []

    func fetchAPOD(date: String? = nil) async throws {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")!
        var items = [URLQueryItem(name: "api_key", value: apiKey)]
        if let d = date { items.append(URLQueryItem(name: "date", value: d)) }
        components.queryItems = items
        let (data, _) = try await URLSession.configured.data(from: components.url!)
        struct Raw: Decodable { let title: String?; let explanation: String?; let url: String?; let date: String?; let center: String? }
        let r = try JSONDecoder().decode(Raw.self, from: data)
        apod = NASAImage(id: r.date ?? UUID().uuidString, title: r.title ?? "", description: r.explanation ?? "",
            imageURL: r.url ?? "", thumbnailURL: r.url ?? "", date: r.date ?? "", center: r.center)
    }

    func search(query: String, page: Int = 1) async throws {
        var components = URLComponents(string: "https://images-api.nasa.gov/search")!
        components.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "media_type", value: "image"), URLQueryItem(name: "page", value: String(page))]
        let (data, _) = try await URLSession.configured.data(from: components.url!)
        struct RawItem: Decodable { let data: [RawData]?; let links: [RawLink]? }
        struct RawData: Decodable { let title: String?; let description: String?; let date_created: String?; let center: String?; let nasa_id: String? }
        struct RawLink: Decodable { let href: String?; let rel: String? }
        struct RawCollection: Decodable { let items: [RawItem]? }
        struct Raw: Decodable { let collection: RawCollection? }
        let r = try JSONDecoder().decode(Raw.self, from: data)
        searchResults = (r.collection?.items ?? []).compactMap { item in
            guard let d = item.data?.first, let nasaId = d.nasa_id else { return nil }
            let thumb = item.links?.first(where: { $0.rel == "preview" })?.href ?? ""
            let full = item.links?.first?.href ?? ""
            return NASAImage(id: nasaId, title: d.title ?? "", description: d.description ?? "",
                imageURL: full, thumbnailURL: thumb, date: d.date_created ?? "", center: d.center)
        }
    }
}
