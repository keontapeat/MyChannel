//
//  DeepLinkManager.swift
//  MyChannel
//
//  Deep link routing, deferred deep linking, and universal link handling.
//  Coordinates with DeepLinkService for URL parsing.
//

import Foundation

struct DeepLinkRoute: Codable, Identifiable {
    let id: String
    let pattern: String
    let destination: String
    let requiresAuth: Bool
    let priority: Int
}

@MainActor
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    private init() {}
    @Published private(set) var routes: [DeepLinkRoute] = []
    @Published private(set) var deferredLink: DeepLinkRoute?

    func registerRoutes() {
        routes = [
            DeepLinkRoute(id: "video", pattern: "/video/*", destination: "VideoDetailView", requiresAuth: false, priority: 10),
            DeepLinkRoute(id: "profile", pattern: "/profile/*", destination: "PublicProfileView", requiresAuth: false, priority: 10),
            DeepLinkRoute(id: "live", pattern: "/live/*", destination: "LiveStreamView", requiresAuth: false, priority: 15),
            DeepLinkRoute(id: "playlist", pattern: "/playlist/*", destination: "PlaylistDetailView", requiresAuth: false, priority: 8),
            DeepLinkRoute(id: "flicks", pattern: "/flicks", destination: "FlicksView", requiresAuth: false, priority: 5),
            DeepLinkRoute(id: "studio", pattern: "/studio", destination: "CreatorStudioView", requiresAuth: true, priority: 20),
            DeepLinkRoute(id: "settings", pattern: "/settings", destination: "SettingsView", requiresAuth: true, priority: 20),
            DeepLinkRoute(id: "search", pattern: "/search/*", destination: "SearchView", requiresAuth: false, priority: 8)
        ]
    }

    func resolve(url: URL) -> DeepLinkRoute? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let path = components.path
        return routes
            .filter { path.matchesGlob($0.pattern) }
            .sorted { $0.priority > $1.priority }
            .first
    }

    func storeDeferred(url: URL) {
        if let route = resolve(url: url) { deferredLink = route }
    }

    func consumeDeferred() -> DeepLinkRoute? {
        let link = deferredLink; deferredLink = nil; return link
    }
}

extension String {
    func matchesGlob(_ pattern: String) -> Bool {
        let regexPattern = pattern.replacingOccurrences(of: "*", with: ".*").replacingOccurrences(of: "/", with: "\\/")
        return range(of: regexPattern, options: .regularExpression) != nil
    }
}
