//
//  InteractiveOverlayMarketplaceService.swift
//  MyChannel
//
//  Phase 234: Interactive Overlay Marketplace.
//  Poll, quiz, commerce, and stats overlays with SDK install flow
//  and sandboxed runtime.
//  Uses `super-ai-team` Cloud Run.
//

import Foundation

// MARK: - Models

struct OverlayTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let type: OverlayType
    let description: String
    let authorId: String
    let downloadCount: Int
    let rating: Double
    let isFree: Bool
    let price: Double
    let sdkVersion: String

    enum OverlayType: String, Codable {
        case poll, quiz, commerce, stats, cta, custom
    }
}

struct InstalledOverlay: Codable, Identifiable {
    let id: String
    let templateId: String
    let userId: String
    let config: [String: String]
    let isActive: Bool
    let installedAt: Date
    let sandboxEnabled: Bool
}

// MARK: - Service

@MainActor
final class InteractiveOverlayMarketplaceService: ObservableObject {
    static let shared = InteractiveOverlayMarketplaceService()
    private init() {}

    @Published private(set) var templates: [OverlayTemplate] = []
    @Published private(set) var installed: [InstalledOverlay] = []
    @Published var isInstalling: Bool = false

    func browseMarketplace(category: OverlayTemplate.OverlayType? = nil) async throws {
        guard AppConfig.Features.enableInteractiveOverlayMarketplace else { return }
        struct Req: Encodable { let task: String; let category: String? }
        struct RawT: Decodable { let id: String; let name: String; let type: String; let desc: String; let author: String; let downloads: Int; let rating: Double; let free: Bool; let price: Double; let sdk: String }
        struct Raw: Decodable { let templates: [RawT]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "browse_overlays", category: category?.rawValue)
        )
        templates = (r.templates ?? []).map {
            OverlayTemplate(id: $0.id, name: $0.name, type: .init(rawValue: $0.type) ?? .custom,
                            description: $0.desc, authorId: $0.author, downloadCount: $0.downloads,
                            rating: $0.rating, isFree: $0.free, price: $0.price, sdkVersion: $0.sdk)
        }
    }

    func installOverlay(templateId: String, userId: String, config: [String: String] = [:]) async throws -> InstalledOverlay {
        guard AppConfig.Features.enableInteractiveOverlayMarketplace else {
            return InstalledOverlay(id: "", templateId: templateId, userId: userId, config: config,
                                     isActive: false, installedAt: Date(), sandboxEnabled: true)
        }
        isInstalling = true
        defer { isInstalling = false }
        struct Req: Encodable { let task: String; let templateId: String; let userId: String; let config: [String: String] }
        struct Raw: Decodable { let id: String }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "install_overlay", templateId: templateId, userId: userId, config: config), timeout: 15
        )
        let overlay = InstalledOverlay(id: r.id, templateId: templateId, userId: userId, config: config,
                                        isActive: true, installedAt: Date(), sandboxEnabled: true)
        installed.append(overlay)
        return overlay
    }

    func toggleOverlay(overlayId: String, active: Bool) async throws {
        guard AppConfig.Features.enableInteractiveOverlayMarketplace else { return }
        struct Req: Encodable { let task: String; let overlayId: String; let active: Bool }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Req(task: "toggle_overlay", overlayId: overlayId, active: active)
        )
        if let idx = installed.firstIndex(where: { $0.id == overlayId }) {
            let old = installed[idx]
            installed[idx] = InstalledOverlay(id: old.id, templateId: old.templateId, userId: old.userId,
                                               config: old.config, isActive: active, installedAt: old.installedAt, sandboxEnabled: old.sandboxEnabled)
        }
    }
}
