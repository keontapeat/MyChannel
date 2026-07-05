//
//  DeepLinkService.swift
//  MyChannel
//
//  Universal link + custom URL scheme routing.
//  Parses deep links, resolves targets, tracks attribution.
//  Branch SDK powers install attribution & deferred deep links.
//

#if canImport(BranchPlugin)
import BranchPlugin
#endif
import Foundation
import UIKit

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

    // Deep-link start position: when a video link carries ?t=, the target video id
    // and start time (seconds) are held here until the player consumes them.
    private var pendingSeekVideoId: String?
    private var pendingSeekSeconds: Double?

    func parse(url: URL) -> DeepLinkTarget? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let host = components.host?.lowercased() ?? ""
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let queryItems = components.queryItems?.reduce(into: [String: String]()) { $0[$1.name] = $1.value ?? "" } ?? [:]

        func typeForKeyword(_ keyword: String) -> DeepLinkTarget.DeepLinkType {
            switch keyword {
            case "video", "watch": return .video
            case "profile", "channel": return .profile
            case "playlist": return .playlist
            case "live": return .live
            case "flicks", "shorts": return .flicks
            case "search": return .search
            case "settings": return .settings
            case "studio": return .studio
            default: return .video
            }
        }

        let type: DeepLinkTarget.DeepLinkType
        let targetId: String
        let segments = path.split(separator: "/").map(String.init)

        if host.contains(".") || host.isEmpty {
            // Universal / web link: https://mychannel.live/watch/{id} (or /video/{id}, /watch?v={id})
            let keyword = segments.first?.lowercased() ?? ""
            type = typeForKeyword(keyword)
            let fromPath = segments.count > 1 ? segments[1] : ""
            targetId = !fromPath.isEmpty ? fromPath : (queryItems["v"] ?? "")
        } else {
            // Custom scheme: mychannel://video/{id}
            type = typeForKeyword(host)
            targetId = path
        }

        // Capture a start timestamp for video links (?t=90 or ?t=1m30s)
        if type == .video, !targetId.isEmpty,
           let raw = queryItems["t"], let seconds = Self.parseTimecode(raw), seconds > 0 {
            pendingSeekVideoId = targetId
            pendingSeekSeconds = seconds
        }

        let target = DeepLinkTarget(id: UUID().uuidString, type: type, targetId: targetId, params: queryItems, source: queryItems["utm_source"])
        pendingLink = target
        return target
    }

    /// Returns and clears the pending start time for [videoId], if a deep link set one.
    func consumeSeek(for videoId: String) -> Double? {
        guard pendingSeekVideoId == videoId, let seconds = pendingSeekSeconds else { return nil }
        pendingSeekVideoId = nil
        pendingSeekSeconds = nil
        return seconds
    }

    /// Parses a timecode: plain seconds ("90") or "1h2m3s" / "2m30s" (iOS 15-safe, no Regex).
    static func parseTimecode(_ raw: String) -> Double? {
        let str = raw.lowercased()
        if let s = Double(str) { return s }
        var total = 0.0
        var num = ""
        for ch in str {
            if ch.isNumber || ch == "." {
                num.append(ch)
            } else {
                let n = Double(num) ?? 0
                switch ch {
                case "h": total += n * 3600
                case "m": total += n * 60
                case "s": total += n
                default: break
                }
                num = ""
            }
        }
        if let trailing = Double(num), !num.isEmpty { total += trailing } // bare trailing = seconds
        return total > 0 ? total : nil
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

    // MARK: - Branch SDK Integration

    func configureBranch(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if canImport(BranchPlugin)
        Branch.getInstance().initSession(launchOptions: launchOptions) { [weak self] params, error in
            guard let self, let params, error == nil else { return }
            if let videoId = params["video_id"] as? String {
                Task { @MainActor in
                    self.pendingLink = DeepLinkTarget(id: UUID().uuidString, type: .video, targetId: videoId, params: [:], source: params["~channel"] as? String)
                }
            }
            print("✅ [Branch] Session init. Params: \(params)")
        }
        #endif
    }

    func handleBranchURL(_ url: URL) -> Bool {
        #if canImport(BranchPlugin)
        Branch.getInstance().handleDeepLink(url)
        return true
        #else
        return false
        #endif
    }

    func handleBranchActivity(_ activity: NSUserActivity) -> Bool {
        #if canImport(BranchPlugin)
        return Branch.getInstance().continue(activity)
        #else
        return false
        #endif
    }

    func createVideoShareLink(videoId: String, title: String, thumbnailURL: String?) async -> URL? {
        #if canImport(BranchPlugin)
        let buo = BranchUniversalObject(canonicalIdentifier: "video/\(videoId)")
        buo.title = title
        buo.contentMetadata.customMetadata["video_id"] = videoId
        if let thumb = thumbnailURL { buo.imageUrl = thumb }

        let lp = BranchLinkProperties()
        lp.channel = "mychannel_ios"
        lp.feature = "sharing"

        return await withCheckedContinuation { cont in
            buo.getShortUrl(with: lp) { url, _ in
                cont.resume(returning: url.flatMap { URL(string: $0) })
            }
        }
        #else
        return URL(string: "https://mychannel.live/watch/\(videoId)")
        #endif
    }
}
