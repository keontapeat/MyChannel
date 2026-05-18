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
