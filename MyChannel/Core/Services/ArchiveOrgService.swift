import Foundation
import SwiftUI

final class ArchiveOrgService {
    static let shared = ArchiveOrgService()
    private init() {}

    struct AdvancedSearchResponse: Decodable {
        let response: Inner
        struct Inner: Decodable {
            let docs: [Doc]
        }
    }

    struct Doc: Decodable, Hashable {
        let identifier: String
        let title: String?
        let year: String?
    }

    struct MetadataResponse: Decodable {
        let files: [File]
        let metadata: Meta?
        struct File: Decodable {
            let name: String
            let format: String?
            let size: String?
        }
        struct Meta: Decodable {
            let title: String?
            let description: String?
            let year: String?
            let runtime: String?
            let language: String?
        }
    }

    func fetchPopular(page: Int = 1, rows: Int = 50) async throws -> [FreeMovie] {
        let q = "collection%3Afeature_films+AND+mediatype%3Amovies"
        let urlString = "https://archive.org/advancedsearch.php?q=\(q)&fl[]=identifier&fl[]=title&fl[]=year&rows=\(rows)&page=\(page)&output=json"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(AdvancedSearchResponse.self, from: data)

        var movies: [FreeMovie] = []
        for doc in decoded.response.docs {
            if let movie = try? await buildMovie(for: doc.identifier, titleFallback: doc.title, yearFallback: doc.year) {
                movies.append(movie)
            }
        }
        return movies
    }

    private func buildMovie(for identifier: String, titleFallback: String?, yearFallback: String?) async throws -> FreeMovie {
        let metaURL = URL(string: "https://archive.org/metadata/\(identifier)")!
        let (data, _) = try await URLSession.shared.data(from: metaURL)
        let meta = try JSONDecoder().decode(MetadataResponse.self, from: data)

        let mp4 = meta.files
            .filter { $0.name.lowercased().hasSuffix(".mp4") }
            .sorted { (Int($0.size ?? "0") ?? 0) > (Int($1.size ?? "0") ?? 0) }
            .first

        let direct = mp4.map { "https://archive.org/download/\(identifier)/\($0.name)" } ?? ""

        let poster = "https://archive.org/services/img/\(identifier)"
        let title = meta.metadata?.title ?? titleFallback ?? identifier.replacingOccurrences(of: "_", with: " ")
        let yearInt = Int(meta.metadata?.year ?? yearFallback ?? "0") ?? 0
        let language = meta.metadata?.language ?? "English"

        let runtimeMinutes: Int = {
            if let r = meta.metadata?.runtime,
               let mins = Int(r.filter("0123456789".contains)) {
                return mins
            }
            return 90
        }()

        return FreeMovie(
            id: "ia-\(identifier)",
            title: title,
            posterURL: poster,
            backdropURL: poster,
            overview: meta.metadata?.description ?? "",
            releaseDate: yearInt > 0 ? "\(yearInt)-01-01" : "1900-01-01",
            runtime: runtimeMinutes,
            genre: [.drama],
            rating: "Unrated",
            imdbRating: Double(Int.random(in: 60...85)) / 10.0,
            streamingSource: .internetArchive,
            streamURL: direct,
            trailerURL: nil,
            cast: [],
            director: "",
            year: yearInt,
            language: language,
            country: "US",
            isAvailable: true
        )
    }
}

#Preview("Archive.org fetch demo") {
    VStack(spacing: 12) {
        Text("Fetching 5 public domain films...")
        ProgressView()
    }
    .task {
        _ = try? await ArchiveOrgService.shared.fetchPopular(page: 1, rows: 5)
    }
}