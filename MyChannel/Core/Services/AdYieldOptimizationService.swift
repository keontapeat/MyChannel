//
//  AdYieldOptimizationService.swift
//  MyChannel
//
//  Phase 58: Ad Yield Optimization v2.
//  Header-bidding live, `rtb-bidding-predictor` floor pricing,
//  frequency capping, brand-safety tier selection. Sits on top of the
//  existing AdsService + RTBAuctionEngine.
//

import Foundation

enum AdSlot: String, Codable {
    case preRoll, midRoll, postRoll, bumper
    case homeFeedNative, searchNative, shortsInterstitial
}

enum BrandSafetyTier: String, Codable {
    case family        // strict; suitable for Kids Mode
    case general       // default
    case mature        // premium CPMs; adult-only audiences
}

struct AdYieldRequest: Codable {
    let userId: String?
    let videoId: String?
    let slot: AdSlot
    let locale: String
    let deviceCategory: String     // iphone / ipad / tv / visionpro
    let connection: String         // wifi / cellular
    let abTestBucket: String?
}

struct AdYieldDecision: Codable {
    let fill: Bool
    let floorCPMUSD: Double
    let bidders: [String]          // sorted list of bidder IDs server-side
    let creativeTier: BrandSafetyTier
    let capRemaining: Int          // remaining ads this hour for this user
    let vastURL: URL?              // server-stitched VAST/VMAP endpoint
    let reason: String
}

@MainActor
final class AdYieldOptimizationService: ObservableObject {
    static let shared = AdYieldOptimizationService()
    private init() {}

    /// Resolve a placement via rtb-bidding-predictor + ad-optimization.
    /// Caller (AdsService) renders the returned VAST URL in the existing IMA/AVPlayer flow.
    func resolve(_ req: AdYieldRequest) async -> AdYieldDecision {
        guard AppConfig.Features.enableAdYieldV2 else {
            return AdYieldDecision(
                fill: false,
                floorCPMUSD: 0,
                bidders: [],
                creativeTier: .general,
                capRemaining: 0,
                vastURL: nil,
                reason: "yield_v2_disabled"
            )
        }

        struct Raw: Decodable {
            let fill: Bool?
            let floor_cpm_usd: Double?
            let bidders: [String]?
            let creative_tier: String?
            let cap_remaining: Int?
            let vast_url: String?
            let reason: String?
        }

        do {
            let raw: Raw = try await CloudRunAgentRouter.post(
                .rtbBidding,
                path: "/predict",
                body: req
            )
            // Pre-type each value so the type-checker doesn't have to solve the
            // whole multi-argument initializer + `??` overload set at once.
            // (Previously this single expression took ~6s to type-check.)
            let fill: Bool = raw.fill ?? false
            let floorCPM: Double = raw.floor_cpm_usd ?? 0
            let bidders: [String] = raw.bidders ?? []
            let tier: BrandSafetyTier = BrandSafetyTier(rawValue: raw.creative_tier ?? "general") ?? .general
            let capRemaining: Int = raw.cap_remaining ?? 0
            let vastURL: URL? = raw.vast_url.flatMap(URL.init)
            let reason: String = raw.reason ?? "rtb_ok"
            return AdYieldDecision(
                fill: fill,
                floorCPMUSD: floorCPM,
                bidders: bidders,
                creativeTier: tier,
                capRemaining: capRemaining,
                vastURL: vastURL,
                reason: reason
            )
        } catch {
            return AdYieldDecision(
                fill: false,
                floorCPMUSD: 0,
                bidders: [],
                creativeTier: .general,
                capRemaining: 0,
                vastURL: nil,
                reason: "rtb_error"
            )
        }
    }

    /// Report a downstream impression/click for closed-loop training.
    func reportEvent(
        userId: String?,
        videoId: String?,
        slot: AdSlot,
        event: String,     // "impression" / "click" / "skip" / "complete"
        cpm: Double?
    ) async {
        struct Request: Encodable {
            let task: String
            let userId: String?
            let videoId: String?
            let slot: String
            let event: String
            let cpm: Double?
        }
        _ = try? await CloudRunAgentRouter.post(
            .adOptimization,
            path: "/predict",
            body: Request(
                task: "report",
                userId: userId,
                videoId: videoId,
                slot: slot.rawValue,
                event: event,
                cpm: cpm
            )
        ) as _Ack
    }

    private struct _Ack: Decodable { let ok: Bool? }
}
