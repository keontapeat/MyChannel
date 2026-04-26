//
//  VirtualGiftsService.swift
//  MyChannel
//
//  Phase 60: Virtual goods & animated gifts.
//  100% via StoreKit consumable IAP — NO external payment processors.
//  Creator receives a revenue split via Stripe Connect payout (web-only).
//

import Foundation
#if canImport(StoreKit)
import StoreKit
#endif

enum ServiceVirtualGift: String, CaseIterable, Codable {
    case heart       // 100 coins
    case rose        // 500 coins
    case crown       // 2500 coins
    case rocket      // 10_000 coins
    case diamond     // 50_000 coins

    var displayName: String {
        switch self {
        case .heart:   return "Heart"
        case .rose:    return "Rose"
        case .crown:   return "Crown"
        case .rocket:  return "Rocket"
        case .diamond: return "Diamond"
        }
    }

    var productId: String {
        switch self {
        case .heart:   return "com.mychannel.gift.heart.100"
        case .rose:    return "com.mychannel.gift.rose.500"
        case .crown:   return "com.mychannel.gift.crown.2500"
        case .rocket:  return "com.mychannel.gift.rocket.10k"
        case .diamond: return "com.mychannel.gift.diamond.50k"
        }
    }

    var coinCost: Int {
        switch self {
        case .heart:   return 100
        case .rose:    return 500
        case .crown:   return 2_500
        case .rocket:  return 10_000
        case .diamond: return 50_000
        }
    }

    /// Name of the Lottie animation file in the bundle for the explosion effect.
    var animationName: String { "gift_\(rawValue)" }
}

struct GiftSendResult: Codable {
    let ok: Bool
    let transactionId: String?
    let creatorSplitUSD: Double?
    let message: String?
}

@MainActor
final class VirtualGiftsService: ObservableObject {
    static let shared = VirtualGiftsService()
    private init() {}

    @Published var lastError: String?

    /// Buy (consumable) and send a gift to `creatorId` on `contextId` (live stream / video).
    @discardableResult
    func sendGift(
        _ gift: ServiceVirtualGift,
        from senderUid: String,
        to creatorId: String,
        contextId: String,
        message: String? = nil
    ) async throws -> GiftSendResult {
        guard AppConfig.Features.enableVirtualGifts else { throw GiftError.disabled }
        #if canImport(StoreKit)
        let products = try await Product.products(for: [gift.productId])
        guard let product = products.first else { throw GiftError.productMissing(gift.productId) }

        let purchase = try await product.purchase()
        switch purchase {
        case .success(let verification):
            guard case .verified(let tx) = verification else {
                throw GiftError.unverified
            }
            // 1) Finish the IAP locally
            await tx.finish()

            // 2) Tell backend to credit the creator (split), emit live animation event.
            struct Request: Encodable {
                let task: String
                let gift: String
                let senderUid: String
                let creatorId: String
                let contextId: String
                let message: String?
                let storeKitTxId: String
            }
            struct Raw: Decodable {
                let ok: Bool?
                let creator_split_usd: Double?
                let message: String?
            }
            let raw: Raw = try await CloudRunAgentRouter.post(
                .virtualGifts,
                path: "/predict",
                body: Request(
                    task: "redeem",
                    gift: gift.rawValue,
                    senderUid: senderUid,
                    creatorId: creatorId,
                    contextId: contextId,
                    message: message,
                    storeKitTxId: String(tx.id)
                )
            )
            return GiftSendResult(
                ok: raw.ok ?? true,
                transactionId: String(tx.id),
                creatorSplitUSD: raw.creator_split_usd,
                message: raw.message
            )
        case .userCancelled:
            return GiftSendResult(ok: false, transactionId: nil, creatorSplitUSD: nil, message: "cancelled")
        case .pending:
            return GiftSendResult(ok: false, transactionId: nil, creatorSplitUSD: nil, message: "pending")
        @unknown default:
            return GiftSendResult(ok: false, transactionId: nil, creatorSplitUSD: nil, message: "unknown")
        }
        #else
        throw GiftError.noStoreKit
        #endif
    }

    enum GiftError: LocalizedError {
        case disabled, productMissing(String), unverified, noStoreKit
        var errorDescription: String? {
            switch self {
            case .disabled: return "Virtual gifts are disabled."
            case .productMissing(let id): return "Product not found: \(id)"
            case .unverified: return "Purchase could not be verified."
            case .noStoreKit: return "StoreKit not available."
            }
        }
    }
}
