//
//  AmbientModeService.swift
//  MyChannel
//
//  Phase 142: Ambient Mode.
//  Color-extracted glow behind player, smooth palette transitions,
//  dark-mode integration. YouTube-style ambient light effect.
//

import Foundation
import UIKit
import AVFoundation

// MARK: - Models

struct AmbientPalette: Equatable {
    let dominant: UIColor
    let secondary: UIColor
    let accent: UIColor
    let luminance: CGFloat     // 0–1
}

// MARK: - Service

@MainActor
final class AmbientModeService: ObservableObject {
    static let shared = AmbientModeService()
    private init() {}

    @Published var isEnabled: Bool = false
    @Published var currentPalette = AmbientPalette(
        dominant: .black, secondary: .darkGray, accent: .gray, luminance: 0
    )
    @Published var glowIntensity: CGFloat = 0.6
    @Published var transitionDuration: TimeInterval = 1.2

    private var extractionTimer: Timer?
    private var lastExtractedImage: UIImage?

    func toggle() {
        guard AppConfig.Features.enableAmbientMode else { return }
        isEnabled.toggle()
        if isEnabled {
            startExtraction()
        } else {
            stopExtraction()
            currentPalette = AmbientPalette(dominant: .black, secondary: .darkGray, accent: .gray, luminance: 0)
        }
    }

    func startExtraction() {
        guard AppConfig.Features.enableAmbientMode, isEnabled else { return }
        extractionTimer?.invalidate()
        extractionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.extractCurrentFrame()
            }
        }
    }

    func stopExtraction() {
        extractionTimer?.invalidate()
        extractionTimer = nil
    }

    func extractFromFrame(_ image: UIImage) {
        guard AppConfig.Features.enableAmbientMode, isEnabled else { return }
        lastExtractedImage = image
        let colors = extractDominantColors(from: image)
        currentPalette = colors
    }

    private func extractCurrentFrame() {
        // Extract colors from the current video frame via pixel sampling
        // In production, this reads from the player's current pixel buffer
        guard let image = lastExtractedImage else { return }
        let colors = extractDominantColors(from: image)
        currentPalette = colors
    }

    private func extractDominantColors(from image: UIImage) -> AmbientPalette {
        guard let cgImage = image.cgImage else {
            return AmbientPalette(dominant: .black, secondary: .darkGray, accent: .gray, luminance: 0)
        }
        let width = 8, height = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixelData, width: width, height: height,
                                     bitsPerComponent: 8, bytesPerRow: width * 4,
                                     space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return AmbientPalette(dominant: .black, secondary: .darkGray, accent: .gray, luminance: 0)
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rTotal = 0, gTotal = 0, bTotal = 0
        var maxSatR = 0, maxSatG = 0, maxSatB = 0
        var maxSat: CGFloat = 0
        let count = width * height

        for i in 0..<count {
            let offset = i * 4
            let r = Int(pixelData[offset])
            let g = Int(pixelData[offset + 1])
            let b = Int(pixelData[offset + 2])
            rTotal += r; gTotal += g; bTotal += b

            let color = UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
            if s > maxSat { maxSat = s; maxSatR = r; maxSatG = g; maxSatB = b }
        }

        let dominant = UIColor(red: CGFloat(rTotal/count)/255, green: CGFloat(gTotal/count)/255, blue: CGFloat(bTotal/count)/255, alpha: 1)
        let accent = UIColor(red: CGFloat(maxSatR)/255, green: CGFloat(maxSatG)/255, blue: CGFloat(maxSatB)/255, alpha: 1)
        var lum: CGFloat = 0
        dominant.getWhite(&lum, alpha: nil)

        return AmbientPalette(
            dominant: dominant,
            secondary: dominant.withAlphaComponent(0.6),
            accent: accent,
            luminance: lum
        )
    }

    func setGlowIntensity(_ intensity: CGFloat) {
        glowIntensity = max(0, min(1, intensity))
    }
}
