//
//  FeedLayoutEngineService.swift
//  MyChannel
//
//  Phase 261: Feed Layout Engine — adaptive grid/list/magazine layouts,
//  density controls, section ordering, responsive breakpoints.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation
import UIKit

struct FeedLayout: Codable, Identifiable {
    let id: String
    let type: LayoutType
    let columns: Int
    let spacing: Double
    let thumbnailAspect: Double
    let showMetadata: Bool
    let sectionOrder: [String]
    enum LayoutType: String, Codable { case grid, list, magazine, compact, hero }
}

struct LayoutBreakpoint: Codable {
    let minWidth: Double
    let layout: FeedLayout
}

@MainActor
final class FeedLayoutEngineService: ObservableObject {
    static let shared = FeedLayoutEngineService()
    private init() {}
    @Published private(set) var activeLayout: FeedLayout?
    @Published private(set) var breakpoints: [LayoutBreakpoint] = []

    func detectLayout() {
        guard AppConfig.Features.enableFeedLayoutEngine else { return }
        let width = UIScreen.main.bounds.width
        let layout: FeedLayout
        if width >= 1024 {
            layout = FeedLayout(id: "tablet_grid", type: .grid, columns: 3, spacing: 16, thumbnailAspect: 16/9, showMetadata: true, sectionOrder: ["hero", "trending", "subscriptions", "recommended", "live"])
        } else if width >= 768 {
            layout = FeedLayout(id: "tablet_mag", type: .magazine, columns: 2, spacing: 12, thumbnailAspect: 16/9, showMetadata: true, sectionOrder: ["hero", "trending", "subscriptions", "recommended"])
        } else {
            layout = FeedLayout(id: "phone_list", type: .list, columns: 1, spacing: 8, thumbnailAspect: 16/9, showMetadata: true, sectionOrder: ["trending", "subscriptions", "recommended", "live"])
        }
        activeLayout = layout
    }

    func fetchRemoteLayout(userId: String) async throws {
        struct Req: Encodable { let task: String; let userId: String; let screenWidth: Double }
        struct Raw: Decodable { let id: String; let type: String; let columns: Int?; let spacing: Double?; let aspect: Double?; let meta: Bool?; let sections: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "fetch_feed_layout", userId: userId, screenWidth: UIScreen.main.bounds.width))
        activeLayout = FeedLayout(id: r.id, type: .init(rawValue: r.type) ?? .list, columns: r.columns ?? 1,
            spacing: r.spacing ?? 8, thumbnailAspect: r.aspect ?? 16/9, showMetadata: r.meta ?? true,
            sectionOrder: r.sections ?? ["trending", "subscriptions", "recommended"])
    }

    func setLayout(_ type: FeedLayout.LayoutType) {
        let cols = type == .grid ? 2 : type == .magazine ? 2 : 1
        activeLayout = FeedLayout(id: type.rawValue, type: type, columns: cols, spacing: 8, thumbnailAspect: 16/9,
            showMetadata: true, sectionOrder: activeLayout?.sectionOrder ?? ["trending", "subscriptions", "recommended"])
    }

    func reorderSections(_ newOrder: [String]) {
        guard let old = activeLayout else { return }
        activeLayout = FeedLayout(id: old.id, type: old.type, columns: old.columns, spacing: old.spacing,
            thumbnailAspect: old.thumbnailAspect, showMetadata: old.showMetadata, sectionOrder: newOrder)
    }
}
