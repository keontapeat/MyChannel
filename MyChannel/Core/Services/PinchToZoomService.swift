//
//  PinchToZoomService.swift
//  MyChannel
//
//  Phase 141: Pinch-to-Zoom & Crop.
//  Pinch gesture for video zoom, crop overlay, aspect ratio switcher.
//  Integrates with VideoDetailView player layer.
//

import Foundation
import UIKit
import AVFoundation

// MARK: - Models

struct ZoomState: Equatable {
    var scale: CGFloat = 1.0
    var offset: CGSize = .zero
    var rotation: CGFloat = 0
    var aspectRatio: AspectRatioMode = .fit
}

enum AspectRatioMode: String, Codable, CaseIterable, Identifiable {
    case fit         // Letterbox (default)
    case fill        // Crop to fill
    case stretch     // Stretch to fill
    case fourThree   // 4:3
    case twentyOneNine // 21:9 (cinematic)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fit: return "Fit"
        case .fill: return "Fill"
        case .stretch: return "Stretch"
        case .fourThree: return "4:3"
        case .twentyOneNine: return "21:9"
        }
    }
    
    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fit, .fourThree, .twentyOneNine: return .resizeAspect
        case .fill: return .resizeAspectFill
        case .stretch: return .resize
        }
    }
}

struct CropRegion: Codable, Equatable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

// MARK: - Service

@MainActor
final class PinchToZoomService: ObservableObject {
    static let shared = PinchToZoomService()
    private init() {}

    @Published var zoomState = ZoomState()
    @Published var isZoomed: Bool = false
    @Published var currentAspectRatio: AspectRatioMode = .fit
    @Published var showAspectRatioHUD: Bool = false

    let minScale: CGFloat = 1.0
    let maxScale: CGFloat = 6.0

    func handlePinch(scale: CGFloat) {
        guard AppConfig.Features.enablePinchToZoom else { return }
        let newScale = max(minScale, min(maxScale, zoomState.scale * scale))
        zoomState.scale = newScale
        isZoomed = newScale > 1.05
    }

    func handlePan(translation: CGSize) {
        guard AppConfig.Features.enablePinchToZoom, isZoomed else { return }
        let maxOffset = (zoomState.scale - 1) * 150
        zoomState.offset = CGSize(
            width: max(-maxOffset, min(maxOffset, zoomState.offset.width + translation.width)),
            height: max(-maxOffset, min(maxOffset, zoomState.offset.height + translation.height))
        )
    }

    func resetZoom() {
        zoomState = ZoomState(aspectRatio: currentAspectRatio)
        isZoomed = false
    }

    func doubleTapZoom(at point: CGPoint, viewSize: CGSize) {
        guard AppConfig.Features.enablePinchToZoom else { return }
        if isZoomed {
            resetZoom()
        } else {
            zoomState.scale = 2.0
            let centerX = viewSize.width / 2
            let centerY = viewSize.height / 2
            zoomState.offset = CGSize(
                width: (centerX - point.x) * 0.5,
                height: (centerY - point.y) * 0.5
            )
            isZoomed = true
        }
    }

    func cycleAspectRatio() {
        guard AppConfig.Features.enablePinchToZoom else { return }
        let modes = AspectRatioMode.allCases
        guard let idx = modes.firstIndex(of: currentAspectRatio) else { return }
        let nextIdx = (idx + 1) % modes.count
        currentAspectRatio = modes[nextIdx]
        zoomState.aspectRatio = currentAspectRatio
        showAspectRatioHUD = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showAspectRatioHUD = false
        }
    }

    func suggestCrop(videoId: String) async throws -> CropRegion? {
        guard AppConfig.Features.enablePinchToZoom else { return nil }
        struct Request: Encodable { let task: String; let videoId: String }
        struct Raw: Decodable { let x: Double?; let y: Double?; let w: Double?; let h: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .videoEditorAIv2, path: "/predict",
            body: Request(task: "suggest_crop", videoId: videoId)
        )
        guard let x = r.x, let y = r.y, let w = r.w, let h = r.h else { return nil }
        return CropRegion(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h))
    }
}
