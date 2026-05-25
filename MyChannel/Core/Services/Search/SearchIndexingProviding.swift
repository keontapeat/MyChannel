import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

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
        guard AppConfig.Features.enableSearchIndexingPipeline else { return [] }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snapshot = try? await db.collection("videos").document(videoId).getDocument()
        guard let data = snapshot?.data(),
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let tags = data["tags"] as? [String] else { return [] }
        let text = (title + " " + description + " " + tags.joined(separator: " ")).lowercased()
        let queryLower = query.lowercased()
        var results: [VideoSearchResult] = []
        let words = queryLower.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let matches = words.filter { text.contains($0) }
        if !matches.isEmpty {
            let video = Video(
                id: videoId,
                title: title,
                description: description,
                thumbnailURL: data["thumbnailURL"] as? String ?? "",
                videoURL: data["videoURL"] as? String ?? "",
                duration: data["duration"] as? Double ?? 0,
                viewCount: data["viewCount"] as? Int ?? 0,
                likeCount: data["likeCount"] as? Int ?? 0,
                commentCount: data["commentCount"] as? Int ?? 0,
                creator: User.sampleUsers.first ?? User.defaultUser,
                category: .entertainment
            )
            results.append(VideoSearchResult(
                video: video,
                relevanceScore: Double(matches.count) / Double(max(words.count, 1)),
                matchingFields: ["title", "description", "tags"],
                highlights: []
            ))
        }
        return results
        #else
        return []
        #endif
    }
}


