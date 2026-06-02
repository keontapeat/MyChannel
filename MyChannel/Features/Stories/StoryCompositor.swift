//
//  StoryCompositor.swift
//  MyChannel
//
//  🖼️ STORY COMPOSITOR
//  Bakes editable overlays (text, stickers, drawings) onto the captured
//  photo/video so the posted story matches exactly what the user composed.
//  This is what gives the creator true Instagram-style WYSIWYG parity.
//

import UIKit
import SwiftUI
import AVFoundation
import CoreImage

/// A snapshot of everything the user placed on the editing canvas.
struct StoryOverlayPlan {
    let elements: [EditableElement]
    let drawingPaths: [DrawingPath]

    /// The size of the on-screen editing canvas the normalized positions were
    /// captured against. Used only as an aspect reference.
    let canvasSize: CGSize

    var isEmpty: Bool {
        elements.isEmpty && drawingPaths.isEmpty
    }
}

enum StoryCompositor {
    /// Instagram stories render at 9:16. We composite at 1080x1920.
    static let renderSize = CGSize(width: 1080, height: 1920)

    // MARK: - Image Compositing

    /// Renders `baseImage` aspect-filled into a 9:16 canvas with all overlays baked in.
    static func composeImage(baseImage: UIImage, plan: StoryOverlayPlan) -> UIImage {
        let size = renderSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Black backdrop (Instagram letterboxes onto black when needed).
            UIColor.black.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            // Draw the base media aspect-fill.
            drawAspectFill(baseImage, in: CGRect(origin: .zero, size: size), context: cg)

            // Draw vector strokes, then text/sticker elements on top.
            drawPaths(plan.drawingPaths, canvasSize: plan.canvasSize, targetSize: size, context: cg)
            drawElements(plan.elements, targetSize: size, context: cg)
        }
    }

    // MARK: - Drawing helpers

    private static func drawAspectFill(_ image: UIImage, in rect: CGRect, context: CGContext) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            image.draw(in: rect)
            return
        }
        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2
        )
        image.draw(in: CGRect(origin: origin, size: drawSize))
    }

    private static func drawElements(_ elements: [EditableElement], targetSize: CGSize, context: CGContext) {
        // The editor's reference width for font sizing is ~390pt; scale up to canvas.
        let fontScale = targetSize.width / 390.0

        for element in elements {
            let center = CGPoint(
                x: element.position.x * targetSize.width,
                y: element.position.y * targetSize.height
            )

            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: CGFloat(element.rotation * .pi / 180.0))
            context.scaleBy(x: element.scale, y: element.scale)

            switch element.type {
            case .text(let text):
                drawTextElement(
                    text,
                    color: UIColor(element.color ?? .white),
                    font: uiFont(for: element.font ?? .bold, scale: fontScale),
                    backgroundStyle: element.backgroundStyle ?? .none,
                    fontScale: fontScale
                )
            case .sticker(let sticker):
                drawStickerElement(sticker, fontScale: fontScale)
            case .drawing:
                break // strokes are drawn separately
            }

            context.restoreGState()
        }
    }

    private static func drawTextElement(
        _ text: String,
        color: UIColor,
        font: UIFont,
        backgroundStyle: TextBackgroundStyle,
        fontScale: CGFloat
    ) {
        let display = text.isEmpty ? " " : text
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        // Neon / outline get a stroke + glow for legibility.
        if case .outline = backgroundStyle {
            attributes[.strokeColor] = UIColor.white
            attributes[.strokeWidth] = -3.0
        }

        let maxWidth = renderSize.width * 0.86
        let bounding = (display as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        let padding = 18 * fontScale
        let boxSize = CGSize(width: bounding.width + padding * 2, height: bounding.height + padding * 2)
        let boxRect = CGRect(
            x: -boxSize.width / 2,
            y: -boxSize.height / 2,
            width: boxSize.width,
            height: boxSize.height
        )

        switch backgroundStyle {
        case .none, .outline:
            break
        case .solid:
            let path = UIBezierPath(roundedRect: boxRect, cornerRadius: 12 * fontScale)
            UIColor.black.withAlphaComponent(0.6).setFill()
            path.fill()
        case .gradient:
            drawGradient(in: boxRect, cornerRadius: 12 * fontScale)
        }

        let textRect = CGRect(
            x: -bounding.width / 2,
            y: -bounding.height / 2,
            width: bounding.width,
            height: bounding.height
        )
        (display as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }

    private static func drawGradient(in rect: CGRect, cornerRadius: CGFloat) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        let clip = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        clip.addClip()
        let colors = [UIColor.systemPurple.cgColor, UIColor.systemPink.cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.maxX, y: rect.maxY),
                options: []
            )
        }
        ctx.restoreGState()
    }

    private static func drawStickerElement(_ sticker: Sticker, fontScale: CGFloat) {
        // Emoji stickers render the emoji glyph; custom/animated fall back to a star glyph.
        let glyph: String
        if sticker.category == .emoji, !sticker.imageName.isEmpty {
            glyph = sticker.imageName
        } else if let image = UIImage(named: sticker.imageName) {
            let side = 120 * fontScale
            image.draw(in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
            return
        } else {
            glyph = "⭐️"
        }

        let font = UIFont.systemFont(ofSize: 90 * fontScale)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (glyph as NSString).size(withAttributes: attributes)
        let rect = CGRect(x: -textSize.width / 2, y: -textSize.height / 2, width: textSize.width, height: textSize.height)
        (glyph as NSString).draw(in: rect, withAttributes: attributes)
    }

    private static func drawPaths(_ paths: [DrawingPath], canvasSize: CGSize, targetSize: CGSize, context: CGContext) {
        guard !paths.isEmpty else { return }
        let refW = canvasSize.width > 0 ? canvasSize.width : 390
        let refH = canvasSize.height > 0 ? canvasSize.height : 844
        let scaleX = targetSize.width / refW
        let scaleY = targetSize.height / refH

        context.setLineCap(.round)
        context.setLineJoin(.round)

        for path in paths where path.points.count > 1 {
            UIColor(path.color).setStroke()
            context.setLineWidth(path.lineWidth * scaleX)
            let bezier = UIBezierPath()
            let first = path.points[0]
            bezier.move(to: CGPoint(x: first.x * scaleX, y: first.y * scaleY))
            for point in path.points.dropFirst() {
                bezier.addLine(to: CGPoint(x: point.x * scaleX, y: point.y * scaleY))
            }
            context.addPath(bezier.cgPath)
            context.strokePath()
        }
    }

    // MARK: - Font mapping (mirrors StoryFont.systemFont)

    private static func uiFont(for storyFont: StoryFont, scale: CGFloat) -> UIFont {
        let size = 32 * scale
        switch storyFont {
        case .bold:
            return roundedFont(size: size, weight: .black) ?? .systemFont(ofSize: size, weight: .black)
        case .classic:
            return UIFont(descriptor: UIFont.systemFont(ofSize: size, weight: .semibold)
                .fontDescriptor.withDesign(.serif) ?? UIFont.systemFont(ofSize: size).fontDescriptor, size: size)
        case .typewriter:
            return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .modern:
            return .systemFont(ofSize: size, weight: .medium)
        case .neon:
            return roundedFont(size: size, weight: .heavy) ?? .systemFont(ofSize: size, weight: .heavy)
        }
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont? {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Video overlay compositing

extension StoryCompositor {
    /// Bakes the overlays onto a video by rendering them into a CALayer tree
    /// layered over the video frames, then exporting a new file.
    /// Returns the original URL unchanged if there is nothing to composite.
    static func composeVideo(url: URL, plan: StoryOverlayPlan) async throws -> URL {
        guard !plan.isEmpty else { return url }

        let asset = AVURLAsset(url: url)
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            return url
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return url }

        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)

        // Preserve audio if present.
        if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let renderSize = orientedSize(naturalSize: naturalSize, transform: preferredTransform)

        // Build the video composition with the layer instruction.
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Overlay layer tree.
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)
        parentLayer.addSublayer(videoLayer)

        let overlayImage = renderOverlayLayerImage(plan: plan, size: renderSize)
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: renderSize)
        overlayLayer.contents = overlayImage.cgImage
        overlayLayer.isGeometryFlipped = false
        parentLayer.addSublayer(overlayLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("story_overlay_\(UUID().uuidString).mp4")

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            return url
        }
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.videoComposition = videoComposition

        do {
            try await export.export()
        } catch {
            print("⚠️ [StoryCompositor] Video overlay export threw: \(error.localizedDescription)")
            return url
        }

        if export.status == .completed {
            return outputURL
        } else {
            // Fall back to the original video rather than failing the whole post.
            print("⚠️ [StoryCompositor] Video overlay export failed: \(export.error?.localizedDescription ?? "unknown")")
            return url
        }
    }

    /// Renders the overlays into a transparent image sized to the video.
    /// Used as CALayer.contents, which maps the bitmap to the layer bounds with
    /// correct orientation (no manual coordinate flipping required).
    private static func renderOverlayLayerImage(plan: StoryOverlayPlan, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            drawPaths(plan.drawingPaths, canvasSize: plan.canvasSize, targetSize: size, context: cg)
            drawElements(plan.elements, targetSize: size, context: cg)
        }
    }

    private static func orientedSize(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }
}
