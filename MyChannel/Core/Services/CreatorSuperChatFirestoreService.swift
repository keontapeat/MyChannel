//
//  CreatorSuperChatFirestoreService.swift
//  MyChannel
//
//  Firestore-backed Super Chat / tips CONFIG + a real read of money already
//  received. Settings (enabled, minimum amount) are creator-owned config. The
//  recent-activity feed reads REAL `super-thanks` documents addressed to this
//  creator — it does NOT create or move money. Sending money stays in
//  SuperThanksSheet / TipPaymentService, which run the actual payment flow.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - A received Super Chat / Super Thanks entry

struct SuperChatEntry: Identifiable, Equatable {
    let id: String
    var senderName: String
    var amount: Double
    var message: String
    var date: Date

    static func == (lhs: SuperChatEntry, rhs: SuperChatEntry) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class CreatorSuperChatFirestoreService: ObservableObject {
    static let shared = CreatorSuperChatFirestoreService()
    private init() {}

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif

    @Published var isLoading = false

    // MARK: - Settings (creator-owned config)

    struct SuperChatSettings {
        var enabled: Bool
        var minimumAmount: Double
    }

    func getSettings(for creatorId: String) async -> SuperChatSettings {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return SuperChatSettings(enabled: false, minimumAmount: 1) }
        let doc = try? await db.collection("creator_superchat_settings").document(creatorId).getDocument()
        let d = doc?.data()
        return SuperChatSettings(
            enabled: d?["enabled"] as? Bool ?? false,
            minimumAmount: (d?["minimumAmount"] as? Double) ?? (d?["minimumAmount"] as? Int).map(Double.init) ?? 1
        )
        #else
        return SuperChatSettings(enabled: false, minimumAmount: 1)
        #endif
    }

    func saveSettings(_ settings: SuperChatSettings, for creatorId: String) async throws {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return }
        guard settings.minimumAmount >= 1 && settings.minimumAmount <= 500 else {
            throw NSError(domain: "SuperChat", code: 422, userInfo: [NSLocalizedDescriptionKey: "Minimum must be between $1 and $500"])
        }
        try await db.collection("creator_superchat_settings").document(creatorId).setData([
            "enabled": settings.enabled,
            "minimumAmount": settings.minimumAmount,
            "creatorId": creatorId,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        #endif
    }

    // MARK: - Real received activity (read-only)

    /// Recent Super Thanks addressed to this creator. Reads the existing
    /// `super-thanks` collection written by SuperThanksSheet.
    func recentSuperChats(for creatorId: String, limit: Int = 20) async throws -> [SuperChatEntry] {
        #if canImport(FirebaseFirestore)
        guard !creatorId.isEmpty else { return [] }
        isLoading = true; defer { isLoading = false }
        let snap = try await db.collection("super-thanks")
            .whereField("creatorId", isEqualTo: creatorId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snap.documents.map { doc in
            let d = doc.data()
            return SuperChatEntry(
                id: doc.documentID,
                senderName: d["senderName"] as? String ?? "Supporter",
                amount: (d["amount"] as? Double) ?? (d["amount"] as? Int).map(Double.init) ?? 0,
                message: d["message"] as? String ?? "",
                date: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #else
        return []
        #endif
    }

    /// Lifetime total received from Super Thanks (creator's gross).
    func totalReceived(for creatorId: String) async -> Double {
        let entries = (try? await recentSuperChats(for: creatorId, limit: 500)) ?? []
        return entries.reduce(0) { $0 + $1.amount }
    }
}
