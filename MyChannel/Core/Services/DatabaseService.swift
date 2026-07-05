//
//  DatabaseService.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import CoreData
import Combine
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - Database Service
@MainActor
class DatabaseService: ObservableObject {
    static let shared = DatabaseService()
    
    @Published var isReady: Bool = false
    @Published var isLoading: Bool = false
    
    // For now, we'll use UserDefaults for simple persistence
    // In a full implementation, this would use Core Data
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        setupDatabase()
    }
    
    // MARK: - Setup
    private func setupDatabase() {
        // Initialize simple storage
        isReady = true
        
        // Setup periodic cleanup
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.cleanupOldData()
            }
        }
    }
    
    // MARK: - User Management
    func saveUser(_ user: User) async throws {
        if let encoded = try? encoder.encode(user) {
            userDefaults.set(encoded, forKey: "user_\(user.id)")
        }
    }
    
    func fetchUser(id: String) async throws -> User? {
        guard let data = userDefaults.data(forKey: "user_\(id)"),
              let user = try? decoder.decode(User.self, from: data) else {
            return nil
        }
        return user
    }
    
    func fetchAllUsers() async throws -> [User] {
        var users: [User] = []
        
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("user_"), 
               let data = userDefaults.data(forKey: key),
               let user = try? decoder.decode(User.self, from: data) {
                users.append(user)
            }
        }
        
        return users.sorted { $0.displayName < $1.displayName }
    }
    
    // MARK: - Video Management
    func saveVideo(_ video: Video) async throws {
        if let encoded = try? encoder.encode(video) {
            userDefaults.set(encoded, forKey: "video_\(video.id)")
        }
    }
    
    func fetchVideo(id: String) async throws -> Video? {
        guard let data = userDefaults.data(forKey: "video_\(id)"),
              let video = try? decoder.decode(Video.self, from: data) else {
            return nil
        }
        return video
    }
    
    func deleteVideo(id: String) async throws {
        userDefaults.removeObject(forKey: "video_\(id)")
    }
    
    func fetchVideos(limit: Int = 50, offset: Int = 0) async throws -> [Video] {
        var videos: [Video] = []
        
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("video_"), 
               let data = userDefaults.data(forKey: key),
               let video = try? decoder.decode(Video.self, from: data) {
                videos.append(video)
            }
        }
        
        // Sort by creation date and apply pagination
        let sortedVideos = videos.sorted { $0.createdAt > $1.createdAt }
        let startIndex = min(offset, sortedVideos.count)
        let endIndex = min(offset + limit, sortedVideos.count)
        
        return Array(sortedVideos[startIndex..<endIndex])
    }
    
    func fetchVideosByCreator(creatorId: String) async throws -> [Video] {
        var videos: [Video] = []
        
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("video_"), 
               let data = userDefaults.data(forKey: key),
               let video = try? decoder.decode(Video.self, from: data),
               video.creator.id == creatorId {
                videos.append(video)
            }
        }
        
        return videos.sorted { $0.createdAt > $1.createdAt }
    }
    
    func searchVideos(query: String) async throws -> [Video] {
        var videos: [Video] = []
        let lowercaseQuery = query.lowercased()
        
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("video_"), 
               let data = userDefaults.data(forKey: key),
               let video = try? decoder.decode(Video.self, from: data) {
                
                if video.title.lowercased().contains(lowercaseQuery) ||
                   video.description.lowercased().contains(lowercaseQuery) ||
                   video.tags.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
                    videos.append(video)
                }
            }
        }
        
        return videos.sorted { $0.viewCount > $1.viewCount }
    }

    // MARK: - Story Management
    func saveStory(_ story: Story) async throws {
        // 1. Cache locally for instant UI
        if let encoded = try? encoder.encode(story) {
            userDefaults.set(encoded, forKey: "story_\(story.id)")
        }
        // 2. Persist to Firestore so all users/devices see the story
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        guard let authUID = Auth.auth().currentUser?.uid else {
            print("⚠️ [DatabaseService] Not signed in — skipping Firestore story save")
            return
        }
        let db = Firestore.firestore()
        let expiresAt = story.expiresAt
        let audience = story.audience ?? "public"
        let data: [String: Any] = [
            "id": story.id,
            "creatorId": authUID,
            "mediaURL": story.mediaURL,
            "mediaType": story.mediaType.rawValue,
            "duration": story.duration,
            "caption": story.caption as Any,
            "text": story.text as Any,
            "backgroundColor": story.backgroundColor as Any,
            "textColor": story.textColor as Any,
            "audience": audience,
            "isActive": true,
            "isPublic": audience == "public",
            "viewCount": story.viewCount,
            "isLive": false,
            "createdAt": Timestamp(date: story.createdAt),
            "expiresAt": Timestamp(date: expiresAt),
        ]
        try await db.collection("stories").document(story.id).setData(data, merge: true)
        #endif
    }
    
    func deleteStory(id: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("stories").document(id).delete()
        print("✅ [DatabaseService] Deleted story \(id) from Firestore")
        #else
        print("⚠️ [DatabaseService] Cannot delete story: Firestore unavailable")
        #endif
    }

    func archiveStory(id: String) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("stories").document(id).updateData(["archived": true, "status": "archived"])
        print("✅ [DatabaseService] Archived story \(id)")
        #else
        print("⚠️ [DatabaseService] Cannot archive story: Firestore unavailable")
        #endif
    }
    
    func fetchStoriesByCreator(creatorId: String, includeExpired: Bool = false) async throws -> [Story] {
        var stories: [Story] = []

        // 1. Try Firestore first — simple single-field query (no composite index needed)
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("stories")
                .whereField("creatorId", isEqualTo: creatorId)
                .getDocuments()
            print("📖 [DatabaseService] fetchStoriesByCreator: found \(snapshot.documents.count) docs for creator \(creatorId)")
            for doc in snapshot.documents {
                if let story = storyFromFirestoreDoc(doc) {
                    let isArchived = doc.data()["archived"] as? Bool == true
                    if !isArchived && (includeExpired || !story.isExpired) {
                        stories.append(story)
                    }
                } else {
                    print("⚠️ [DatabaseService] Could not parse story doc: \(doc.documentID) data: \(doc.data())")
                }
            }
            if !stories.isEmpty {
                print("✅ [DatabaseService] Returning \(stories.count) stories for creator \(creatorId)")
                return stories.sorted { $0.createdAt > $1.createdAt }
            }
        } catch {
            print("⚠️ [DatabaseService] Firestore fetchStoriesByCreator failed: \(error.localizedDescription)")
        }
        #endif

        // 2. Fallback to local UserDefaults cache
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("story_"),
               let data = userDefaults.data(forKey: key),
               let story = try? decoder.decode(Story.self, from: data),
               story.creatorId == creatorId {
                if includeExpired || !story.isExpired {
                    stories.append(story)
                }
            }
        }
        print("📖 [DatabaseService] fetchStoriesByCreator fallback: \(stories.count) from UserDefaults")
        return stories.sorted { $0.createdAt > $1.createdAt }
    }
    
    func fetchActiveStoriesForCreators(_ creatorIds: [String]) async throws -> [Story] {
        var stories: [Story] = []

        // 1. Try Firestore first — simple 'in' query, filter expiry client-side
        #if canImport(FirebaseFirestore)
        if !creatorIds.isEmpty {
            do {
                let db = Firestore.firestore()
                // Firestore 'in' queries support up to 30 elements
                let chunks = stride(from: 0, to: creatorIds.count, by: 30).map {
                    Array(creatorIds[$0..<min($0 + 30, creatorIds.count)])
                }
                for chunk in chunks {
                    let snapshot = try await db.collection("stories")
                        .whereField("creatorId", in: chunk)
                        .getDocuments()
                    print("📖 [DatabaseService] fetchActiveStoriesForCreators: \(snapshot.documents.count) docs for chunk of \(chunk.count) creators")
                    for doc in snapshot.documents {
                        let isArchived = doc.data()["archived"] as? Bool == true
                        if let story = storyFromFirestoreDoc(doc), !story.isExpired, !isArchived {
                            stories.append(story)
                        }
                    }
                }
                if !stories.isEmpty {
                    print("✅ [DatabaseService] Returning \(stories.count) active stories for followed creators")
                    return stories.sorted { $0.createdAt > $1.createdAt }
                }
            } catch {
                print("⚠️ [DatabaseService] Firestore fetchActiveStoriesForCreators failed: \(error.localizedDescription)")
            }
        }
        #endif

        // 2. Fallback to local UserDefaults cache
        let set = Set(creatorIds)
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("story_"),
               let data = userDefaults.data(forKey: key),
               let story = try? decoder.decode(Story.self, from: data),
               set.contains(story.creatorId), !story.isExpired {
                stories.append(story)
            }
        }
        print("📖 [DatabaseService] fetchActiveStoriesForCreators fallback: \(stories.count) from UserDefaults")
        return stories.sorted { $0.createdAt > $1.createdAt }
    }
    
    func fetchAllActiveStories(limit: Int = 50) async throws -> [Story] {
        var stories: [Story] = []

        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            // Simple query — fetch recent stories, filter expiry client-side
            let snapshot = try await db.collection("stories")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()
            print("📖 [DatabaseService] fetchAllActiveStories: \(snapshot.documents.count) total docs from Firestore")
            for doc in snapshot.documents {
                let isArchived = doc.data()["archived"] as? Bool == true
                if let story = storyFromFirestoreDoc(doc), !story.isExpired, !isArchived {
                    stories.append(story)
                } else if storyFromFirestoreDoc(doc) == nil {
                    print("⚠️ [DatabaseService] Could not parse story doc: \(doc.documentID) data: \(doc.data())")
                }
            }
            print("✅ [DatabaseService] fetchAllActiveStories: \(stories.count) non-expired stories")
            if !stories.isEmpty {
                return stories.sorted { $0.createdAt > $1.createdAt }
            }
        } catch {
            print("⚠️ [DatabaseService] Firestore fetchAllActiveStories failed: \(error)")
        }
        #endif

        // Fallback to local cache
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("story_"),
               let data = userDefaults.data(forKey: key),
               let story = try? decoder.decode(Story.self, from: data),
               !story.isExpired {
                stories.append(story)
            }
        }
        print("📖 [DatabaseService] fetchAllActiveStories fallback: \(stories.count) from UserDefaults")
        return stories.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Firestore Story Parsing
    #if canImport(FirebaseFirestore)
    private func storyFromFirestoreDoc(_ doc: DocumentSnapshot) -> Story? {
        return storyFromFirestoreData(doc.data() ?? [:], id: doc.documentID)
    }

    /// Public dictionary-based parser so other views (e.g. the story viewer) can
    /// rebuild a full `Story` — including stickers/polls/links/music — from a
    /// Firestore document's data.
    func storyFromFirestoreData(_ d: [String: Any], id: String) -> Story? {
        guard let creatorId = d["creatorId"] as? String,
              let mediaURL = d["mediaURL"] as? String,
              let mediaTypeRaw = d["mediaType"] as? String,
              let mediaType = Story.MediaType(rawValue: mediaTypeRaw) else {
            return nil
        }
        let duration = d["duration"] as? TimeInterval ?? 15.0
        let caption = d["caption"] as? String
        let text = d["text"] as? String
        let createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let expiresAt = (d["expiresAt"] as? Timestamp)?.dateValue() ?? Calendar.current.date(byAdding: .hour, value: 24, to: createdAt) ?? Date()
        let viewCount = d["viewCount"] as? Int ?? 0
        let backgroundColor = d["backgroundColor"] as? String
        let textColor = d["textColor"] as? String
        let audience = d["audience"] as? String ?? "public"

        // Parse rich interactive content (Instagram parity)
        let music = parseStoryMusic(d["music"])
        let stickers = parseStoryStickers(d["stickers"])
        let polls = parseStoryPolls(d["polls"])
        let links = parseStoryLinks(d["links"])

        return Story(
            id: id,
            creatorId: creatorId,
            mediaURL: mediaURL,
            mediaType: mediaType,
            duration: duration,
            caption: caption,
            text: text,
            createdAt: createdAt,
            expiresAt: expiresAt,
            viewCount: viewCount,
            isViewed: false,
            thumbnail: d["thumbnail"] as? String,
            isLive: d["isLive"] as? Bool ?? false,
            backgroundColor: backgroundColor,
            textColor: textColor,
            music: music,
            stickers: stickers,
            polls: polls,
            links: links,
            audience: audience
        )
    }

    // MARK: - Rich field parsers (mirror StoryService.saveStory serialization)

    private func parseStoryMusic(_ raw: Any?) -> StoryMusic? {
        guard let m = raw as? [String: Any],
              let title = m["title"] as? String,
              let artist = m["artist"] as? String else { return nil }
        return StoryMusic(
            id: m["id"] as? String ?? UUID().uuidString,
            title: title,
            artist: artist,
            previewURL: m["previewURL"] as? String ?? "",
            duration: m["duration"] as? TimeInterval ?? 30.0,
            startTime: m["startTime"] as? TimeInterval ?? 0.0
        )
    }

    private func parseStoryStickers(_ raw: Any?) -> [StorySticker] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap { s in
            guard let typeRaw = s["type"] as? String,
                  let type = StorySticker.StickerType(rawValue: typeRaw) else { return nil }
            return StorySticker(
                id: s["id"] as? String ?? UUID().uuidString,
                type: type,
                x: s["x"] as? Double ?? 0.5,
                y: s["y"] as? Double ?? 0.5,
                scale: s["scale"] as? Double ?? 1.0,
                rotation: s["rotation"] as? Double ?? 0.0,
                data: parseStickerData(s["data"]) ?? .emoji("⭐️")
            )
        }
    }

    private func parseStickerData(_ raw: Any?) -> StickerData? {
        guard let d = raw as? [String: Any], let kind = d["kind"] as? String else { return nil }
        switch kind {
        case "emoji": return .emoji(d["value"] as? String ?? "⭐️")
        case "gif": return .gif(d["value"] as? String ?? "")
        case "location":
            return .location(d["name"] as? String ?? "", d["lat"] as? Double ?? 0, d["lng"] as? Double ?? 0)
        case "hashtag": return .hashtag(d["value"] as? String ?? "")
        case "time": return .time((d["value"] as? Timestamp)?.dateValue() ?? Date())
        case "weather": return .weather(d["condition"] as? String ?? "", d["temperature"] as? String ?? "")
        case "countdown":
            return .countdown(title: d["title"] as? String ?? "Countdown", endTime: (d["endTime"] as? Timestamp)?.dateValue() ?? Date())
        case "poll":
            return .poll(
                question: d["question"] as? String ?? "",
                options: d["options"] as? [String] ?? [],
                votes: d["votes"] as? [Int] ?? []
            )
        default:
            return nil
        }
    }

    private func parseStoryPolls(_ raw: Any?) -> [StoryPoll] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap { p in
            guard let question = p["question"] as? String else { return nil }
            let optionsRaw = p["options"] as? [[String: Any]] ?? []
            let options = optionsRaw.map { o in
                StoryPoll.PollOption(
                    id: o["id"] as? String ?? UUID().uuidString,
                    text: o["text"] as? String ?? "",
                    voteCount: o["voteCount"] as? Int ?? 0,
                    color: o["color"] as? String ?? "#FF6B6B"
                )
            }
            return StoryPoll(
                id: p["id"] as? String ?? UUID().uuidString,
                question: question,
                options: options,
                x: p["x"] as? Double ?? 0.5,
                y: p["y"] as? Double ?? 0.5,
                expiresAt: (p["expiresAt"] as? Timestamp)?.dateValue() ?? Date().addingTimeInterval(86400)
            )
        }
    }

    private func parseStoryLinks(_ raw: Any?) -> [StoryLink] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap { l in
            guard let url = l["url"] as? String, let title = l["title"] as? String else { return nil }
            return StoryLink(
                id: l["id"] as? String ?? UUID().uuidString,
                url: url,
                title: title,
                description: l["description"] as? String,
                imageURL: l["imageURL"] as? String,
                x: l["x"] as? Double ?? 0.5,
                y: l["y"] as? Double ?? 0.85
            )
        }
    }
    #endif

    // MARK: - Watch History
    func saveToWatchHistory(_ video: Video, watchTime: TimeInterval = 0) async throws {
        let historyItem = WatchHistoryItem.fromVideo(
            video,
            watchedAt: Date(),
            progress: video.duration > 0 ? watchTime / video.duration : 0,
            position: watchTime
        )
        
        if let encoded = try? encoder.encode(historyItem) {
            let key = "history_\(video.id)_\(Date().timeIntervalSince1970)"
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    func fetchWatchHistory(limit: Int = 100) async throws -> [WatchHistoryItem] {
        var historyItems: [WatchHistoryItem] = []
        
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("history_"), 
               let data = userDefaults.data(forKey: key),
               let item = try? decoder.decode(WatchHistoryItem.self, from: data) {
                historyItems.append(item)
            }
        }
        
        return historyItems.sorted { $0.watchedAt > $1.watchedAt }.prefix(limit).map { $0 }
    }
    
    func clearWatchHistory() async throws {
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("history_") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    // MARK: - Saved/Liked Videos
    func saveVideoToWatchLater(_ video: Video) async throws {
        let savedItem = SavedVideoItem(
            videoId: video.id,
            videoTitle: video.title,
            creatorName: video.creator.displayName,
            thumbnailURL: video.thumbnailURL,
            savedAt: Date(),
            category: video.category.rawValue
        )
        
        if let encoded = try? encoder.encode(savedItem) {
            userDefaults.set(encoded, forKey: "saved_\(video.id)")
        }
    }
    
    func removeVideoFromWatchLater(_ videoId: String) async throws {
        userDefaults.removeObject(forKey: "saved_\(videoId)")
    }
    
    func fetchSavedVideos() async throws -> [SavedVideoItem] {
        var savedItems: [SavedVideoItem] = []
        
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("saved_"), 
               let data = userDefaults.data(forKey: key),
               let item = try? decoder.decode(SavedVideoItem.self, from: data) {
                savedItems.append(item)
            }
        }
        
        return savedItems.sorted { $0.savedAt > $1.savedAt }
    }
    
    func isVideoSaved(_ videoId: String) async throws -> Bool {
        return userDefaults.data(forKey: "saved_\(videoId)") != nil
    }
    
    // MARK: - Cache Management
    func cacheVideo(_ video: Video, data: Data) async throws {
        // For simplicity, we'll just store the video metadata
        // In a real implementation, you'd store the actual video data
        let key = "cache_\(video.id)"
        userDefaults.set(data, forKey: key)
    }
    
    func getCachedVideo(_ videoId: String) async throws -> Data? {
        return userDefaults.data(forKey: "cache_\(videoId)")
    }
    
    func clearVideoCache() async throws {
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("cache_") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    // MARK: - Analytics & Statistics
    func saveAnalyticsEvent(_ event: LocalAnalyticsEvent) async throws {
        if let encoded = try? encoder.encode(event) {
            let key = "analytics_\(event.timestamp.timeIntervalSince1970)_\(UUID().uuidString)"
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    func fetchAnalyticsEvents(limit: Int = 1000) async throws -> [LocalAnalyticsEvent] {
        var events: [LocalAnalyticsEvent] = []
        
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("analytics_"), 
               let data = userDefaults.data(forKey: key),
               let event = try? decoder.decode(LocalAnalyticsEvent.self, from: data) {
                events.append(event)
            }
        }
        
        return events.sorted { $0.timestamp > $1.timestamp }.prefix(limit).map { $0 }
    }
    
    // MARK: - Data Cleanup
    private func cleanupOldData() async {
        let now = Date()
        let keysToRemove = userDefaults.dictionaryRepresentation().keys.filter { key in
            // Remove old history (older than 90 days)
            if key.hasPrefix("history_") {
                if let timestampString = key.components(separatedBy: "_").last,
                   let timestamp = TimeInterval(timestampString) {
                    let date = Date(timeIntervalSince1970: timestamp)
                    return now.timeIntervalSince(date) > 90 * 24 * 3600 // 90 days
                }
            }
            
            // Remove old analytics (older than 30 days)
            if key.hasPrefix("analytics_") {
                let components = key.components(separatedBy: "_")
                if components.count > 1,
                   let timestamp = TimeInterval(components[1]) {
                    let date = Date(timeIntervalSince1970: timestamp)
                    return now.timeIntervalSince(date) > 30 * 24 * 3600 // 30 days
                }
            }
            
            return false
        }
        
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 Database cleanup completed - removed \(keysToRemove.count) old entries")
        }
    }
    
    // MARK: - Database Statistics
    func getDatabaseStatistics() async throws -> DatabaseStatistics {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        let userCount = allKeys.filter { $0.hasPrefix("user_") }.count
        let videoCount = allKeys.filter { $0.hasPrefix("video_") }.count
        let historyCount = allKeys.filter { $0.hasPrefix("history_") }.count
        let savedCount = allKeys.filter { $0.hasPrefix("saved_") }.count
        let cacheCount = allKeys.filter { $0.hasPrefix("cache_") }.count
        
        // Calculate cache size
        var totalCacheSize: Int64 = 0
        for key in allKeys {
            if key.hasPrefix("cache_"),
               let data = userDefaults.data(forKey: key) {
                totalCacheSize += Int64(data.count)
            }
        }
        
        return DatabaseStatistics(
            userCount: userCount,
            videoCount: videoCount,
            historyCount: historyCount,
            savedCount: savedCount,
            cacheCount: cacheCount,
            totalCacheSize: totalCacheSize
        )
    }
}

// MARK: - Supporting Models
// WatchHistoryItem is defined in Core/Models/WatchHistoryItem.swift

struct SavedVideoItem: Identifiable, Codable {
    let id = UUID()
    let videoId: String
    let videoTitle: String
    let creatorName: String
    let thumbnailURL: String
    let savedAt: Date
    let category: String
    
    enum CodingKeys: String, CodingKey {
        case videoId, videoTitle, creatorName, thumbnailURL, savedAt, category
    }
}

struct LocalAnalyticsEvent: Codable {
    let name: String
    let parameters: [String: String]
    let timestamp: Date
    let userId: String?
    let sessionId: String
}

struct DatabaseStatistics {
    let userCount: Int
    let videoCount: Int
    let historyCount: Int
    let savedCount: Int
    let cacheCount: Int
    let totalCacheSize: Int64
    
    var cacheSizeMB: Double {
        return Double(totalCacheSize) / (1024 * 1024)
    }
}

struct DatabaseService_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Database Service")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Status:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(DatabaseService.shared.isReady ? "Ready" : "Loading")
                        .foregroundColor(DatabaseService.shared.isReady ? .green : .orange)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuration:")
                        .fontWeight(.medium)
                    
                    Text("Storage: UserDefaults (Simplified)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Auto Cleanup: Every hour")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("History Retention: 90 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Analytics Retention: 30 days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}