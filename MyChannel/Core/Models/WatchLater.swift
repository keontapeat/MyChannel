//
//  WatchLater.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - Watch Later Item Model
struct WatchLaterItem: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let videoId: String
    let addedAt: Date
    let watchProgress: Double // 0.0 to 1.0
    let isWatched: Bool
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        videoId: String,
        addedAt: Date = Date(),
        watchProgress: Double = 0.0,
        isWatched: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.videoId = videoId
        self.addedAt = addedAt
        self.watchProgress = watchProgress
        self.isWatched = isWatched
    }
    
    // MARK: - Equatable
    static func == (lhs: WatchLaterItem, rhs: WatchLaterItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Watch Later Stats
struct WatchLaterStats: Codable, Equatable {
    let totalItems: Int
    let unwatchedItems: Int
    let watchedItems: Int
    let averageWatchProgress: Double
    let totalWatchTime: TimeInterval
    
    init(
        totalItems: Int = 0,
        unwatchedItems: Int = 0,
        watchedItems: Int = 0,
        averageWatchProgress: Double = 0.0,
        totalWatchTime: TimeInterval = 0.0
    ) {
        self.totalItems = totalItems
        self.unwatchedItems = unwatchedItems
        self.watchedItems = watchedItems
        self.averageWatchProgress = averageWatchProgress
        self.totalWatchTime = totalWatchTime
    }
    
    var completionRate: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(watchedItems) / Double(totalItems)
    }
    
    // MARK: - Equatable
    static func == (lhs: WatchLaterStats, rhs: WatchLaterStats) -> Bool {
        lhs.totalItems == rhs.totalItems &&
        lhs.unwatchedItems == rhs.unwatchedItems &&
        lhs.watchedItems == rhs.watchedItems
    }
}

// MARK: - Watch Later Service Interface
protocol WatchLaterServiceProtocol {
    func addToWatchLater(videoId: String, userId: String) async throws -> WatchLaterItem
    func removeFromWatchLater(videoId: String, userId: String) async throws
    func isInWatchLater(videoId: String, userId: String) async throws -> Bool
    func getWatchLaterItems(for userId: String) async throws -> [WatchLaterItem]
    func updateWatchProgress(itemId: String, progress: Double) async throws -> WatchLaterItem
    func markAsWatched(itemId: String) async throws -> WatchLaterItem
    func clearWatchedItems(for userId: String) async throws
    func getWatchLaterStats(for userId: String) async throws -> WatchLaterStats
}

// MARK: - Mock Watch Later Service
class MockWatchLaterService: WatchLaterServiceProtocol, ObservableObject {
    @Published var watchLaterItems: [WatchLaterItem] = WatchLaterItem.sampleItems
    @Published var isLoading = false
    
    func addToWatchLater(videoId: String, userId: String) async throws -> WatchLaterItem {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Check if already exists
        if watchLaterItems.contains(where: { $0.videoId == videoId && $0.userId == userId }) {
            throw NSError(domain: "WatchLaterError", code: 409, userInfo: [NSLocalizedDescriptionKey: "Video already in Watch Later"])
        }
        
        let item = WatchLaterItem(userId: userId, videoId: videoId)
        
        await MainActor.run {
            watchLaterItems.append(item)
        }
        
        return item
    }
    
    func removeFromWatchLater(videoId: String, userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        await MainActor.run {
            watchLaterItems.removeAll { $0.videoId == videoId && $0.userId == userId }
        }
    }
    
    func isInWatchLater(videoId: String, userId: String) async throws -> Bool {
        return watchLaterItems.contains { $0.videoId == videoId && $0.userId == userId }
    }
    
    func getWatchLaterItems(for userId: String) async throws -> [WatchLaterItem] {
        return watchLaterItems
            .filter { $0.userId == userId }
            .sorted { $0.addedAt > $1.addedAt } // Most recently added first
    }
    
    func updateWatchProgress(itemId: String, progress: Double) async throws -> WatchLaterItem {
        guard let index = watchLaterItems.firstIndex(where: { $0.id == itemId }) else {
            throw NSError(domain: "WatchLaterError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Watch Later item not found"])
        }
        
        let updatedItem = WatchLaterItem(
            id: watchLaterItems[index].id,
            userId: watchLaterItems[index].userId,
            videoId: watchLaterItems[index].videoId,
            addedAt: watchLaterItems[index].addedAt,
            watchProgress: min(max(progress, 0.0), 1.0), // Clamp between 0 and 1
            isWatched: progress >= 0.95 // Consider watched if 95% complete
        )
        
        await MainActor.run {
            watchLaterItems[index] = updatedItem
        }
        
        return updatedItem
    }
    
    func markAsWatched(itemId: String) async throws -> WatchLaterItem {
        guard let index = watchLaterItems.firstIndex(where: { $0.id == itemId }) else {
            throw NSError(domain: "WatchLaterError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Watch Later item not found"])
        }
        
        let updatedItem = WatchLaterItem(
            id: watchLaterItems[index].id,
            userId: watchLaterItems[index].userId,
            videoId: watchLaterItems[index].videoId,
            addedAt: watchLaterItems[index].addedAt,
            watchProgress: 1.0,
            isWatched: true
        )
        
        await MainActor.run {
            watchLaterItems[index] = updatedItem
        }
        
        return updatedItem
    }
    
    func clearWatchedItems(for userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        await MainActor.run {
            watchLaterItems.removeAll { $0.userId == userId && $0.isWatched }
        }
    }
    
    func getWatchLaterStats(for userId: String) async throws -> WatchLaterStats {
        let userItems = watchLaterItems.filter { $0.userId == userId }
        let watchedItems = userItems.filter { $0.isWatched }
        let unwatchedItems = userItems.filter { !$0.isWatched }
        
        let averageProgress = userItems.isEmpty ? 0.0 : userItems.reduce(0.0) { $0 + $1.watchProgress } / Double(userItems.count)
        
        return WatchLaterStats(
            totalItems: userItems.count,
            unwatchedItems: unwatchedItems.count,
            watchedItems: watchedItems.count,
            averageWatchProgress: averageProgress,
            totalWatchTime: Double(userItems.count) * 600 // Assuming 10 min average per video
        )
    }
}

// MARK: - Watch Later Extensions
extension WatchLaterItem {
    var progressPercentage: Int {
        return Int(watchProgress * 100)
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: addedAt, relativeTo: Date())
    }
}

// MARK: - Sample Data
extension WatchLaterItem {
    static let sampleItems: [WatchLaterItem] = [
        WatchLaterItem(
            userId: "user-1",
            videoId: Video.sampleVideos[0].id,
            addedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
            watchProgress: 0.3
        ),
        WatchLaterItem(
            userId: "user-1",
            videoId: Video.sampleVideos[1].id,
            addedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            watchProgress: 0.0
        ),
        WatchLaterItem(
            userId: "user-1",
            videoId: Video.sampleVideos[2].id,
            addedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
            watchProgress: 0.85
        ),
        WatchLaterItem(
            userId: "user-1",
            videoId: Video.sampleVideos[3].id,
            addedAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            watchProgress: 1.0,
            isWatched: true
        ),
        WatchLaterItem(
            userId: "user-1",
            videoId: Video.sampleVideos[4].id,
            addedAt: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date(),
            watchProgress: 0.0
        )
    ]
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            Text("Watch Later System")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // Stats Overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Watch Later Stats")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("12")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("8")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Unwatched")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("4")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Watched")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Sample Watch Later Items
            ForEach(WatchLaterItem.sampleItems.prefix(3)) { item in
                HStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 68)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "clock")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sample Video Title")
                            .font(.headline)
                            .lineLimit(2)
                        
                        Text("Added \(item.timeAgo)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            if item.watchProgress > 0 {
                                ProgressView(value: item.watchProgress)
                                    .frame(width: 60)
                                Text("\(item.progressPercentage)%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Not started")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if item.isWatched {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}