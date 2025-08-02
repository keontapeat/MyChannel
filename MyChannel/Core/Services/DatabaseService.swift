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
    
    // MARK: - Watch History
    func saveToWatchHistory(_ video: Video, watchTime: TimeInterval = 0) async throws {
        let historyItem = WatchHistoryItem(
            videoId: video.id,
            videoTitle: video.title,
            creatorName: video.creator.displayName,
            thumbnailURL: video.thumbnailURL,
            watchedAt: Date(),
            watchTime: watchTime,
            duration: video.duration
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
    func saveAnalyticsEvent(_ event: AnalyticsEvent) async throws {
        if let encoded = try? encoder.encode(event) {
            let key = "analytics_\(event.timestamp.timeIntervalSince1970)_\(UUID().uuidString)"
            userDefaults.set(encoded, forKey: key)
        }
    }
    
    func fetchAnalyticsEvents(limit: Int = 1000) async throws -> [AnalyticsEvent] {
        var events: [AnalyticsEvent] = []
        
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("analytics_"), 
               let data = userDefaults.data(forKey: key),
               let event = try? decoder.decode(AnalyticsEvent.self, from: data) {
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
struct WatchHistoryItem: Identifiable, Codable {
    let id = UUID()
    let videoId: String
    let videoTitle: String
    let creatorName: String
    let thumbnailURL: String
    let watchedAt: Date
    let watchTime: TimeInterval
    let duration: TimeInterval
    
    var progressPercentage: Double {
        guard duration > 0 else { return 0 }
        return min(1.0, watchTime / duration)
    }
    
    enum CodingKeys: String, CodingKey {
        case videoId, videoTitle, creatorName, thumbnailURL, watchedAt, watchTime, duration
    }
}

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

struct AnalyticsEvent: Codable {
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

#Preview("Database Service Status") {
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