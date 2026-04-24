//
//  MultiRegionFirestoreConfig.swift
//  MyChannel
//
//  Phase 64: Multi-region Firestore + BigQuery plan.
//  Primary region: us-central1 (mychannel-ca26d).
//  Secondary regions: europe-west1 (EU users), asia-northeast1 (APAC users).
//
//  Firestore currently ships as a single multi-region by default. True
//  cross-region writes require migration to per-region databases with a
//  routing layer. This file declares the client-side routing rules used
//  by the sharding service and by `DatabaseShardingService`.
//

import Foundation

enum FirestoreRegion: String, Codable, CaseIterable {
    case usCentral1    = "us-central1"
    case europeWest1   = "europe-west1"
    case asiaNortheast1 = "asia-northeast1"

    /// Firebase callable function host used to read/write against this region.
    var gatewayHost: String {
        switch self {
        case .usCentral1:     return "https://us-central1-mychannel-ca26d.cloudfunctions.net"
        case .europeWest1:    return "https://europe-west1-mychannel-ca26d.cloudfunctions.net"
        case .asiaNortheast1: return "https://asia-northeast1-mychannel-ca26d.cloudfunctions.net"
        }
    }
}

struct MultiRegionFirestoreConfig {
    /// Simple caller→region policy until the true multi-region rollout lands.
    /// Reads: prefer caller region, fall back to us-central1.
    /// Writes: always primary (us-central1) to preserve strong consistency.
    static func preferredReadRegion(for countryCode: String) -> FirestoreRegion {
        let cc = countryCode.uppercased()
        let eu: Set<String> = ["GB","IE","FR","DE","ES","IT","NL","BE","LU","PT","SE","NO","DK","FI","PL","CZ","AT","CH","GR","HU","RO","BG"]
        let apac: Set<String> = ["JP","KR","CN","HK","TW","SG","MY","ID","TH","VN","PH","IN","AU","NZ"]
        if eu.contains(cc)   { return .europeWest1 }
        if apac.contains(cc) { return .asiaNortheast1 }
        return .usCentral1
    }

    static let primaryWriteRegion: FirestoreRegion = .usCentral1

    /// Per-collection override: some collections (e.g. live chat) should
    /// always write close to the caller. Enabled only when the secondary
    /// database is provisioned.
    static func writeRegion(forCollection collection: String, callerCountry: String) -> FirestoreRegion {
        guard AppConfig.Features.enableMultiRegionFirestore else {
            return primaryWriteRegion
        }
        switch collection {
        case "liveChat", "presence", "storyViews":
            return preferredReadRegion(for: callerCountry)
        default:
            return primaryWriteRegion
        }
    }

    /// BigQuery mirror region per collection (set up via Firestore BigQuery extension).
    static let bigQueryDatasets: [String: String] = [
        "videos":    "videos_v1",
        "analytics": "analytics_v1",
        "users":     "users_v1",
        "comments":  "comments_v1",
        "watchHistory": "watch_history_v1"
    ]
}
