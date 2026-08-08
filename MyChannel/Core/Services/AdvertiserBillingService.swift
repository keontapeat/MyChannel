//
//  AdvertiserBillingService.swift
//  MyChannel
//
//  Prepaid advertiser balance management via the ads-billing Cloud Function.
//

import Foundation

enum AdvertiserBillingError: LocalizedError {
    case insufficientBalance
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .insufficientBalance: return "Insufficient ad account balance"
        case .networkError(let msg): return "Billing error: \(msg)"
        }
    }
}

/// Manages advertiser prepaid balance: fetch summary and debit per impression.
@MainActor
final class AdvertiserBillingService {
    static let shared = AdvertiserBillingService()
    private init() {}

    struct BillingSummary: Sendable, Decodable {
        let balanceCents: Int
        let currency: String
        let lastInvoiceId: String?
    }

    func fetchSummary(advertiserId: String) async throws -> BillingSummary {
        guard let token = try? await AuthenticationManager.sharedToken() else {
            return BillingSummary(balanceCents: 0, currency: "usd", lastInvoiceId: nil)
        }
        let url = URL(string: "\(AppConfig.API.gatewayBaseURL)/ads/billing/summary?advertiserId=\(advertiserId)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(BillingSummary.self, from: data)
    }

    func chargeImpression(campaignId: String, cpmCents: Int) async throws {
        guard let token = try? await AuthenticationManager.sharedToken() else {
            throw AdvertiserBillingError.networkError("Not authenticated")
        }
        let url = URL(string: "\(AppConfig.API.gatewayBaseURL)/ads/billing/charge")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "campaignId": campaignId,
            "cpmCents": cpmCents
        ])
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw AdvertiserBillingError.networkError("No response")
        }
        if http.statusCode == 402 {
            throw AdvertiserBillingError.insufficientBalance
        }
        guard http.statusCode == 200 else {
            throw AdvertiserBillingError.networkError("HTTP \(http.statusCode)")
        }
    }
}
