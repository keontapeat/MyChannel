import Foundation

final class NASAImagesService {
    static let shared = NASAImagesService()
    private init() {}

    struct SearchResponse: Decodable {
        struct Collection: Decodable { let items: [Item] }
        struct Item: Decodable {
            struct DataObj: Decodable { let title: String; let description: String? }
            struct LinkObj: Decodable { let rel: String?; let href: String? }
            let data: [DataObj]
            let links: [LinkObj]?
            let href: String
        }
        let collection: Collection
    }

    func search(query: String, limit: Int = 20) async throws -> [FreeMovie] {
        var comps = URLComponents(string: "https://images-api.nasa.gov/search")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "media_type", value: "video")
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let resp = try JSONDecoder().decode(SearchResponse.self, from: data)
        var items: [FreeMovie] = []
        for item in resp.collection.items.prefix(limit) {
            guard let assetsURL = URL(string: item.href) else { continue }
            do {
                let (adata, _) = try await URLSession.shared.data(from: assetsURL)
                if let arr = try JSONSerialization.jsonObject(with: adata) as? [String],
                   let mp4Str = arr.first(where: { $0.lowercased().hasSuffix(".mp4") }) {
                    let title = item.data.first?.title ?? "NASA Video"
                    let desc = item.data.first?.description ?? ""
                    let thumbStr = item.links?.first(where: { ($0.rel ?? "").contains("preview") })?.href
                    let thumb = thumbStr ?? ""
                    items.append(
                        FreeMovie(
                            id: "nasa-\(abs(title.hashValue))",
                            title: title,
                            posterURL: thumb,
                            backdropURL: thumb,
                            overview: desc,
                            releaseDate: "1900-01-01",
                            runtime: 90,
                            genre: [.documentary],
                            rating: "Unrated",
                            imdbRating: 7.0,
                            streamingSource: .nasa,
                            streamURL: mp4Str,
                            trailerURL: nil,
                            cast: [],
                            director: "",
                            year: 1900,
                            language: "",
                            country: "",
                            isAvailable: true
                        )
                    )
                }
            } catch {
                continue
            }
        }
        return items
    }
}


