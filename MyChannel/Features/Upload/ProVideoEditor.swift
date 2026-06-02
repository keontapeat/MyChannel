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

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum EditorTool {
    case trim, split, speed, filters, audio, text, transitions, effects
}

// MARK: - Editor Filters

/// Core Image-backed video filters that actually render into the export.
enum VideoFilter: String, CaseIterable, Identifiable {
    case none = "None"
    case vivid = "Vivid"
    case mono = "Mono"
    case noir = "Noir"
    case sepia = "Sepia"
    case cool = "Cool"
    case warm = "Warm"
    case fade = "Fade"

    var id: String { rawValue }

    /// Builds the filtered image for a given source frame.
    func apply(to input: CIImage) -> CIImage {
        switch self {
        case .none:
            return input
        case .vivid:
            let f = CIFilter(name: "CIColorControls")!
            f.setValue(input, forKey: kCIInputImageKey)
            f.setValue(1.25, forKey: kCIInputSaturationKey)
            f.setValue(1.05, forKey: kCIInputContrastKey)
            return f.outputImage ?? input
        case .mono:
            let f = CIFilter(name: "CIPhotoEffectMono")!
            f.setValue(input, forKey: kCIInputImageKey)
            return f.outputImage ?? input
        case .noir:
            let f = CIFilter(name: "CIPhotoEffectNoir")!
            f.setValue(input, forKey: kCIInputImageKey)
            return f.outputImage ?? input
        case .sepia:
            let f = CIFilter(name: "CISepiaTone")!
            f.setValue(input, forKey: kCIInputImageKey)
            f.setValue(0.85, forKey: kCIInputIntensityKey)
            return f.outputImage ?? input
        case .cool:
            let f = CIFilter(name: "CITemperatureAndTint")!
            f.setValue(input, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 5500, y: 0), forKey: "inputNeutral")
            f.setValue(CIVector(x: 7500, y: 0), forKey: "inputTargetNeutral")
            return f.outputImage ?? input
        case .warm:
            let f = CIFilter(name: "CITemperatureAndTint")!
            f.setValue(input, forKey: kCIInputImageKey)
            f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            f.setValue(CIVector(x: 5000, y: 0), forKey: "inputTargetNeutral")
            return f.outputImage ?? input
        case .fade:
            let f = CIFilter(name: "CIPhotoEffectFade")!
            f.setValue(input, forKey: kCIInputImageKey)
            return f.outputImage ?? input
        }
    }
}

// MARK: - Text Overlay

/// A text overlay that is burned into the exported video.
struct EditorTextOverlay: Identifiable {
    let id: String
    var text: String
    /// Normalized position (0...1) within the video frame.
    var position: CGPoint
    var fontSize: CGFloat
    var color: Color
    /// Seconds from the start the overlay appears.
    var startTime: TimeInterval
    /// Seconds from the start the overlay disappears.
    var endTime: TimeInterval

    init(
        id: String = UUID().uuidString,
        text: String,
        position: CGPoint = CGPoint(x: 0.5, y: 0.5),
        fontSize: CGFloat = 48,
        color: Color = .white,
        startTime: TimeInterval = 0,
        endTime: TimeInterval = .greatestFiniteMagnitude
    ) {
        self.id = id
        self.text = text
        self.position = position
        self.fontSize = fontSize
        self.color = color
        self.startTime = startTime
        self.endTime = endTime
    }
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

    // Effects state (these now actually render into the export)
    @Published var selectedFilter: VideoFilter = .none
    @Published var playbackSpeed: Double = 1.0
    @Published var volume: Float = 1.0
    @Published var textOverlays: [EditorTextOverlay] = []
    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var lastExportedURL: URL?
    
    // Video clips (for split functionality)
    @Published var clips: [VideoClip] = []
    
    private var videoAsset: AVAsset?
    private var videoURL: URL?
    private var existingVideo: Video?
    private var timeObserver: Any?

    /// Live-preview filtered playback via an AVPlayerItem video composition.
    private let previewCIContext = CIContext()
    
    // Store references for cleanup in deinit (nonisolated access)
    private nonisolated(unsafe) var playerForCleanup: AVPlayer?
    private nonisolated(unsafe) var observerForCleanup: Any?
    
    func loadVideo(url: URL, existing: Video?) {
        self.existingVideo = existing
        self.videoURL = url
        
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
        
        // Store references for cleanup in deinit
        playerForCleanup = player
        observerForCleanup = timeObserver
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
        guard let url = videoURL else { return }
        let clip1 = VideoClip(
            id: UUID().uuidString,
            url: url,
            duration: currentTime,
            startTime: 0
        )
        let clip2 = VideoClip(
            id: UUID().uuidString,
            url: url,
            duration: duration - currentTime,
            startTime: currentTime
        )
        clips.append(contentsOf: [clip1, clip2])
        print("✂️ Split video at \(currentTime)s")
    }
    
    func applyTrim() {
        // Trim the video to trimStart...trimEnd range
        print("✂️ Trimming video from \(trimStart)s to \(trimEnd)s")
    }
    
    func applySpeedChange(speed: Double) {
        playbackSpeed = max(0.25, min(speed, 4.0))
        if isPlaying {
            player?.rate = Float(playbackSpeed)
        }
        print("⚡️ Applied speed change: \(playbackSpeed)x")
    }

    func applyFilter(_ filter: VideoFilter) {
        selectedFilter = filter
        // Re-apply live preview composition so the change is visible immediately.
        applyLivePreviewComposition()
        print("🎨 Applied filter: \(filter.rawValue)")
    }

    func adjustVolume(level: Float) {
        volume = max(0, min(level, 1))
        player?.volume = volume
        print("🔊 Adjusted volume to \(volume)")
    }

    func addTextOverlay(text: String, at time: TimeInterval) {
        let overlay = EditorTextOverlay(
            text: text,
            startTime: time,
            endTime: duration > 0 ? duration : .greatestFiniteMagnitude
        )
        textOverlays.append(overlay)
        print("📝 Added text overlay '\(text)' at \(time)s")
    }

    func removeTextOverlay(id: String) {
        textOverlays.removeAll { $0.id == id }
    }

    func updateTextOverlay(_ overlay: EditorTextOverlay) {
        if let idx = textOverlays.firstIndex(where: { $0.id == overlay.id }) {
            textOverlays[idx] = overlay
        }
    }

    /// Applies the currently selected filter to the live player preview so the
    /// user sees exactly what will be exported.
    private func applyLivePreviewComposition() {
        guard let item = player?.currentItem, let asset = videoAsset else { return }
        guard selectedFilter != .none else {
            item.videoComposition = nil
            return
        }
        let filter = selectedFilter
        let context = previewCIContext
        item.videoComposition = AVMutableVideoComposition(asset: asset) { request in
            let source = request.sourceImage.clampedToExtent()
            let output = filter.apply(to: source).cropped(to: request.sourceImage.extent)
            request.finish(with: output, context: context)
        }
    }
    
    // MARK: - Export

    func exportVideo(quality: ExportQuality) async {
        guard let asset = videoAsset else {
            print("❌ No video asset to export")
            return
        }

        isExporting = true
        exportProgress = 0
        defer { isExporting = false }

        print("📹 Exporting video at \(quality.rawValue)...")

        do {
            // Build a composition so speed + audio volume can be baked in.
            let composition = AVMutableComposition()
            guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                print("❌ No video track")
                return
            }

            let fullDuration = try await asset.load(.duration)
            let start = CMTime(seconds: trimStart, preferredTimescale: 600)
            let end = CMTime(seconds: trimEnd > 0 ? trimEnd : fullDuration.seconds, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: start, end: end)

            guard let compVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                print("❌ Could not create composition video track")
                return
            }
            try compVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
            compVideoTrack.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

            // Audio (respect volume / mute)
            if volume > 0, let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                if let compAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) {
                    try compAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
                }
            }

            // Speed ramp (scale the inserted range)
            if playbackSpeed != 1.0 {
                let scaledDuration = CMTimeMultiplyByFloat64(timeRange.duration, multiplier: 1.0 / playbackSpeed)
                composition.scaleTimeRange(
                    CMTimeRange(start: .zero, duration: timeRange.duration),
                    toDuration: scaledDuration
                )
            }

            // Video composition: filter + text overlays burned in.
            let naturalSize = try await sourceVideoTrack.load(.naturalSize)
            let renderSize = renderSize(for: naturalSize, transform: compVideoTrack.preferredTransform)
            let filter = selectedFilter
            let overlays = textOverlays
            let context = previewCIContext

            let videoComposition = AVMutableVideoComposition(asset: composition) { request in
                var image = request.sourceImage.clampedToExtent()
                if filter != .none {
                    image = filter.apply(to: image)
                }
                // Burn in text overlays active at this time.
                let t = request.compositionTime.seconds
                let activeOverlays = overlays.filter { t >= $0.startTime && t <= $0.endTime }
                if !activeOverlays.isEmpty {
                    image = Self.composite(overlays: activeOverlays, on: image, renderSize: request.sourceImage.extent.size)
                }
                request.finish(with: image.cropped(to: request.sourceImage.extent), context: context)
            }
            videoComposition.renderSize = renderSize

            // Export
            guard let exportSession = AVAssetExportSession(asset: composition, presetName: preset(for: quality)) else {
                print("❌ Failed to create export session")
                return
            }
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("edited_\(UUID().uuidString).mp4")
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            exportSession.videoComposition = videoComposition
            exportSession.shouldOptimizeForNetworkUse = true

            // Progress polling
            let progressTask = Task { @MainActor in
                while exportSession.status == .exporting || exportSession.status == .waiting {
                    exportProgress = Double(exportSession.progress)
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }

            await exportSession.export()
            progressTask.cancel()
            exportProgress = 1.0

            if exportSession.status == .completed {
                print("✅ Export completed: \(outputURL)")
                lastExportedURL = outputURL
                if let existing = existingVideo {
                    await updateExistingVideo(existing, with: outputURL)
                }
            } else {
                print("❌ Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
            }
        } catch {
            print("❌ Export error: \(error.localizedDescription)")
        }
    }

    /// Composites text overlays onto a CIImage by rendering them with Core Graphics.
    nonisolated private static func composite(
        overlays: [EditorTextOverlay],
        on image: CIImage,
        renderSize: CGSize
    ) -> CIImage {
        let size = renderSize == .zero ? image.extent.size : renderSize
        guard size.width > 0, size.height > 0 else { return image }

        let renderer = UIGraphicsImageRenderer(size: size)
        let overlayImage = renderer.image { ctx in
            for overlay in overlays {
                let uiColor = UIColor(overlay.color)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: overlay.fontSize, weight: .bold),
                    .foregroundColor: uiColor,
                    .strokeColor: UIColor.black.withAlphaComponent(0.6),
                    .strokeWidth: -3.0
                ]
                let attrString = NSAttributedString(string: overlay.text, attributes: attributes)
                let textSize = attrString.size()
                let x = (overlay.position.x * size.width) - textSize.width / 2
                // CoreGraphics origin is top-left here (UIGraphicsImageRenderer).
                let y = (overlay.position.y * size.height) - textSize.height / 2
                attrString.draw(at: CGPoint(x: x, y: y))
            }
        }

        guard let cgOverlay = overlayImage.cgImage else { return image }
        // Flip overlay to match CIImage's bottom-left origin coordinate space.
        var overlayCI = CIImage(cgImage: cgOverlay)
        overlayCI = overlayCI.transformed(by: CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -size.height))
        return overlayCI.composited(over: image)
    }

    /// Returns the upright render size given a track's preferred transform.
    nonisolated private func renderSize(for naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
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
            let uploadedVideo = try await VideoStreamingService.shared.uploadVideo(
                url: newURL,
                title: video.title,
                description: video.description
            )
            
            // Update Firestore
            try await VideoFirestoreService.shared.updateVideoURL(videoId: video.id, newURL: uploadedVideo.videoURL)
            
            print("✅ Video updated successfully!")
        } catch {
            print("❌ Failed to update video: \(error)")
        }
    }
    
    deinit {
        // Use nonisolated(unsafe) stored references for cleanup
        if let observer = observerForCleanup {
            playerForCleanup?.removeTimeObserver(observer)
        }
    }
}

// MARK: - Firestore Extension for Video URL Updates
// 🔥 PERFORMANCE FIX: Removed duplicate updateVideoMetadata - already exists in VideoFirestoreService
extension VideoFirestoreService {
    func updateVideoURL(videoId: String, newURL: String) async throws {
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("videos").document(videoId)
        try await ref.updateData([
            "videoURL": newURL,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        print("✅ Video URL updated in Firestore")
        #endif
    }
}

