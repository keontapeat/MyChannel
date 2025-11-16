//
//  MultiClipEngine.swift
//  MyChannel
//
//  🎬 MULTI-CLIP ENGINE
//  Stitch multiple video clips with transitions (like TikTok/Instagram Reels)
//

import SwiftUI
import AVFoundation
import Photos

@MainActor
class MultiClipEngine: ObservableObject {
    
    // MARK: - Published State
    @Published var clips: [VideoClip] = []
    @Published var selectedClip: VideoClip?
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var totalDuration: TimeInterval = 0
    
    // Composition
    private var composition: AVMutableComposition?
    private var videoComposition: AVMutableVideoComposition?
    
    // Maximum clips
    let maxClips = 10
    let maxTotalDuration: TimeInterval = 60.0 // 60 seconds total
    
    // MARK: - Clip Management
    func addClip(url: URL, duration: TimeInterval) {
        guard clips.count < maxClips else {
            print("⚠️ Maximum clips reached")
            return
        }
        
        guard totalDuration + duration <= maxTotalDuration else {
            print("⚠️ Total duration exceeds maximum")
            return
        }
        
        let clip = VideoClip(
            id: UUID().uuidString,
            url: url,
            duration: duration,
            startTime: totalDuration,
            transition: .none,
            speed: 1.0
        )
        
        clips.append(clip)
        totalDuration += duration
        
        HapticManager.shared.impact(style: .medium)
    }
    
    func removeClip(_ clipId: String) {
        guard let index = clips.firstIndex(where: { $0.id == clipId }) else { return }
        
        let removedClip = clips.remove(at: index)
        totalDuration -= removedClip.duration
        
        // Recalculate start times
        var currentTime: TimeInterval = 0
        for i in 0..<clips.count {
            clips[i].startTime = currentTime
            currentTime += clips[i].duration
        }
        
        HapticManager.shared.impact(style: .light)
    }
    
    func reorderClips(from source: IndexSet, to destination: Int) {
        clips.move(fromOffsets: source, toOffset: destination)
        
        // Recalculate start times
        var currentTime: TimeInterval = 0
        for i in 0..<clips.count {
            clips[i].startTime = currentTime
            currentTime += clips[i].duration
        }
    }
    
    func updateClipSpeed(_ clipId: String, speed: Double) {
        guard let index = clips.firstIndex(where: { $0.id == clipId }) else { return }
        
        let oldDuration = clips[index].duration
        clips[index].speed = speed
        clips[index].duration = clips[index].originalDuration / speed
        
        // Update total duration
        totalDuration += (clips[index].duration - oldDuration)
        
        // Recalculate start times for subsequent clips
        var currentTime: TimeInterval = 0
        for i in 0..<clips.count {
            clips[i].startTime = currentTime
            currentTime += clips[i].duration
        }
    }
    
    func setTransition(_ clipId: String, transition: VideoTransition) {
        guard let index = clips.firstIndex(where: { $0.id == clipId }) else { return }
        clips[index].transition = transition
    }
    
    // MARK: - Video Composition
    func createComposition() async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
              let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw MultiClipError.compositionFailed
        }
        
        var currentTime = CMTime.zero
        
        for clip in clips {
            let asset = AVAsset(url: clip.url)
            
            // Get video track
            guard let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                continue
            }
            
            let clipDuration = CMTime(seconds: clip.duration, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: .zero, duration: clipDuration)
            
            // Insert video
            try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
            
            // Insert audio if available
            if let assetAudioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                try? audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
            }
            
            // Apply speed adjustment
            if clip.speed != 1.0 {
                let scaledDuration = CMTime(seconds: clip.originalDuration, preferredTimescale: 600)
                videoTrack.scaleTimeRange(
                    CMTimeRange(start: currentTime, duration: clipDuration),
                    toDuration: scaledDuration
                )
            }
            
            currentTime = CMTimeAdd(currentTime, clipDuration)
        }
        
        self.composition = composition
        return composition
    }
    
    func createVideoComposition() async throws -> AVMutableVideoComposition {
        guard let composition = self.composition else {
            throw MultiClipError.compositionNotReady
        }
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = CGSize(width: 1080, height: 1920) // 9:16 aspect ratio
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30fps
        
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var currentTime = CMTime.zero
        
        for (index, clip) in clips.enumerated() {
            let clipDuration = CMTime(seconds: clip.duration, preferredTimescale: 600)
            
            // Create instruction for this clip
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: currentTime, duration: clipDuration)
            
            // Layer instruction
            guard let track = composition.tracks(withMediaType: .video).first else { continue }
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            
            // Apply transition if not first clip
            if index > 0, clips[index].transition != .none {
                try await applyTransition(
                    clips[index].transition,
                    to: layerInstruction,
                    at: currentTime,
                    duration: 0.5
                )
            }
            
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)
            
            currentTime = CMTimeAdd(currentTime, clipDuration)
        }
        
        videoComposition.instructions = instructions
        self.videoComposition = videoComposition
        
        return videoComposition
    }
    
    // MARK: - Transitions
    private func applyTransition(
        _ transition: VideoTransition,
        to layerInstruction: AVMutableVideoCompositionLayerInstruction,
        at time: CMTime,
        duration: TimeInterval
    ) async throws {
        let transitionDuration = CMTime(seconds: duration, preferredTimescale: 600)
        
        switch transition {
        case .none:
            break
            
        case .fade:
            layerInstruction.setOpacityRamp(
                fromStartOpacity: 0.0,
                toEndOpacity: 1.0,
                timeRange: CMTimeRange(start: time, duration: transitionDuration)
            )
            
        case .slide:
            let slideTransform = CGAffineTransform(translationX: 1080, y: 0)
            layerInstruction.setTransformRamp(
                fromStart: slideTransform,
                toEnd: .identity,
                timeRange: CMTimeRange(start: time, duration: transitionDuration)
            )
            
        case .zoom:
            let zoomTransform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            layerInstruction.setTransformRamp(
                fromStart: zoomTransform,
                toEnd: .identity,
                timeRange: CMTimeRange(start: time, duration: transitionDuration)
            )
            
        case .wipe:
            // Wipe effect using crop
            let startCrop = CGRect(x: 0, y: 0, width: 0, height: 1920)
            let endCrop = CGRect(x: 0, y: 0, width: 1080, height: 1920)
            layerInstruction.setCropRectangleRamp(
                fromStartCropRectangle: startCrop,
                toEndCropRectangle: endCrop,
                timeRange: CMTimeRange(start: time, duration: transitionDuration)
            )
            
        case .dissolve:
            // Similar to fade
            layerInstruction.setOpacityRamp(
                fromStartOpacity: 0.0,
                toEndOpacity: 1.0,
                timeRange: CMTimeRange(start: time, duration: transitionDuration)
            )
        }
    }
    
    // MARK: - Export
    func exportVideo() async throws -> URL {
        guard let composition = self.composition,
              let videoComposition = self.videoComposition else {
            throw MultiClipError.compositionNotReady
        }
        
        isProcessing = true
        processingProgress = 0.0
        defer { isProcessing = false }
        
        // Output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        // Export session
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPreset1920x1080
        ) else {
            throw MultiClipError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Monitor progress
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processingProgress = Double(exportSession.progress)
            }
        }
        
        // Export
        await exportSession.export()
        
        progressTimer.invalidate()
        processingProgress = 1.0
        
        guard exportSession.status == .completed else {
            throw MultiClipError.exportFailed
        }
        
        return outputURL
    }
    
    // MARK: - Thumbnail Generation
    func generateThumbnail(for clipId: String) async throws -> UIImage {
        guard let clip = clips.first(where: { $0.id == clipId }) else {
            throw MultiClipError.clipNotFound
        }
        
        let asset = AVAsset(url: clip.url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: clip.duration / 2, preferredTimescale: 600)
        let cgImage = try await imageGenerator.image(at: time).image
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Video Filter
struct VideoFilter: Identifiable {
    var id = UUID()
    let name: String
    let filterName: String
    let parameters: [String: Any]
}

// MARK: - Errors
enum MultiClipError: LocalizedError {
    case compositionFailed
    case compositionNotReady
    case exportFailed
    case clipNotFound
    case invalidClip
    
    var errorDescription: String? {
        switch self {
        case .compositionFailed: return "Failed to create composition"
        case .compositionNotReady: return "Composition not ready"
        case .exportFailed: return "Export failed"
        case .clipNotFound: return "Clip not found"
        case .invalidClip: return "Invalid clip"
        }
    }
}

