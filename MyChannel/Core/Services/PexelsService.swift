import Foundation

final class PexelsService {
    static let shared = PexelsService()
    private init() {}

    struct PexelsVideosResponse: Decodable {
        struct Video: Decodable {
            struct File: Decodable { let link: String; let file_type: String?; let quality: String? }
            let id: Int
            let url: String
            let image: String
            let video_files: [File]
        }
        let videos: [Video]
    }

    func search(query: String, perPage: Int = 20, apiKey: String) async throws -> [FreeMovie] {
        guard !apiKey.isEmpty else { return [] }
        var comps = URLComponents(string: "https://api.pexels.com/videos/search")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        var req = URLRequest(url: comps.url!)
        req.addValue(apiKey, forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(PexelsVideosResponse.self, from: data)
        return decoded.videos.compactMap { v in
            guard let link = v.video_files.first?.link, let _ = URL(string: link) else { return nil }
            return FreeMovie(
                id: "pexels-\(v.id)",
                title: "Pexels #\(v.id)",
                posterURL: v.image,
                backdropURL: v.image,
                overview: v.url,
                releaseDate: "1900-01-01",
                runtime: 90,
                genre: [.documentary],
                rating: "Unrated",
                imdbRating: 7.0,
                streamingSource: .pexels,
                streamURL: link,
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


