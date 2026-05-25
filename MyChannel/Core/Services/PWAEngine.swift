//
//  PWAEngine.swift
//  MyChannel
//
//  Progressive Web App support: manifest generation, service worker config,
//  offline shell, install prompt, push subscription.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation

struct PWAManifest: Codable {
    let name: String
    let shortName: String
    let startURL: String
    let display: String
    let backgroundColor: String
    let themeColor: String
    let icons: [PWAIcon]
    struct PWAIcon: Codable { let src: String; let sizes: String; let type: String }
}

struct ServiceWorkerConfig: Codable {
    let cacheName: String
    let precacheURLs: [String]
    let runtimeCacheStrategies: [CacheStrategy]
    struct CacheStrategy: Codable { let pattern: String; let strategy: String; let maxAge: Int; let maxEntries: Int }
}

@MainActor
final class PWAEngine: ObservableObject {
    static let shared = PWAEngine()
    private init() {}
    @Published private(set) var manifest: PWAManifest?
    @Published private(set) var swConfig: ServiceWorkerConfig?

    func generateManifest(creatorId: String) async throws -> PWAManifest {
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawI: Decodable { let src: String; let sizes: String; let type: String }
        struct Raw: Decodable { let name: String; let short: String; let start: String; let display: String; let bg: String; let theme: String; let icons: [RawI]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "generate_pwa_manifest", creatorId: creatorId))
        let m = PWAManifest(name: r.name, shortName: r.short, startURL: r.start, display: r.display,
            backgroundColor: r.bg, themeColor: r.theme, icons: (r.icons ?? []).map { PWAManifest.PWAIcon(src: $0.src, sizes: $0.sizes, type: $0.type) })
        manifest = m; return m
    }

    func configureServiceWorker(cacheName: String, precacheURLs: [String]) async throws {
        struct Req: Encodable { let task: String; let cacheName: String; let precache: [String] }
        struct RawS: Decodable { let pattern: String; let strategy: String; let maxAge: Int; let maxEntries: Int }
        struct Raw: Decodable { let strategies: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(.myChannelContent, path: "/predict",
            body: Req(task: "configure_service_worker", cacheName: cacheName, precache: precacheURLs))
        swConfig = ServiceWorkerConfig(cacheName: cacheName, precacheURLs: precacheURLs,
            runtimeCacheStrategies: (r.strategies ?? []).map { ServiceWorkerConfig.CacheStrategy(pattern: $0.pattern, strategy: $0.strategy, maxAge: $0.maxAge, maxEntries: $0.maxEntries) })
    }

    func checkInstallEligibility() -> Bool {
        guard let m = manifest else { return false }
        return !m.icons.isEmpty && !m.startURL.isEmpty
    }
}
