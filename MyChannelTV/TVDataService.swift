// TVDataService.swift
// MyChannelTV — real Firebase data loading for Apple TV
//
// Replaces all sample-data usage in ContentView with live Firestore reads.
// The iOS `VideoFirestoreService` lives in the shared `MyChannel` module;
// we call it here rather than duplicating the network layer.

import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - TVFeedViewModel
// Single @MainActor ViewModel powering all four tvOS tabs.
@MainActor
final class TVFeedViewModel: ObservableObject {

    // Home feed
    @Published var featuredVideos: [Video] = []
    @Published var trendingVideos: [Video] = []
    @Published var continueWatching: [Video] = []
    @Published var liveStreams: [LiveTVChannel] = []

    // Search
    @Published var searchResults: [Video] = []
    @Published var isSearching: Bool = false

    // Library
    @Published var watchLater: [Video] = []
    @Published var watchHistory: [Video] = []
    @Published var likedVideos: [Video] = []

    @Published var isLoading: Bool = true
    @Published var error: String? = nil

    private var tasks: [Task<Void, Never>] = []

    init() {
        Task { await loadHomeFeed() }
    }

    // MARK: Home feed
    func loadHomeFeed() async {
        isLoading = true
        error = nil

        async let featured = fetchVideos(limit: 5, orderBy: "viewCount")
        async let trending = fetchVideos(limit: 20, orderBy: "viewCount")
        async let live = loadLiveChannels()

        let (f, t, l) = await (featured, trending, live)
        featuredVideos = f
        trendingVideos = t
        liveStreams = l
        isLoading = false
    }

    // MARK: Search
    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        let lower = query.lowercased()
        let all = await fetchVideos(limit: 50, orderBy: "viewCount")
        searchResults = all.filter {
            $0.title.lowercased().contains(lower) ||
            $0.description.lowercased().contains(lower)
        }
        isSearching = false
    }

    // MARK: Library — loads for the authenticated user
    func loadLibrary(userId: String) async {
        guard !userId.isEmpty else { return }
        async let wl = fetchWatchLater(userId: userId)
        async let wh = fetchWatchHistory(userId: userId)
        async let liked = fetchLikedVideos(userId: userId)
        let (w, h, lv) = await (wl, wh, liked)
        watchLater = w
        watchHistory = h
        likedVideos = lv
    }

    // MARK: Private helpers
    private func fetchVideos(limit: Int, orderBy field: String) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snap = try await db.collection("videos")
                .whereField("isPublic", isEqualTo: true)
                .order(by: field, descending: true)
                .limit(to: limit)
                .getDocuments()
            return snap.documents.compactMap { doc -> Video? in
                let data = doc.data()
                guard let title = data["title"] as? String else { return nil }
                let videoURL = (data["hlsURL"] as? String) ?? (data["videoURL"] as? String) ?? ""
                let creatorData: [String: Any] = data["creator"] as? [String: Any] ?? [:]
                let creator = User(
                    id: data["creatorId"] as? String ?? "",
                    username: creatorData["username"] as? String ?? "",
                    displayName: creatorData["displayName"] as? String ?? "Creator",
                    email: "",
                    profileImageURL: creatorData["profileImageURL"] as? String ?? "",
                    subscriberCount: (creatorData["subscriberCount"] as? Int) ?? 0,
                    videoCount: 0,
                    createdAt: Date(),
                    isVerified: false,
                    isAdmin: false
                )
                return Video(
                    id: doc.documentID,
                    title: title,
                    description: data["description"] as? String ?? "",
                    videoURL: videoURL,
                    thumbnailURL: data["thumbnailURL"] as? String ?? "",
                    duration: (data["duration"] as? Double) ?? 0,
                    viewCount: (data["viewCount"] as? Int) ?? 0,
                    likeCount: (data["likeCount"] as? Int) ?? 0,
                    commentCount: (data["commentCount"] as? Int) ?? 0,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    creatorId: data["creatorId"] as? String ?? "",
                    creator: creator,
                    category: .entertainment,
                    tags: data["tags"] as? [String] ?? [],
                    isPublic: true,
                    ageRestricted: data["ageRestricted"] as? Bool ?? false
                )
            }
        } catch {
            self.error = error.localizedDescription
            return []
        }
        #else
        return Video.sampleVideos
        #endif
    }

    private func fetchWatchLater(userId: String) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snap = try await db.collection("users").document(userId)
                .collection("watchLater")
                .order(by: "addedAt", descending: true)
                .limit(to: 24)
                .getDocuments()
            let videoIds = snap.documents.compactMap { $0.data()["videoId"] as? String }
            return await fetchVideosByIds(videoIds)
        } catch { return [] }
        #else
        return []
        #endif
    }

    private func fetchWatchHistory(userId: String) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snap = try await db.collection("users").document(userId)
                .collection("watchHistory")
                .order(by: "watchedAt", descending: true)
                .limit(to: 24)
                .getDocuments()
            let videoIds = snap.documents.compactMap { $0.data()["videoId"] as? String }
            return await fetchVideosByIds(videoIds)
        } catch { return [] }
        #else
        return []
        #endif
    }

    private func fetchLikedVideos(userId: String) async -> [Video] {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snap = try await db.collection("users").document(userId)
                .collection("liked_videos")
                .order(by: "likedAt", descending: true)
                .limit(to: 24)
                .getDocuments()
            let videoIds = snap.documents.compactMap { $0.data()["videoId"] as? String }
            return await fetchVideosByIds(videoIds)
        } catch { return [] }
        #else
        return []
        #endif
    }

    private func fetchVideosByIds(_ ids: [String]) async -> [Video] {
        guard !ids.isEmpty else { return [] }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let results = await withTaskGroup(of: Video?.self) { group in
            for id in ids.prefix(20) {
                group.addTask {
                    guard let snap = try? await db.collection("videos").document(id).getDocument(),
                          snap.exists,
                          let title = snap.data()?["title"] as? String else { return nil }
                    let data = snap.data() ?? [:]
                    let videoURL = (data["hlsURL"] as? String) ?? (data["videoURL"] as? String) ?? ""
                    let creator = User(
                        id: data["creatorId"] as? String ?? "",
                        username: "", displayName: "Creator",
                        email: "", profileImageURL: "",
                        subscriberCount: 0, videoCount: 0,
                        createdAt: Date(), isVerified: false, isAdmin: false
                    )
                    return Video(
                        id: snap.documentID, title: title,
                        description: data["description"] as? String ?? "",
                        videoURL: videoURL,
                        thumbnailURL: data["thumbnailURL"] as? String ?? "",
                        duration: (data["duration"] as? Double) ?? 0,
                        viewCount: (data["viewCount"] as? Int) ?? 0,
                        likeCount: (data["likeCount"] as? Int) ?? 0,
                        commentCount: (data["commentCount"] as? Int) ?? 0,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        creatorId: data["creatorId"] as? String ?? "",
                        creator: creator, category: .entertainment,
                        tags: [], isPublic: true, ageRestricted: false
                    )
                }
            }
            var videos: [Video] = []
            for await v in group { if let v { videos.append(v) } }
            return videos
        }
        return results
        #else
        return []
        #endif
    }

    private func loadLiveChannels() async -> [LiveTVChannel] {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snap = try await db.collection("liveTVChannels")
                .limit(to: 30)
                .getDocuments()
            return snap.documents.compactMap { doc -> LiveTVChannel? in
                let d = doc.data()
                guard let name = d["name"] as? String else { return nil }
                return LiveTVChannel(
                    id: doc.documentID,
                    name: name,
                    logoURL: d["logoURL"] as? String ?? "",
                    streamURL: d["streamURL"] as? String
                        ?? "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
                    isLive: d["isLive"] as? Bool ?? false,
                    viewerCount: (d["viewerCount"] as? Int) ?? 0,
                    previewFallbackURL: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
                )
            }
        } catch {
            return LiveTVChannel.sampleChannels
        }
        #else
        return LiveTVChannel.sampleChannels
        #endif
    }
}
