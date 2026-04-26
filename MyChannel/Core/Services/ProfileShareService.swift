//
//  ProfileShareService.swift
//  MyChannel
//
//  Phase 245: Profile QR Code & Smart Sharing.
//  Dynamic QR codes, NFC tap-to-follow, share sheet with preview cards,
//  deep link attribution, cross-app sharing.
//  Uses `mychannel-content` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileShareCard: Codable, Identifiable {
    let id: String
    let creatorId: String
    let qrCodeURL: String
    let deepLink: String
    let previewImageURL: String?
    let style: ShareCardStyle
    let createdAt: Date

    enum ShareCardStyle: String, Codable { case standard, minimal, cinematic, branded }
}

struct ShareAttribution: Codable, Identifiable {
    let id: String
    let shareId: String
    let source: String
    let medium: String
    let campaign: String?
    let clickedAt: Date
    let convertedToFollow: Bool
}

// MARK: - Service

@MainActor
final class ProfileShareService: ObservableObject {
    static let shared = ProfileShareService()
    private init() {}

    @Published private(set) var shareCard: ProfileShareCard?
    @Published private(set) var attributions: [ShareAttribution] = []

    func generateQRCode(creatorId: String, style: ProfileShareCard.ShareCardStyle = .standard) async throws -> ProfileShareCard {
        guard AppConfig.Features.enableProfileSmartSharing else {
            return ProfileShareCard(id: "", creatorId: creatorId, qrCodeURL: "", deepLink: "mychannel://profile/\(creatorId)",
                                     previewImageURL: nil, style: style, createdAt: Date())
        }
        struct Req: Encodable { let task: String; let creatorId: String; let style: String }
        struct Raw: Decodable { let id: String; let qr_url: String; let deep_link: String; let preview: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "generate_qr_code", creatorId: creatorId, style: style.rawValue)
        )
        let card = ProfileShareCard(id: r.id, creatorId: creatorId, qrCodeURL: r.qr_url,
                                      deepLink: r.deep_link, previewImageURL: r.preview, style: style, createdAt: Date())
        shareCard = card
        return card
    }

    func trackShareAttribution(shareId: String, source: String, medium: String, campaign: String?) async throws {
        guard AppConfig.Features.enableProfileSmartSharing else { return }
        struct Req: Encodable { let task: String; let shareId: String; let source: String; let medium: String; let campaign: String? }
        struct Raw: Decodable { let id: String; let converted: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "track_share_attribution", shareId: shareId, source: source, medium: medium, campaign: campaign)
        )
        let attr = ShareAttribution(id: r.id, shareId: shareId, source: source, medium: medium,
                                      campaign: campaign, clickedAt: Date(), convertedToFollow: r.converted ?? false)
        attributions.append(attr)
    }

    func fetchShareStats(creatorId: String) async throws -> [String: Int] {
        guard AppConfig.Features.enableProfileSmartSharing else { return [:] }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct Raw: Decodable { let stats: [String: Int]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelContent, path: "/predict",
            body: Req(task: "fetch_share_stats", creatorId: creatorId)
        )
        return r.stats ?? [:]
    }
}
