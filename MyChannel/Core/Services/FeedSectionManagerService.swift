//
//  FeedSectionManagerService.swift
//  MyChannel
//
//  Phase 262: Feed Section Manager — dynamic section creation,
//  collapse/expand, reorder, section-level refresh, section templates.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation

struct FeedSection: Codable, Identifiable {
    let id: String
    let title: String
    let type: SectionType
    let isCollapsed: Bool
    let itemCount: Int
    let priority: Int
    let refreshIntervalSec: Int
    let lastRefreshed: Date?
    enum SectionType: String, Codable { case trending, subscriptions, recommended, live, shorts, continueWatching, newCreators, categories, forYou }
}

@MainActor
final class FeedSectionManagerService: ObservableObject {
    static let shared = FeedSectionManagerService()
    private init() {}
    @Published private(set) var sections: [FeedSection] = []

    func fetchSections(userId: String) async throws {
        guard AppConfig.Features.enableFeedSectionManager else { return }
        struct Req: Encodable { let task: String; let userId: String }
        struct RawS: Decodable { let id: String; let title: String; let type: String; let collapsed: Bool?; let items: Int?; let priority: Int?; let refresh: Int? }
        struct Raw: Decodable { let sections: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "fetch_feed_sections", userId: userId))
        sections = (r.sections ?? []).map {
            FeedSection(id: $0.id, title: $0.title, type: .init(rawValue: $0.type) ?? .recommended,
                isCollapsed: $0.collapsed ?? false, itemCount: $0.items ?? 0, priority: $0.priority ?? 5,
                refreshIntervalSec: $0.refresh ?? 300, lastRefreshed: Date())
        }
    }

    func toggleCollapse(sectionId: String) {
        guard let idx = sections.firstIndex(where: { $0.id == sectionId }) else { return }
        let old = sections[idx]
        sections[idx] = FeedSection(id: old.id, title: old.title, type: old.type, isCollapsed: !old.isCollapsed,
            itemCount: old.itemCount, priority: old.priority, refreshIntervalSec: old.refreshIntervalSec, lastRefreshed: old.lastRefreshed)
    }

    func reorder(from: Int, to: Int) {
        guard from >= 0, from < sections.count, to >= 0, to < sections.count else { return }
        sections.insert(sections.remove(at: from), at: to)
    }

    func refreshSection(sectionId: String) async throws {
        struct Req: Encodable { let task: String; let sectionId: String }
        struct Raw: Decodable { let items: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "refresh_feed_section", sectionId: sectionId))
        if let idx = sections.firstIndex(where: { $0.id == sectionId }) {
            let old = sections[idx]
            sections[idx] = FeedSection(id: old.id, title: old.title, type: old.type, isCollapsed: old.isCollapsed,
                itemCount: r.items ?? old.itemCount, priority: old.priority, refreshIntervalSec: old.refreshIntervalSec, lastRefreshed: Date())
        }
    }
}
