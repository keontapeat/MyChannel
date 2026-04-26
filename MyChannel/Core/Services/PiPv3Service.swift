//
//  PiPv3Service.swift
//  MyChannel
//
//  Phase 156: Picture-in-Picture v3.
//  Resizable PiP, snap-to-edge, mini controls, cross-app continuity.
//

import Foundation
import AVKit
import UIKit

// MARK: - Models

struct PiPConfiguration: Equatable {
    var size: PiPSize
    var corner: PiPCorner
    var opacity: CGFloat
    var showMiniControls: Bool
    var autoStartOnDismiss: Bool
}

enum PiPSize: String, CaseIterable { case small, medium, large }
enum PiPCorner: String, CaseIterable { case topLeft, topRight, bottomLeft, bottomRight }

// MARK: - Service

@MainActor
final class PiPv3Service: ObservableObject {
    static let shared = PiPv3Service()
    private init() {}

    @Published var config = PiPConfiguration(
        size: .medium, corner: .bottomRight, opacity: 1.0,
        showMiniControls: true, autoStartOnDismiss: true
    )
    @Published var isActive: Bool = false
    @Published var currentVideoId: String?
    @Published var currentTimeSec: Double = 0

    func start(videoId: String, player: AVPlayer?) {
        guard AppConfig.Features.enablePiPv3 else { return }
        currentVideoId = videoId
        isActive = true
        if config.autoStartOnDismiss {
            NativePiPController.shared.startPiP()
        }
    }

    func stop() {
        NativePiPController.shared.stopPiP()
        isActive = false
        currentVideoId = nil
    }

    func resize(to size: PiPSize) {
        guard AppConfig.Features.enablePiPv3 else { return }
        config.size = size
    }

    func snapTo(corner: PiPCorner) {
        guard AppConfig.Features.enablePiPv3 else { return }
        config.corner = corner
    }

    func toggleMiniControls() {
        config.showMiniControls.toggle()
    }

    func setOpacity(_ opacity: CGFloat) {
        config.opacity = max(0.3, min(1.0, opacity))
    }

    var pipSizePoints: CGSize {
        switch config.size {
        case .small: return CGSize(width: 160, height: 90)
        case .medium: return CGSize(width: 240, height: 135)
        case .large: return CGSize(width: 320, height: 180)
        }
    }

    var cornerOffset: CGPoint {
        let margin: CGFloat = 16
        let screen = UIScreen.main.bounds
        let size = pipSizePoints
        switch config.corner {
        case .topLeft: return CGPoint(x: margin, y: margin + 60)
        case .topRight: return CGPoint(x: screen.width - size.width - margin, y: margin + 60)
        case .bottomLeft: return CGPoint(x: margin, y: screen.height - size.height - margin - 90)
        case .bottomRight: return CGPoint(x: screen.width - size.width - margin, y: screen.height - size.height - margin - 90)
        }
    }
}
