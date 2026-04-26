//
//  DeepLinkService.swift
//  MyChannel
//
//  Universal link + custom URL scheme routing.
//  Parses deep links, resolves targets, tracks attribution.
//

import Foundation

struct DeepLinkTarget: Codable, Identifiable {
    let id: String
    let type: DeepLinkType
    let targetId: String
    let params: [String: String]
    let source: String?
    enum DeepLinkType: String, Codable { case video, profile, playlist, live, flicks, search, settings, studio }
}

struct DeepLinkAttribution: Codable, Identifiable {
    let id: String
    let link: String
    let source: String
    let medium: String?
    let campaign: String?
    let clickedAt: Date
    let convertedAt: Date?
}

@MainActor
final class DeepLinkService: ObservableObject {
    static let shared = DeepLinkService()
    private init() {}
    @Published private(set) var pendingLink: DeepLinkTarget?
    @Published private(set) var attributions: [DeepLinkAttribution] = []

    func parse(url: URL) -> DeepLinkTarget? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let host = components.host?.lowercased() ?? ""
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name] = $1.value ?? "" } ?? [:]

        let type: DeepLinkTarget.DeepLinkType
        switch host {
        case "video": type = .video
        case "profile", "channel": type = .profile
        case "playlist": type = .playlist
        case "live": type = .live
        case "flicks", "shorts": type = .flicks
        case "search": type = .search
        case "settings": type = .settings
        case "studio": type = .studio
        default: type = .video
        }

        let target = DeepLinkTarget(id: UUID().uuidString, type: type, targetId: path, params: queryItems, source: queryItems["utm_source"])
        pendingLink = target
        return target
    }

    func trackAttribution(link: String, source: String, medium: String?, campaign: String?) {
        let attr = DeepLinkAttribution(id: UUID().uuidString, link: link, source: source, medium: medium, campaign: campaign, clickedAt: Date(), convertedAt: nil)
        attributions.append(attr)
    }

    func markConverted(attributionId: String) {
        if let idx = attributions.firstIndex(where: { $0.id == attributionId }) {
            let old = attributions[idx]
            attributions[idx] = DeepLinkAttribution(id: old.id, link: old.link, source: old.source, medium: old.medium, campaign: old.campaign, clickedAt: old.clickedAt, convertedAt: Date())
        }
    }

    func clearPending() { pendingLink = nil }
}
