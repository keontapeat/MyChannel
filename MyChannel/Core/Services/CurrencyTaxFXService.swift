//
//  CurrencyTaxFXService.swift
//  MyChannel
//
//  Phase 65: Currency, Tax, and FX.
//  Wraps the `tax-optimization-ai` Cloud Run service to:
//    • format amounts in the caller's StoreKit storefront currency
//    • estimate VAT/GST included in subscription prices
//    • convert payout earnings between USD and the creator's bank currency
//

import Foundation
#if canImport(StoreKit)
import StoreKit
#endif

struct FXQuote: Codable {
    let fromISO: String      // "USD"
    let toISO: String        // "EUR"
    let rate: Double
    let asOf: Date
}

struct TaxBreakdown: Codable {
    let currency: String
    let subtotal: Decimal
    let vatRate: Double        // 0..1
    let vatAmount: Decimal
    let total: Decimal
    let jurisdiction: String
}

@MainActor
final class CurrencyTaxFXService: ObservableObject {
    static let shared = CurrencyTaxFXService()
    private init() {}

    @Published private(set) var storefrontCurrency: String = "USD"

    func refreshStorefront() async {
        #if canImport(StoreKit)
        if let storefront = await Storefront.current {
            storefrontCurrency = storefront.countryCode
        }
        #endif
    }

    // MARK: - FX

    /// Live rate (24h-cached server-side). Safe to call often.
    func fxRate(from: String, to: String) async throws -> FXQuote {
        guard AppConfig.Features.enableTaxFX else {
            return FXQuote(fromISO: from, toISO: to, rate: 1.0, asOf: Date())
        }
        struct Request: Encodable { let task: String; let from: String; let to: String }
        struct Raw: Decodable { let rate: Double?; let as_of: Double? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .taxOptimization,
            path: "/predict",
            body: Request(task: "fx_rate", from: from, to: to)
        )
        return FXQuote(
            fromISO: from,
            toISO: to,
            rate: r.rate ?? 1.0,
            asOf: r.as_of.map { Date(timeIntervalSince1970: $0) } ?? Date()
        )
    }

    // MARK: - Tax

    /// Estimate VAT/GST for a display-time price using the caller's country.
    func taxEstimate(
        amountUSD: Decimal,
        countryCode: String,
        category: String = "digital_subscription"
    ) async throws -> TaxBreakdown {
        guard AppConfig.Features.enableTaxFX else {
            return TaxBreakdown(
                currency: "USD",
                subtotal: amountUSD,
                vatRate: 0,
                vatAmount: 0,
                total: amountUSD,
                jurisdiction: countryCode
            )
        }
        struct Request: Encodable {
            let task: String
            let amount_usd: Double
            let country: String
            let category: String
        }
        struct Raw: Decodable {
            let currency: String?
            let subtotal: Double?
            let vat_rate: Double?
            let vat_amount: Double?
            let total: Double?
            let jurisdiction: String?
        }
        let r: Raw = try await CloudRunAgentRouter.post(
            .taxOptimization,
            path: "/predict",
            body: Request(
                task: "estimate_vat",
                amount_usd: (amountUSD as NSDecimalNumber).doubleValue,
                country: countryCode,
                category: category
            )
        )
        return TaxBreakdown(
            currency: r.currency ?? "USD",
            subtotal: Decimal(r.subtotal ?? (amountUSD as NSDecimalNumber).doubleValue),
            vatRate: r.vat_rate ?? 0,
            vatAmount: Decimal(r.vat_amount ?? 0),
            total: Decimal(r.total ?? (amountUSD as NSDecimalNumber).doubleValue),
            jurisdiction: r.jurisdiction ?? countryCode
        )
    }

    // MARK: - Formatting

    func formatPrice(_ amount: Decimal, currencyCode: String = "USD") -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
