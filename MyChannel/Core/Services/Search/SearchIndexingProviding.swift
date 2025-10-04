import Foundation

protocol SearchIndexingProviding {
    func buildIndex(from videos: [Video], creators: [User])
    func searchWithinContent(videoId: String, query: String) async -> [VideoSearchResult]
}

final class DefaultSearchIndexer: SearchIndexingProviding {
    private var videoIndex: [String: [String]] = [:]
    private var creatorIndex: [String: [String]] = [:]

    func buildIndex(from videos: [Video], creators: [User]) {
        for video in videos {
            let text = (video.title + " " + video.description + " " + video.tags.joined(separator: " ")).lowercased()
            let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            for word in words where !word.isEmpty {
                videoIndex[word, default: []].append(video.id)
            }
        }
        for creator in creators {
            let text = (creator.displayName + " " + creator.username + " " + (creator.bio ?? "")).lowercased()
            let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            for word in words where !word.isEmpty {
                creatorIndex[word, default: []].append(creator.id)
            }
        }
    }

    func searchWithinContent(videoId: String, query: String) async -> [VideoSearchResult] {
        return []
    }
}


