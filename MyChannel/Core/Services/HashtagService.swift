//
//  HashtagService.swift
//  MyChannel
//
//  Phase 14: Hashtag & Topic aggregation service.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct HashtagTopic: Identifiable, Codable, Hashable {
    let id: String       // lowercased tag
    let tag: String
    var videoCount: Int
    var viewCount: Int
    var relatedTags: [String]

    init(id: String? = nil, tag: String, videoCount: Int = 0, viewCount: Int = 0, relatedTags: [String] = []) {
        self.id = id ?? tag.lowercased().trimmingCharacters(in: .punctuationCharacters)
        self.tag = tag; self.videoCount = videoCount; self.viewCount = viewCount; self.relatedTags = relatedTags
    }
}

@MainActor
final class HashtagService: ObservableObject {
    static let shared = HashtagService()
    private init() {}

    @Published var trendingTags: [HashtagTopic] = []
    @Published var isLoading: Bool = false

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    // MARK: - Fetch trending hashtags

    func fetchTrending(limit: Int = 20) async {
        isLoading = true
        defer { isLoading = false }

        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("hashtags")
                .order(by: "videoCount", descending: true)
                .limit(to: limit)
                .getDocuments()

            trendingTags = snap.documents.compactMap { doc -> HashtagTopic? in
                let d = doc.data()
                return HashtagTopic(
                    id: doc.documentID,
                    tag: d["tag"] as? String ?? doc.documentID,
                    videoCount: d["videoCount"] as? Int ?? 0,
                    viewCount: d["viewCount"] as? Int ?? 0,
                    relatedTags: d["relatedTags"] as? [String] ?? []
                )
            }

            // If Firestore collection empty, derive from video tags
            if trendingTags.isEmpty {
                trendingTags = await deriveTrendingFromVideos(limit: limit)
            }
        } catch {
            trendingTags = await deriveTrendingFromVideos(limit: limit)
        }
        #endif
    }

    // MARK: - Fetch videos for a tag

    func fetchVideos(for tag: String, limit: Int = 30) async -> [Video] {
        let lowered = tag.lowercased().trimmingCharacters(in: .punctuationCharacters)
        #if canImport(FirebaseFirestore)
        do {
            let snap = try await db.collection("videos")
                .whereField("tags", arrayContains: lowered)
                .whereField("visibility", isEqualTo: "public")
                .order(by: "viewCount", descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { doc -> Video? in
                try? doc.data(as: Video.self)
            }
        } catch { return [] }
        #else
        return []
        #endif
    }

    // MARK: - Derive trending from video tags

    private func deriveTrendingFromVideos(limit: Int) async -> [HashtagTopic] {
        let videos = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: 200)
        var tagCounts: [String: (count: Int, views: Int)] = [:]
        for v in videos {
            for t in v.tags {
                let low = t.lowercased()
                let existing = tagCounts[low] ?? (0, 0)
                tagCounts[low] = (existing.count + 1, existing.views + v.viewCount)
            }
        }
        return tagCounts
            .sorted { $0.value.count > $1.value.count }
            .prefix(limit)
            .map { HashtagTopic(tag: "#\($0.key)", videoCount: $0.value.count, viewCount: $0.value.views) }
    }

    // MARK: - Increment on upload

    func incrementTag(_ tag: String) async {
        let lowered = tag.lowercased().trimmingCharacters(in: .punctuationCharacters)
        #if canImport(FirebaseFirestore)
        let ref = db.collection("hashtags").document(lowered)
        try? await ref.setData([
            "tag": "#\(lowered)",
            "videoCount": FieldValue.increment(Int64(1))
        ], merge: true)
        #endif
    }
}
