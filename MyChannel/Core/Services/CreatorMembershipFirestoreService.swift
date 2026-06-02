//
//  CreatorMembershipFirestoreService.swift
//  MyChannel
//
//  Firestore-backed creator membership TIER DEFINITIONS (YouTube "Channel
//  Memberships" parity). This persists the tiers a creator offers — names,
//  prices, and perks. It does NOT move money: the actual subscription purchase
//  flow runs through StoreKit/IAP and is gated separately. Defining tiers is
//  configuration data, so it is safe for the creator to write their own.
//
//  Layout: membership_tiers/{tierId} with a `creatorId` field (flat collection,
//  public read so viewers can see what a channel offers, owner-only write).
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class CreatorMembershipFirestoreService: ObservableObject {
    static let shared = CreatorMembershipFirestoreService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    @Published var isLoading = false

    /// Fetch all membership tiers a creator has defined, cheapest first.
    func getTiers(for creatorId: String) async throws -> [MembershipTier] {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return [] }
        isLoading = true; defer { isLoading = false }
        let snap = try await db.collection("membership_tiers")
            .whereField("creatorId", isEqualTo: creatorId)
            .order(by: "price", descending: false)
            .getDocuments()
        return snap.documents.compactMap { doc -> MembershipTier? in
            let d = doc.data()
            guard let name = d["name"] as? String else { return nil }
            return MembershipTier(
                id: doc.documentID,
                name: name,
                description: d["description"] as? String ?? "",
                price: (d["price"] as? Double) ?? (d["price"] as? Int).map(Double.init) ?? 0,
                currency: d["currency"] as? String ?? "USD",
                benefits: d["benefits"] as? [String] ?? [],
                badgeColor: d["badgeColor"] as? String ?? "blue",
                isActive: d["isActive"] as? Bool ?? true
            )
        }
        #else
        return []
        #endif
    }

    /// Whether the creator has memberships turned on (stored on a settings doc).
    func isMembershipEnabled(for creatorId: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return false }
        let doc = try? await db.collection("creator_memberships").document(creatorId).getDocument()
        return (doc?.data()?["enabled"] as? Bool) ?? false
        #else
        return false
        #endif
    }

    func setMembershipEnabled(_ enabled: Bool, for creatorId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return }
        try await db.collection("creator_memberships").document(creatorId).setData([
            "enabled": enabled,
            "creatorId": creatorId,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }

    /// Create or update a tier. Returns the tier id.
    @discardableResult
    func saveTier(_ tier: MembershipTier, for creatorId: String) async throws -> String {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { throw NSError(domain: "Membership", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in required"]) }
        // Match the platform's price policy used by CreatorEconomyService.
        guard tier.price >= 0.99 && tier.price <= 999.99 else {
            throw NSError(domain: "Membership", code: 422, userInfo: [NSLocalizedDescriptionKey: "Tier price must be between $0.99 and $999.99"])
        }
        let data: [String: Any] = [
            "creatorId": creatorId,
            "name": tier.name,
            "description": tier.description,
            "price": tier.price,
            "currency": tier.currency,
            "benefits": tier.benefits,
            "badgeColor": tier.badgeColor,
            "isActive": tier.isActive,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        let ref = db.collection("membership_tiers").document(tier.id)
        try await ref.setData(data, merge: true)
        return tier.id
        #else
        return tier.id
        #endif
    }

    func deleteTier(_ tierId: String) async throws {
        #if canImport(FirebaseFirestore)
        try await db.collection("membership_tiers").document(tierId).delete()
        #endif
    }
}
