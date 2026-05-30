//
//  LocalDatabaseService.swift
//  MyChannel
//
//  Manages the SwiftData container and background syncing
//

import Foundation
import SwiftData

@available(iOS 17, *)
@MainActor
final class LocalDatabaseService {
    static let shared = LocalDatabaseService()
    
    let container: ModelContainer
    
    private init() {
        do {
            let schema = Schema([OfflineVideo.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("💾 [LocalDatabase] SwiftData Container initialized successfully")
        } catch {
            fatalError("🚨 [LocalDatabase] Could not initialize SwiftData container: \(error)")
        }
    }
    
    func saveVideosToOfflineCache(_ videos: [Video]) {
        let context = container.mainContext
        
        for video in videos {
            // Check if exists
            let id = video.id
            var descriptor = FetchDescriptor<OfflineVideo>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            
            do {
                if let _ = try context.fetch(descriptor).first {
                    continue // Already saved
                }
                
                let offline = OfflineVideo(
                    id: video.id,
                    title: video.title,
                    videoURL: video.videoURL,
                    thumbnailURL: video.thumbnailURL,
                    creatorDisplayName: video.creator.displayName,
                    creatorProfileImage: video.creator.profileImageURL ?? ""
                )
                context.insert(offline)
            } catch {
                print("⚠️ [LocalDatabase] Failed to save video \(video.id): \(error)")
            }
        }
        
        do {
            try context.save()
            print("💾 [LocalDatabase] Synced \(videos.count) videos to local disk")
        } catch {
            print("🚨 [LocalDatabase] Failed to save context: \(error)")
        }
    }
    
    func fetchOfflineVideos() -> [OfflineVideo] {
        let context = container.mainContext
        var descriptor = FetchDescriptor<OfflineVideo>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        descriptor.fetchLimit = 50
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("🚨 [LocalDatabase] Failed to fetch offline videos: \(error)")
            return []
        }
    }
}
