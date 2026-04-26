//
//  OfflineFirstPlaybackService.swift
//  MyChannel
//
//  Phase 159: Offline-First Playback.
//  Seamless online/offline transition, background download, resume sync.
//

import Foundation
import AVFoundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct OfflineAsset: Codable, Identifiable, Equatable {
    let id: String            // videoId
    let title: String
    let localFileURL: URL
    let originalURL: URL
    let quality: String
    let fileSizeMB: Double
    let downloadedAt: Date
    let expiresAt: Date?
    let resumePositionSec: Double
}

struct SyncRecord: Codable {
    let videoId: String
    let lastWatchedSec: Double
    let watchedOffline: Bool
    let syncedAt: Date
}

// MARK: - Service

@MainActor
final class OfflineFirstPlaybackService: ObservableObject {
    static let shared = OfflineFirstPlaybackService()
    private init() {}

    @Published private(set) var offlineAssets: [OfflineAsset] = []
    @Published private(set) var pendingSyncs: [SyncRecord] = []
    @Published var isOffline: Bool = false
    @Published var totalCacheSizeMB: Double = 0

    private let cacheDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("OfflineVideos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func loadCachedAssets() {
        guard AppConfig.Features.enableOfflineFirstPlayback else { return }
        let decoder = JSONDecoder()
        let indexURL = cacheDirectory.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let assets = try? decoder.decode([OfflineAsset].self, from: data) else { return }
        offlineAssets = assets.filter { FileManager.default.fileExists(atPath: $0.localFileURL.path) }
        totalCacheSizeMB = offlineAssets.reduce(0) { $0 + $1.fileSizeMB }
    }

    func resolvePlaybackURL(for video: Video) -> URL? {
        guard AppConfig.Features.enableOfflineFirstPlayback else { return URL(string: video.videoURL) }
        if let offline = offlineAssets.first(where: { $0.id == video.id }),
           FileManager.default.fileExists(atPath: offline.localFileURL.path) {
            return offline.localFileURL
        }
        return URL(string: video.videoURL)
    }

    func isAvailableOffline(videoId: String) -> Bool {
        offlineAssets.contains { $0.id == videoId }
    }

    func saveResumePosition(videoId: String, timeSec: Double) {
        guard AppConfig.Features.enableOfflineFirstPlayback else { return }
        if let idx = offlineAssets.firstIndex(where: { $0.id == videoId }) {
            let old = offlineAssets[idx]
            offlineAssets[idx] = OfflineAsset(
                id: old.id, title: old.title, localFileURL: old.localFileURL,
                originalURL: old.originalURL, quality: old.quality, fileSizeMB: old.fileSizeMB,
                downloadedAt: old.downloadedAt, expiresAt: old.expiresAt, resumePositionSec: timeSec
            )
        }
        pendingSyncs.append(SyncRecord(videoId: videoId, lastWatchedSec: timeSec, watchedOffline: isOffline, syncedAt: Date()))
        saveIndex()
    }

    func syncPendingRecords() async throws {
        guard AppConfig.Features.enableOfflineFirstPlayback, !pendingSyncs.isEmpty else { return }
        #if canImport(FirebaseFirestore)
        for record in pendingSyncs {
            try await Firestore.firestore().collection("watch_sync").document(record.videoId).setData([
                "videoId": record.videoId, "lastWatchedSec": record.lastWatchedSec,
                "watchedOffline": record.watchedOffline, "syncedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
        #endif
        pendingSyncs.removeAll()
    }

    func deleteAsset(videoId: String) throws {
        guard let asset = offlineAssets.first(where: { $0.id == videoId }) else { return }
        try? FileManager.default.removeItem(at: asset.localFileURL)
        offlineAssets.removeAll { $0.id == videoId }
        totalCacheSizeMB = offlineAssets.reduce(0) { $0 + $1.fileSizeMB }
        saveIndex()
    }

    func clearAll() throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        offlineAssets.removeAll()
        totalCacheSizeMB = 0
    }

    private func saveIndex() {
        let encoder = JSONEncoder()
        let indexURL = cacheDirectory.appendingPathComponent("index.json")
        if let data = try? encoder.encode(offlineAssets) {
            try? data.write(to: indexURL)
        }
    }
}
