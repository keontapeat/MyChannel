import Foundation

final class PixabayService {
    static let shared = PixabayService()
    private init() {}

    struct PixabayResponse: Decodable {
        struct Hit: Decodable {
            struct Videos: Decodable {
                struct Variant: Decodable { let url: String }
                let large: Variant?
                let medium: Variant?
                let small: Variant?
            }
            let id: Int
            let pageURL: String
            let videos: Videos
            let picture_id: String
        }
        let hits: [Hit]
    }

    func search(query: String, perPage: Int = 20, apiKey: String) async throws -> [FreeMovie] {
        guard !apiKey.isEmpty else { return [] }
        var comps = URLComponents(string: "https://pixabay.com/api/videos/")!
        comps.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let decoded = try JSONDecoder().decode(PixabayResponse.self, from: data)
        return decoded.hits.compactMap { h in
            let urlStr = h.videos.medium?.url ?? h.videos.large?.url ?? h.videos.small?.url
            guard let urlStr, let _ = URL(string: urlStr) else { return nil }
            let thumb = "https://i.vimeocdn.com/video/\(h.picture_id)_295x166.jpg"
            return FreeMovie(
                id: "pixabay-\(h.id)",
                title: "Pixabay #\(h.id)",
                posterURL: thumb,
                backdropURL: thumb,
                overview: h.pageURL,
                releaseDate: "1900-01-01",
                runtime: 90,
                genre: [.documentary],
                rating: "Unrated",
                imdbRating: 7.0,
                streamingSource: .pixabay,
                streamURL: urlStr,
                trailerURL: nil,
                cast: [],
                director: "",
                year: 1900,
                language: "",
                country: "",
                isAvailable: true
            )
        }
    }
}


