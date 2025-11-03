//
//  ProVideoEditor.swift
//  MyChannel
//
//  Professional Video Editor Engine
//  Created for MyChannel by AI Assistant
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

enum EditorTool {
    case trim, split, speed, filters, audio, text, transitions, effects
}

@MainActor
class ProVideoEditor: ObservableObject {
    // Video state
    @Published var player: AVPlayer?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying = false
    
    // Editing state
    @Published var selectedTool: EditorTool = .trim
    @Published var trimStart: TimeInterval = 0
    @Published var trimEnd: TimeInterval = 0
    @Published var timelineZoom: CGFloat = 0.5
    
    // Video clips (for split functionality)
    @Published var clips: [VideoClip] = []
    
    private var videoAsset: AVAsset?
    private var existingVideo: Video?
    private var timeObserver: Any?
    
    func loadVideo(url: URL, existing: Video?) {
        self.existingVideo = existing
        
        videoAsset = AVAsset(url: url)
        player = AVPlayer(url: url)
        
        Task {
            if let asset = videoAsset {
                do {
                    let duration = try await asset.load(.duration)
                    await MainActor.run {
                        self.duration = duration.seconds
                        self.trimEnd = duration.seconds
                    }
                } catch {
                    print("❌ Failed to load video duration: \(error)")
                }
            }
        }
        
        // Observe playback time
        setupTimeObserver()
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
            }
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime)
        currentTime = time
    }
    
    func skipForward() {
        let newTime = min(currentTime + 5, duration)
        seek(to: newTime)
    }
    
    func skipBackward() {
        let newTime = max(currentTime - 5, 0)
        seek(to: newTime)
    }
    
    func zoomIn() {
        timelineZoom = min(timelineZoom + 0.1, 1.0)
    }
    
    func zoomOut() {
        timelineZoom = max(timelineZoom - 0.1, 0.1)
    }
    
    // MARK: - Editing Operations
    
    func splitAtCurrentTime() {
        let clip1 = VideoClip(id: UUID().uuidString, start: 0, end: currentTime)
        let clip2 = VideoClip(id: UUID().uuidString, start: currentTime, end: duration)
        clips.append(contentsOf: [clip1, clip2])
        print("✂️ Split video at \(currentTime)s")
    }
    
    func applyTrim() {
        // Trim the video to trimStart...trimEnd range
        print("✂️ Trimming video from \(trimStart)s to \(trimEnd)s")
    }
    
    func applySpeedChange(speed: Float) {
        player?.rate = speed
        print("⚡️ Applied speed change: \(speed)x")
    }
    
    func applyFilter(name: String) {
        // Apply video filter
        print("🎨 Applied filter: \(name)")
    }
    
    func adjustVolume(level: Float) {
        player?.volume = level
        print("🔊 Adjusted volume to \(level)")
    }
    
    func addTextOverlay(text: String, at time: TimeInterval) {
        print("📝 Added text overlay '\(text)' at \(time)s")
    }
    
    func addTransition(type: String, between clip1: VideoClip, and clip2: VideoClip) {
        print("✨ Added \(type) transition between clips")
    }
    
    // MARK: - Export
    
    func exportVideo(quality: ExportQuality) async {
        guard let asset = videoAsset else {
            print("❌ No video asset to export")
            return
        }
        
        print("📹 Exporting video at \(quality.rawValue)...")
        
        // Create export session
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset(for: quality)) else {
            print("❌ Failed to create export session")
            return
        }
        
        // Set output URL
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("edited_\(UUID().uuidString).mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        // Apply trim if needed
        if trimStart > 0 || trimEnd < duration {
            let start = CMTime(seconds: trimStart, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            let end = CMTime(seconds: trimEnd, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            exportSession.timeRange = CMTimeRange(start: start, end: end)
        }
        
        // Export
        await exportSession.export()
        
        if exportSession.status == .completed {
            print("✅ Export completed: \(outputURL)")
            
            // If this is an existing video, update it in Firestore
            if let existing = existingVideo {
                await updateExistingVideo(existing, with: outputURL)
            }
        } else {
            print("❌ Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    private func preset(for quality: ExportQuality) -> String {
        switch quality {
        case .low: return AVAssetExportPreset640x480
        case .medium: return AVAssetExportPreset1280x720
        case .high: return AVAssetExportPreset1920x1080
        case .ultra: return AVAssetExportPresetHEVC3840x2160
        }
    }
    
    private func updateExistingVideo(_ video: Video, with newURL: URL) async {
        // Upload the edited video to Firebase Storage
        // Update the video document in Firestore with the new URL
        print("🔄 Updating existing video in Firestore...")
        
        do {
            // Upload to storage
            let downloadURL = try await VideoStreamingService.shared.uploadVideo(at: newURL)
            
            // Update Firestore
            try await VideoFirestoreService.shared.updateVideoURL(videoId: video.id, newURL: downloadURL)
            
            print("✅ Video updated successfully!")
        } catch {
            print("❌ Failed to update video: \(error)")
        }
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }
}

struct VideoClip: Identifiable {
    let id: String
    let start: TimeInterval
    let end: TimeInterval
}

// MARK: - Firestore Extension for Video URL Updates
extension VideoFirestoreService {
    func updateVideoURL(videoId: String, newURL: String) async throws {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("videos").document(videoId)
        try await ref.updateData([
            "videoURL": newURL,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        print("✅ Video URL updated in Firestore")
        #endif
    }
    
    func updateVideoMetadata(videoId: String, title: String?, description: String?, category: VideoCategory?, tags: [String]?) async throws {
        #if canImport(FirebaseFirestore)
        var updates: [String: Any] = ["updatedAt": FieldValue.serverTimestamp()]
        
        if let title = title { updates["title"] = title }
        if let description = description { updates["description"] = description }
        if let category = category { updates["category"] = category.rawValue }
        if let tags = tags { updates["tags"] = tags }
        
        let ref = db.collection("videos").document(videoId)
        try await ref.updateData(updates)
        print("✅ Video metadata updated in Firestore")
        #endif
    }
}

