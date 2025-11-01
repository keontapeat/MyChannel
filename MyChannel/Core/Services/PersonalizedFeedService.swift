import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class PersonalizedFeedService: ObservableObject {
    static let shared = PersonalizedFeedService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    func generateForYou(userId: String, limit: Int = 20) async -> [Video] {
        // 1. Fetch user's history + likes for signals
        let history = await HistoryService.shared.fetch(userId: userId, limit: 50)
        let likedCategories = history.map { $0.category }.uniqued()
        let likedCreators = history.map { $0.creator.id }.uniqued()

        // 2. Fetch candidates from Firestore based on signals
        var candidates: [Video] = []

        #if canImport(FirebaseFirestore)
        do {
            // Fetch from liked categories
            for category in likedCategories.prefix(3) {
                let snap = try await db.collection("videos")
                    .whereField("category", isEqualTo: category.rawValue)
                    .whereField("visibility", isEqualTo: "public")
                    .order(by: "createdAt", descending: true)
                    .limit(to: 10)
                    .getDocuments()
                candidates += snap.documents.compactMap { doc in
                    let d = doc.data()
                    return Video(
                        id: doc.documentID,
                        title: d["title"] as? String ?? "",
                        description: d["description"] as? String ?? "",
                        thumbnailURL: d["thumbnailUrl"] as? String ?? "",
                        videoURL: d["videoUrl"] as? String ?? "",
                        duration: (d["duration"] as? Double) ?? 0,
                        viewCount: (d["viewCount"] as? Int) ?? 0,
                        likeCount: (d["likeCount"] as? Int) ?? 0,
                        creator: AppState.shared.currentUser ?? User.defaultUser,
                        category: category
                    )
                }
            }

            // Fetch from subscribed creators
            for creatorId in likedCreators.prefix(5) {
                let snap = try await db.collection("videos")
                    .whereField("ownerUid", isEqualTo: creatorId)
                    .whereField("visibility", isEqualTo: "public")
                    .order(by: "createdAt", descending: true)
                    .limit(to: 5)
                    .getDocuments()
                candidates += snap.documents.compactMap { doc in
                    let d = doc.data()
                    return Video(
                        id: doc.documentID,
                        title: d["title"] as? String ?? "",
                        description: d["description"] as? String ?? "",
                        thumbnailURL: d["thumbnailUrl"] as? String ?? "",
                        videoURL: d["videoUrl"] as? String ?? "",
                        duration: (d["duration"] as? Double) ?? 0,
                        viewCount: (d["viewCount"] as? Int) ?? 0,
                        likeCount: (d["likeCount"] as? Int) ?? 0,
                        creator: AppState.shared.currentUser ?? User.defaultUser,
                        category: .entertainment
                    )
                }
            }
        } catch { }
        #endif

        // 3. Fallback to mock if empty
        if candidates.isEmpty {
            candidates = Video.sampleVideos.filter { vid in
                likedCategories.contains(vid.category) || likedCreators.contains(vid.creator.id)
            }
            if candidates.isEmpty { candidates = Array(Video.sampleVideos.shuffled().prefix(limit)) }
        }

        // 4. Score and rank
        let scored = candidates.map { vid -> (Video, Double) in
            var score = 0.0
            if likedCategories.contains(vid.category) { score += 0.3 }
            if likedCreators.contains(vid.creator.id) { score += 0.4 }
            score += min(Double(vid.viewCount) / 1_000_000, 0.2) // popularity
            let daysSince = Date().timeIntervalSince(vid.createdAt) / (24 * 3600)
            score += max(0, 0.1 - daysSince / 30.0) // recency
            return (vid, score)
        }

        return scored.sorted { $0.1 > $1.1 }.map { $0.0 }.prefix(limit).map { $0 }
    }
    
    func generateHomeFeed(limit: Int = 20) async -> [Video] {
        // Generate a general home feed that includes all uploaded content
        var videos: [Video] = []
        
        #if canImport(FirebaseFirestore)
        do {
            // 🔥 PRIORITY: Fetch all uploaded videos from Firestore
            let snap = try await db.collection("videos")
                .whereField("visibility", isEqualTo: "public")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            videos = snap.documents.compactMap { doc in
                let d = doc.data()
                return Video(
                    id: doc.documentID,
                    title: d["title"] as? String ?? "",
                    description: d["description"] as? String ?? "",
                    thumbnailURL: d["thumbnailUrl"] as? String ?? "",
                    videoURL: d["videoUrl"] as? String ?? "",
                    duration: (d["duration"] as? Double) ?? 0,
                    viewCount: (d["viewCount"] as? Int) ?? 0,
                    likeCount: (d["likeCount"] as? Int) ?? 0,
                    creator: AppState.shared.currentUser ?? User.defaultUser,
                    category: VideoCategory(rawValue: d["category"] as? String ?? "entertainment") ?? .entertainment
                )
            }
        } catch {
            print("Error fetching home feed videos: \(error)")
        }
        #endif
        
        // Fill remaining slots with sample content if needed
        let remainingSlots = max(0, limit - videos.count)
        if remainingSlots > 0 {
            videos.append(contentsOf: Video.sampleVideos.shuffled().prefix(remainingSlots / 2))
            videos.append(contentsOf: SeedCatalogService.shared.seedVideos.shuffled().prefix(remainingSlots / 2))
        }
        
        return Array(videos.prefix(limit))
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

