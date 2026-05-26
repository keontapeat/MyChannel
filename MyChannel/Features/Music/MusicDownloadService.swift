//
//  MusicDownloadService.swift
//  MyChannel
//
//  Music offline download service - downloads tracks for offline playback
//

import Foundation
import Combine
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class MusicDownloadService: ObservableObject {
    static let shared = MusicDownloadService()
    
    @Published private(set) var downloadedTracks: [DownloadedTrack] = []
    @Published private(set) var isDownloading: Bool = false
    @Published private(set) var downloadProgress: Double = 0.0
    @Published private(set) var currentDownloadTrackId: String? = nil
    
    private let downloadsKey = "music_downloads"
    
    private init() {
        loadDownloads()
    }
    
    // MARK: - Download Track
    
    func downloadTrack(songId: String, title: String, artist: String, album: String?, artworkURL: String?, duration: TimeInterval, streamURL: URL) async throws {
        isDownloading = true
        currentDownloadTrackId = songId
        downloadProgress = 0.0
        
        #if canImport(FirebaseStorage)
        let storage = Storage.storage()
        let fileName = "\(songId).m4a"
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music")
            .appendingPathComponent(fileName)
        
        // Create Music directory if it doesn't exist
        try? FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Download from Firebase Storage if streamURL is a Firebase Storage URL
        if streamURL.absoluteString.contains("firebasestorage.googleapis.com") {
            let ref = storage.reference(forURL: streamURL.absoluteString)
            let maxSize: Int64 = 50 * 1024 * 1024 // 50MB max
            
            let _ = try await ref.write(toFile: localURL)
            downloadProgress = 1.0
            
            let fileSize = try FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64 ?? 0
            
            let downloadedTrack = DownloadedTrack(
                id: songId,
                title: title,
                artist: artist,
                album: album,
                artworkURL: artworkURL,
                duration: duration,
                downloadedAt: Date(),
                localFileURL: localURL.absoluteString,
                fileSize: fileSize
            )
            
            downloadedTracks.append(downloadedTrack)
            saveDownloads()
        } else {
            // Download from regular URL
            let (data, _) = try await URLSession.configured.data(from: streamURL)
            downloadProgress = 0.8
            try data.write(to: localURL)
            downloadProgress = 1.0
            
            let fileSize = Int64(data.count)
            
            let downloadedTrack = DownloadedTrack(
                id: songId,
                title: title,
                artist: artist,
                album: album,
                artworkURL: artworkURL,
                duration: duration,
                downloadedAt: Date(),
                localFileURL: localURL.absoluteString,
                fileSize: fileSize
            )
            
            downloadedTracks.append(downloadedTrack)
            saveDownloads()
        }
        #else
        // Fallback for non-Firebase builds
        let (data, _) = try await URLSession.configured.data(from: streamURL)
        let fileName = "\(songId).m4a"
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music")
            .appendingPathComponent(fileName)
        
        try? FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: localURL)
        
        let downloadedTrack = DownloadedTrack(
            id: songId,
            title: title,
            artist: artist,
            album: album,
            artworkURL: artworkURL,
            duration: duration,
            downloadedAt: Date(),
            localFileURL: localURL.absoluteString,
            fileSize: Int64(data.count)
        )
        
        downloadedTracks.append(downloadedTrack)
        saveDownloads()
        #endif
        
        isDownloading = false
        currentDownloadTrackId = nil
    }
    
    // MARK: - Delete Download
    
    func deleteDownload(trackId: String) {
        if let index = downloadedTracks.firstIndex(where: { $0.id == trackId }) {
            let track = downloadedTracks[index]
            if let localURL = track.localFileURL, let url = URL(string: localURL) {
                try? FileManager.default.removeItem(at: url)
            }
            downloadedTracks.remove(at: index)
            saveDownloads()
        }
    }
    
    func deleteAllDownloads() {
        for track in downloadedTracks {
            if let localURL = track.localFileURL, let url = URL(string: localURL) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        downloadedTracks.removeAll()
        saveDownloads()
    }
    
    // MARK: - Check Download Status
    
    func isDownloaded(songId: String) -> Bool {
        downloadedTracks.contains { $0.id == songId }
    }
    
    func getLocalURL(for songId: String) -> URL? {
        downloadedTracks.first { $0.id == songId }.flatMap { track in
            track.localFileURL.flatMap { URL(string: $0) }
        }
    }
    
    // MARK: - Storage
    
    func getTotalStorageUsed() -> Int64 {
        downloadedTracks.reduce(0) { $0 + $1.fileSize }
    }
    
    func getFormattedTotalStorage() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: getTotalStorageUsed())
    }
    
    // MARK: - Persistence
    
    private func saveDownloads() {
        if let encoded = try? JSONEncoder().encode(downloadedTracks) {
            UserDefaults.standard.set(encoded, forKey: downloadsKey)
        }
    }
    
    private func loadDownloads() {
        if let data = UserDefaults.standard.data(forKey: downloadsKey),
           let decoded = try? JSONDecoder().decode([DownloadedTrack].self, from: data) {
            // Verify files still exist
            downloadedTracks = decoded.filter { track in
                guard let localURL = track.localFileURL,
                      let url = URL(string: localURL) else { return false }
                return FileManager.default.fileExists(atPath: url.path)
            }
            saveDownloads() // Save to remove any missing files
        }
    }
}
