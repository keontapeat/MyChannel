import SwiftUI
import Foundation

// MARK: - Free Movie Model
struct FreeMovie: Identifiable, Codable {
    let id: String
    let title: String
    let posterURL: String
    let backdropURL: String?
    let overview: String
    let releaseDate: String
    let runtime: Int
    let genre: [MovieGenre]
    let rating: String
    let imdbRating: Double
    let streamingSource: StreamingSource
    let streamURL: String
    let trailerURL: String?
    let cast: [String]
    let director: String
    let year: Int
    let language: String
    let country: String
    let isAvailable: Bool
    
    
    
    var formattedRuntime: String {
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var genreString: String {
        genre.map { $0.rawValue.capitalized }.joined(separator: ", ")
    }
}


// MARK: - Multi-source poster fallbacks
extension FreeMovie {
    var archiveIdentifier: String? {
        if id.hasPrefix("ia-") {
            return String(id.dropFirst(3))
        }
        if let range = streamURL.range(of: "/download/") {
            let rest = streamURL[range.upperBound...]
            if let slash = rest.firstIndex(of: "/") {
                return String(rest[..<slash])
            } else {
                return String(rest)
            }
        }
        return nil
    }
    
    var posterCandidates: [URL] {
        var urls: [URL] = []
        
        if !posterURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let u = URL(string: posterURL) {
            urls.append(u)
        }
        
        if let ia = archiveIdentifier,
           let u = URL(string: "https://archive.org/services/img/\(ia)") {
            urls.append(u)
        }
        
        if let t = trailerURL,
           let vid = Self.youtubeID(from: t),
           let u = URL(string: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg") {
            urls.append(u)
        }
        
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }
    
    private static func youtubeID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if url.host?.contains("youtu.be") == true {
            return url.lastPathComponent
        }
        if url.host?.contains("youtube.com") == true {
            if let query = url.query {
                for pair in query.components(separatedBy: "&") {
                    let kv = pair.components(separatedBy: "=")
                    if kv.count == 2, kv[0] == "v" { return kv[1] }
                }
            }
            let comps = url.pathComponents
            if let idx = comps.firstIndex(of: "embed"), idx + 1 < comps.count {
                return comps[idx + 1]
            }
        }
        return nil
    }
}

#Preview {
    VStack {
        ForEach(FreeMovie.sampleMovies.prefix(2)) { movie in
            HStack {
                AsyncImage(url: URL(string: movie.posterURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle().fill(.gray)
                }
                .frame(width: 60, height: 90)
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.headline)
                    Text(movie.streamingSource.displayName)
                        .font(.caption)
                        .foregroundColor(movie.streamingSource.color)
                    Text("⭐ \(movie.imdbRating, specifier: "%.1f")")
                        .font(.caption)
                }
                Spacer()
            }
            .padding()
        }
    }
}