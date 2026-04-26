//
//  MultiRegionFirestoreConfig.swift
//  MyChannel
//
//  Multi-region Firestore configuration: region selection,
//  latency-based routing, replication monitoring.
//

import Foundation
import FirebaseFirestore

struct FirestoreRegion: Codable, Identifiable {
    let id: String
    let name: String
    let location: String
    let avgLatencyMs: Double
    let isPrimary: Bool
    let status: String
}

@MainActor
final class MultiRegionFirestoreConfig: ObservableObject {
    static let shared = MultiRegionFirestoreConfig()
    private init() {}
    @Published private(set) var regions: [FirestoreRegion] = []
    @Published private(set) var activeRegion: FirestoreRegion?

    func detectOptimalRegion() {
        let current = Locale.current.region?.identifier ?? "US"
        let regionMap: [String: (String, String)] = [
            "US": ("us-central1", "Iowa"), "EU": ("europe-west1", "Belgium"),
            "ASIA": ("asia-northeast1", "Tokyo"), "AU": ("australia-southeast1", "Sydney")
        ]
        let (loc, name) = regionMap[current] ?? regionMap["US"]!
        activeRegion = FirestoreRegion(id: loc, name: name, location: loc, avgLatencyMs: 0, isPrimary: true, status: "active")
    }

    func fetchRegionHealth() async throws {
        struct Req: Encodable { let task: String }
        struct RawR: Decodable { let id: String; let name: String; let location: String; let latency: Double; let primary: Bool; let status: String }
        struct Raw: Decodable { let regions: [RawR]? }
        let r: Raw = try await CloudRunAgentRouter.post(.autoScaler, path: "/predict", body: Req(task: "fetch_firestore_regions"))
        regions = (r.regions ?? []).map { FirestoreRegion(id: $0.id, name: $0.name, location: $0.location, avgLatencyMs: $0.latency, isPrimary: $0.primary, status: $0.status) }
    }

    func getFirestore() -> Firestore {
        let settings = Firestore.firestore().settings
        if let region = activeRegion { settings.host = "\(region.location).firestore.googleapis.com" }
        let db = Firestore.firestore()
        db.settings = settings
        return db
    }
}
