//
//  AdRefundService.swift
//  MyChannel
//
//  Refund unused prepaid ad balance via the ads-billing Cloud Function.
//

import Foundation

enum AdRefundReason: String, Codable, Sendable {
    case campaignPaused
    case campaignCancelled
    case billingError
    case policyViolation
}

enum AdRefundError: LocalizedError {
    case nothingToRefund
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .nothingToRefund: return "No refundable ad spend on this campaign"
        case .networkError(let msg): return "Refund request failed: \(msg)"
        }
    }
}

/// Refunds unused prepaid ad balance by calling the ads-billing Cloud Function.
@MainActor
final class AdRefundService {
    static let shared = AdRefundService()
    private init() {}

    struct RefundRequest: Sendable {
        let campaignId: String
        let advertiserId: String
        let reason: AdRefundReason
        let idempotencyKey: String
    }

    struct RefundResponse: Decodable {
        let refundedCents: Int
        let transactionId: String
    }

    func requestRefund(_ request: RefundRequest) async throws -> Int {
        guard !request.campaignId.isEmpty else { throw AdRefundError.nothingToRefund }

        guard let token = try? await AuthenticationManager.sharedToken() else {
            throw AdRefundError.networkError("Not authenticated")
        }

        let url = URL(string: "\(AppConfig.API.gatewayBaseURL)/ads/refund")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(request.idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "campaignId": request.campaignId,
            "advertiserId": request.advertiserId,
            "reason": request.reason.rawValue
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AdRefundError.networkError("Server error \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let decoded = try JSONDecoder().decode(RefundResponse.self, from: data)
        return decoded.refundedCents
    }
}
