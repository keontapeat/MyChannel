//
//  MicropaymentsService.swift
//  MyChannel
//
//  Phase 163: Micropayments & Pay-Per-View.
//  Per-video purchases, rental windows, early access pricing.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct PayPerViewOffer: Codable, Identifiable, Equatable {
    let id: String
    let videoId: String
    let creatorUid: String
    let type: PPVType
    let priceUSD: Double
    let rentalHours: Int?
    let earlyAccessHours: Int?
    let isActive: Bool
}

enum PPVType: String, Codable { case purchase, rental, earlyAccess }

struct PPVEntitlement: Codable, Identifiable {
    let id: String
    let uid: String
    let videoId: String
    let type: PPVType
    let purchasedAt: Date
    let expiresAt: Date?
}

// MARK: - Service

@MainActor
final class MicropaymentsService: ObservableObject {
    static let shared = MicropaymentsService()
    private init() {}

    @Published private(set) var offers: [PayPerViewOffer] = []
    @Published private(set) var entitlements: [PPVEntitlement] = []

    func loadOffers(videoId: String) async throws {
        guard AppConfig.Features.enableMicropayments else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("ppv_offers").whereField("videoId", isEqualTo: videoId)
            .whereField("isActive", isEqualTo: true).getDocuments()
        offers = snap.documents.compactMap { doc in
            let d = doc.data()
            return PayPerViewOffer(
                id: doc.documentID, videoId: d["videoId"] as? String ?? "",
                creatorUid: d["creatorUid"] as? String ?? "",
                type: PPVType(rawValue: d["type"] as? String ?? "") ?? .purchase,
                priceUSD: d["priceUSD"] as? Double ?? 0,
                rentalHours: d["rentalHours"] as? Int,
                earlyAccessHours: d["earlyAccessHours"] as? Int,
                isActive: true
            )
        }
        #endif
    }

    func hasAccess(uid: String, videoId: String) async -> Bool {
        guard AppConfig.Features.enableMicropayments else { return true }
        return entitlements.contains { $0.uid == uid && $0.videoId == videoId && ($0.expiresAt == nil || $0.expiresAt! > Date()) }
    }

    func purchase(uid: String, offerId: String) async throws -> PPVEntitlement? {
        guard AppConfig.Features.enableMicropayments else { return nil }
        guard let offer = offers.first(where: { $0.id == offerId }) else { return nil }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("ppv_entitlements").document()
        let expires: Date? = offer.rentalHours.map { Calendar.current.date(byAdding: .hour, value: $0, to: Date())! }
        try await ref.setData([
            "uid": uid, "videoId": offer.videoId, "type": offer.type.rawValue,
            "purchasedAt": FieldValue.serverTimestamp(),
            "expiresAt": expires.map { Timestamp(date: $0) } as Any
        ])
        let ent = PPVEntitlement(id: ref.documentID, uid: uid, videoId: offer.videoId,
                                 type: offer.type, purchasedAt: Date(), expiresAt: expires)
        entitlements.append(ent)
        return ent
        #else
        return nil
        #endif
    }

    func createOffer(videoId: String, creatorUid: String, type: PPVType, priceUSD: Double, rentalHours: Int? = nil) async throws -> String {
        guard AppConfig.Features.enableMicropayments else { return "" }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("ppv_offers").document()
        try await ref.setData([
            "videoId": videoId, "creatorUid": creatorUid, "type": type.rawValue,
            "priceUSD": priceUSD, "rentalHours": rentalHours as Any, "isActive": true
        ])
        return ref.documentID
        #else
        return ""
        #endif
    }
}
