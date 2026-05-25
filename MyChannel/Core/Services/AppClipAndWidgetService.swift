//
//  AppClipAndWidgetService.swift
//  MyChannel
//
//  Phase 55: iOS App Clip + Home/Lock Screen widgets.
//  Provides the data feed widgets/Clips pull from — served through the App Group
//  shared container so WidgetKit + App Clip targets can read without a network
//  round-trip when cached.
//
//  NOTE: The WidgetKit target + App Clip target must be added in Xcode separately.
//  This file powers the shared data provider consumed by both.
//

import Foundation

struct NowPlayingWidgetPayload: Codable {
    let videoId: String
    let title: String
    let thumbnailURL: URL?
    let creatorName: String
    let progress: Double           // 0..1
    let updatedAt: Date
}

struct UpNextWidgetPayload: Codable {
    struct Item: Codable, Identifiable {
        let id: String
        let title: String
        let thumbnailURL: URL?
        let creatorName: String
    }
    let items: [Item]
    let updatedAt: Date
}

struct LiveBadgeWidgetPayload: Codable {
    let liveCount: Int
    let topStreamId: String?
    let topStreamTitle: String?
    let updatedAt: Date
}

@MainActor
final class AppClipAndWidgetService: ObservableObject {
    static let shared = AppClipAndWidgetService()
    private init() {}

    /// App Group used by Widget + Clip extensions to share data.
    /// Add matching App Group entitlement to Widget + Clip targets in Xcode.
    static let appGroup = "group.com.mychannel.shared"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroup)
    }

    // MARK: - Writers (main app)

    func writeNowPlaying(_ payload: NowPlayingWidgetPayload) {
        guard AppConfig.Features.enableAppClipAndWidgets else { return }
        write(payload, key: "widget.nowPlaying")
        reloadWidgets(kind: "NowPlayingWidget")
    }

    func writeUpNext(_ payload: UpNextWidgetPayload) {
        guard AppConfig.Features.enableAppClipAndWidgets else { return }
        write(payload, key: "widget.upNext")
        reloadWidgets(kind: "UpNextWidget")
    }

    func writeLiveBadge(_ payload: LiveBadgeWidgetPayload) {
        guard AppConfig.Features.enableAppClipAndWidgets else { return }
        write(payload, key: "widget.liveBadge")
        reloadWidgets(kind: "LiveBadgeWidget")
    }

    // MARK: - Readers (Widget + Clip targets)

    func readNowPlaying() -> NowPlayingWidgetPayload? { read("widget.nowPlaying") }
    func readUpNext() -> UpNextWidgetPayload? { read("widget.upNext") }
    func readLiveBadge() -> LiveBadgeWidgetPayload? { read("widget.liveBadge") }

    // MARK: - App Clip invocation

    /// Universal Links for App Clip. Configured in AASA under:
    ///   "applinks": paths = ["/clip/*", "/v/*", "/live/*"]
    ///   "appclips": { "apps": ["TEAMID.com.mychannel.app.Clip"] }
    static let appClipDomain = "mychannel.live"
    static let appClipPaths: [String] = ["/clip/*", "/v/*", "/live/*", "/r/*"]

    // MARK: - Helpers

    private func write<T: Encodable>(_ value: T, key: String) {
        guard let d = defaults, let data = try? JSONEncoder().encode(value) else { return }
        d.set(data, forKey: key)
    }

    private func read<T: Decodable>(_ key: String) -> T? {
        guard let d = defaults, let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func reloadWidgets(kind: String) {
        #if canImport(WidgetKit)
        Task { @MainActor in
            // Only call into WidgetKit if the widget target is included.
            // Avoid a hard dependency so this compiles in the main app target.
            if let cls = NSClassFromString("WKInterfaceDevice") { _ = cls } // no-op touch
            // Actual reload must happen from the Widget/main app with WidgetKit linked.
            // This stub exists so main app can forward-reload. See WidgetBundle.swift in the Widget target.
        }
        #endif
    }
}
