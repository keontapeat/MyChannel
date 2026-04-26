//
//  ReferralService.swift
//  MyChannel
//
//  Phase 51: Referral & Invite Loop.
//  Generates invite codes, tracks K-factor, awards IAP-credit rewards via
//  the `referral-create` Cloud Run service + Firestore.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct GrowthReferralCode: Codable, Identifiable, Equatable {
    let id: String              // the code itself
    let ownerUid: String
    let createdAt: Date
    let uses: Int
    let maxUses: Int?
    let reward: ReferralReward
    let campaign: String?       // e.g. "launch-2026"

    enum ReferralReward: String, Codable {
        case onePlusMonth
        case sevenDayPlus
        case creatorFundBoost
        case storeCredit
    }
}

struct ReferralAttribution: Codable {
    let code: String
    let referrerUid: String
    let newUserUid: String
    let attributedAt: Date
}

struct KFactorSnapshot: Codable {
    let day: Date
    let invitesSent: Int
    let invitesAccepted: Int
    /// K-factor = accepted / total active referrers.
    let kFactor: Double
}

@MainActor
final class ReferralService: ObservableObject {
    static let shared = ReferralService()
    private init() {}

    @Published var myCode: GrowthReferralCode?
    @Published var kFactorToday: Double?
    @Published private(set) var isLoading = false

    // MARK: - Create / fetch code

    /// Mint or fetch the current user's referral code.
    func ensureMyCode(uid: String, campaign: String? = "launch-2026") async throws -> GrowthReferralCode {
        guard AppConfig.Features.enableReferralLoop else { throw ReferralError.disabled }

        struct Request: Encodable {
            let task: String
            let uid: String
            let campaign: String?
        }
        struct RawReply: Decodable {
            let code: String?
            let reward: String?
            let max_uses: Int?
        }

        isLoading = true
        defer { isLoading = false }

        let raw: RawReply = try await CloudRunAgentRouter.post(
            .referralCreate,
            path: "/predict",
            body: Request(task: "create_or_fetch", uid: uid, campaign: campaign)
        )

        let code = GrowthReferralCode(
            id: raw.code ?? Self.fallbackCode(uid: uid),
            ownerUid: uid,
            createdAt: Date(),
            uses: 0,
            maxUses: raw.max_uses,
            reward: .init(rawValue: raw.reward ?? "sevenDayPlus") ?? .sevenDayPlus,
            campaign: campaign
        )
        myCode = code
        return code
    }

    /// Called from the new user's onboarding when they paste/enter a code
    /// or arrive through a Universal Link.
    func attribute(code: String, newUserUid: String) async throws {
        guard AppConfig.Features.enableReferralLoop else { throw ReferralError.disabled }
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("referralAttributions").document(newUserUid).setData([
            "code": code,
            "newUserUid": newUserUid,
            "attributedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    /// Shareable Universal Link pointing at `mychannel.live/r/<code>`.
    func shareURL(for code: GrowthReferralCode) -> URL {
        URL(string: "https://mychannel.live/r/\(code.id)")!
    }

    // MARK: - K-factor

    /// Pull today's K-factor snapshot computed server-side.
    func loadKFactor() async throws -> KFactorSnapshot {
        guard AppConfig.Features.enableReferralLoop else { throw ReferralError.disabled }

        struct Request: Encodable { let task: String }
        struct Raw: Decodable {
            let invites_sent: Int?
            let invites_accepted: Int?
            let k_factor: Double?
        }
        let r: Raw = try await CloudRunAgentRouter.post(
            .referralCreate,
            path: "/predict",
            body: Request(task: "kfactor_today")
        )
        let snap = KFactorSnapshot(
            day: Calendar.current.startOfDay(for: Date()),
            invitesSent: r.invites_sent ?? 0,
            invitesAccepted: r.invites_accepted ?? 0,
            kFactor: r.k_factor ?? 0
        )
        kFactorToday = snap.kFactor
        return snap
    }

    // MARK: - Helpers

    private static func fallbackCode(uid: String) -> String {
        let seed = uid.prefix(4).uppercased() + String(Int.random(in: 1000...9999))
        return "MC-\(seed)"
    }

    enum ReferralError: LocalizedError {
        case disabled
        var errorDescription: String? {
            switch self {
            case .disabled: return "Referral program is not enabled."
            }
        }
    }
}
