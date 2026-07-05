import Foundation
import SwiftData

/// Phase 94: SwiftData Offline Object Cache
/// Uses modern SwiftData to cache user profiles and comments locally.

@Model
final class CachedProfile {
    @Attribute(.unique) var userId: String
    var username: String
    var bio: String
    var lastUpdated: Date
    
    init(userId: String, username: String, bio: String) {
        self.userId = userId
        self.username = username
        self.bio = bio
        self.lastUpdated = Date()
    }
}

@Model
final class CachedComment {
    @Attribute(.unique) var commentId: String
    var videoId: String
    var authorId: String
    var content: String
    var timestamp: Date
    
    init(commentId: String, videoId: String, authorId: String, content: String, timestamp: Date) {
        self.commentId = commentId
        self.videoId = videoId
        self.authorId = authorId
        self.content = content
        self.timestamp = timestamp
    }
}

@MainActor
final class OfflineCacheEngine {
    static let shared = OfflineCacheEngine()
    
    let container: ModelContainer?
    
    private init() {
        do {
            let schema = Schema([CachedProfile.self, CachedComment.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("💾 [OfflineCache] SwiftData container initialized successfully.")
        } catch {
            // 🔥 FIX 2.1(a): Never fatalError on container init — degrade gracefully.
            print("⚠️ [OfflineCache] Failed to initialize SwiftData container (non-fatal): \(error)")
            container = nil
        }
    }
    
    func saveProfile(_ profile: CachedProfile) {
        guard let container = container else { return }
        container.mainContext.insert(profile)
        try? container.mainContext.save()
    }
    
    func getProfile(userId: String) -> CachedProfile? {
        guard let container = container else { return nil }
        let descriptor = FetchDescriptor<CachedProfile>(predicate: #Predicate { $0.userId == userId })
        return try? container.mainContext.fetch(descriptor).first
    }
    
    func saveComment(_ comment: CachedComment) {
        guard let container = container else { return }
        container.mainContext.insert(comment)
        try? container.mainContext.save()
    }
    
    func getComments(for videoId: String) -> [CachedComment] {
        guard let container = container else { return [] }
        let descriptor = FetchDescriptor<CachedComment>(
            predicate: #Predicate { $0.videoId == videoId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? container.mainContext.fetch(descriptor)) ?? []
    }
}
