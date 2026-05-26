//
//  AdaptiveInterfaceService.swift
//  MyChannel
//
//  Phase 202: Adaptive UI — context-aware layout adaptation.
//  Device capability detection, accessibility-driven layout,
//  performance-based simplification. Uses `mychannel-content` Cloud Run.
//

import Foundation
import UIKit

struct DeviceCapability: Codable {
    let deviceModel: String
    let screenSize: String
    let ramGB: Int
    let cpuCores: Int
    let gpuTier: GPUTier
    let supportsProMotion: Bool
    let supportsFaceID: Bool
    enum GPUTier: String, Codable { case low, medium, high }
}

struct LayoutProfile: Codable {
    let id: String
    let name: String
    let maxConcurrentAnimations: Int
    let enableParallax: Bool
    let enableBlur: Bool
    let imageQuality: String
    let videoPreloadCount: Int
    let enableSkeletonLoaders: Bool
}

@MainActor
final class AdaptiveInterfaceService: ObservableObject {
    static let shared = AdaptiveInterfaceService()
    private init() {}
    @Published private(set) var capability: DeviceCapability?
    @Published private(set) var layout: LayoutProfile?

    func detectCapability() {
        let device = UIDevice.current
        let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds ?? CGRect(x: 0, y: 0, width: 390, height: 844)
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        let cpuCores = ProcessInfo.processInfo.processorCount
        let supportsProMotion = UIScreen.main.maximumFramesPerSecond > 60
        capability = DeviceCapability(deviceModel: device.model, screenSize: "\(Int(screen.width))x\(Int(screen.height))",
            ramGB: max(ramGB, 2), cpuCores: cpuCores, gpuTier: ramGB >= 6 ? .high : ramGB >= 4 ? .medium : .low,
            supportsProMotion: supportsProMotion, supportsFaceID: true)
    }

    func selectLayout() {
        guard let cap = capability else { detectCapability(); return }
        let tier = cap.gpuTier
        switch tier {
        case .high:
            layout = LayoutProfile(id: "high", name: "Premium", maxConcurrentAnimations: 8, enableParallax: true,
                enableBlur: true, imageQuality: "high", videoPreloadCount: 3, enableSkeletonLoaders: true)
        case .medium:
            layout = LayoutProfile(id: "medium", name: "Standard", maxConcurrentAnimations: 4, enableParallax: true,
                enableBlur: true, imageQuality: "medium", videoPreloadCount: 2, enableSkeletonLoaders: true)
        case .low:
            layout = LayoutProfile(id: "low", name: "Performance", maxConcurrentAnimations: 2, enableParallax: false,
                enableBlur: false, imageQuality: "low", videoPreloadCount: 1, enableSkeletonLoaders: false)
        }
    }

    func fetchRemoteProfile() async throws {
        struct Req: Encodable { let task: String; let device: String }
        struct Raw: Decodable { let id: String; let name: String; let animations: Int?; let parallax: Bool?; let blur: Bool?; let quality: String?; let preload: Int?; let skeletons: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "fetch_layout_profile", device: capability?.deviceModel ?? "unknown"))
        layout = LayoutProfile(id: r.id, name: r.name, maxConcurrentAnimations: r.animations ?? 4,
            enableParallax: r.parallax ?? true, enableBlur: r.blur ?? true, imageQuality: r.quality ?? "medium",
            videoPreloadCount: r.preload ?? 2, enableSkeletonLoaders: r.skeletons ?? true)
    }
}
