//
//  RegionalLicensingService.swift
//  MyChannel
//
//  Phase 62: Regional content licensing.
//  Decides if a video is playable in the caller's geo by checking the
//  `licensing/{videoId}` rights document and the `regional-content-optimizer`
//  Cloud Run service for per-country availability windows.
//  Works alongside `RegionBlockingService`.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct VideoRights: Codable {
    let videoId: String
    /// ISO 3166-1 alpha-2 codes. If empty, treat as worldwide.
    let allowedCountries: [String]
    /// Overrides — always blocked (sanctions, takedowns, etc.)
    let blockedCountries: [String]
    let availableFrom: Date?
    let availableUntil: Date?
    /// Rights holder identifier (IMDb/TMDB external id, catalog partner id, or "creator").
    let rightsHolderId: String?
}

struct PlayabilityDecision {
    let playable: Bool
    let reason: String
    let availableAt: Date?
}

@MainActor
final class RegionalLicensingService: ObservableObject {
    static let shared = RegionalLicensingService()
    private init() {}

    /// Quick cache to avoid double fetches on a single screen.
    private var cache: [String: VideoRights] = [:]

    func rights(for videoId: String) async throws -> VideoRights? {
        if let cached = cache[videoId] { return cached }
        #if canImport(FirebaseFirestore)
        let doc = try await Firestore.firestore()
            .collection("licensing").document(videoId).getDocument()
        guard let d = doc.data() else { return nil }
        let rights = VideoRights(
            videoId: videoId,
            allowedCountries: (d["allowedCountries"] as? [String]) ?? [],
            blockedCountries: (d["blockedCountries"] as? [String]) ?? [],
            availableFrom: (d["availableFrom"] as? Timestamp)?.dateValue(),
            availableUntil: (d["availableUntil"] as? Timestamp)?.dateValue(),
            rightsHolderId: d["rightsHolderId"] as? String
        )
        cache[videoId] = rights
        return rights
        #else
        return nil
        #endif
    }

    /// Decide if a caller in `countryCode` (e.g. "US") may play `videoId` now.
    func canPlay(videoId: String, countryCode: String, at now: Date = Date()) async -> PlayabilityDecision {
        guard AppConfig.Features.enableRegionalLicensing else {
            return .init(playable: true, reason: "licensing_disabled", availableAt: nil)
        }

        let rights: VideoRights?
        do { rights = try await self.rights(for: videoId) } catch {
            return .init(playable: true, reason: "rights_fetch_failed", availableAt: nil)
        }
        guard let r = rights else {
            return .init(playable: true, reason: "no_rights_doc", availableAt: nil)
        }

        let cc = countryCode.uppercased()
        if r.blockedCountries.map({ $0.uppercased() }).contains(cc) {
            return .init(playable: false, reason: "blocked_country", availableAt: nil)
        }
        if !r.allowedCountries.isEmpty,
           !r.allowedCountries.map({ $0.uppercased() }).contains(cc) {
            return .init(playable: false, reason: "not_in_allowed_countries", availableAt: nil)
        }
        if let from = r.availableFrom, now < from {
            return .init(playable: false, reason: "not_yet_available", availableAt: from)
        }
        if let until = r.availableUntil, now > until {
            return .init(playable: false, reason: "availability_expired", availableAt: nil)
        }
        return .init(playable: true, reason: "ok", availableAt: nil)
    }

    /// Ask the regional optimizer for the best alternative in-catalog title
    /// when the primary is not playable (e.g. show a similar free-in-region video).
    func regionalAlternatives(videoId: String, countryCode: String) async throws -> [String] {
        guard AppConfig.Features.enableRegionalLicensing else { return [] }
        struct Request: Encodable { let task: String; let videoId: String; let country: String }
        struct Raw: Decodable { let video_ids: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .regionalContentOptimizer,
            path: "/predict",
            body: Request(task: "alternatives", videoId: videoId, country: countryCode)
        )
        return r.video_ids ?? []
    }
}
