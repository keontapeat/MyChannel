//
//  MerchCheckoutService.swift
//  MyChannel
//
//  Buyer-side checkout for PHYSICAL creator merchandise.
//
//  ⚖️ APPLE COMPLIANCE: Physical goods/services consumed outside the app MUST
//  use an external payment processor (Apple Guideline 3.1.3(e)). This flow uses
//  Stripe — NOT Apple IAP. The Stripe secret key never touches the client: we
//  call the authenticated `escrow-payments` Cloud Function, which derives price,
//  stock, totals, and the creator's connected account SERVER-SIDE, then confirm
//  the returned PaymentIntent with the Stripe PaymentSheet.
//

import Foundation
import SwiftUI
#if canImport(StripePaymentSheet)
import StripePaymentSheet
#endif

// MARK: - Shipping address (buyer-entered)

struct MerchShippingAddress: Equatable {
    var line1: String = ""
    var line2: String = ""
    var city: String = ""
    var state: String = ""
    var postalCode: String = ""
    var country: String = "US"

    var isComplete: Bool {
        !line1.trimmingCharacters(in: .whitespaces).isEmpty &&
        !city.trimmingCharacters(in: .whitespaces).isEmpty &&
        !postalCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        country.count == 2
    }

    var asDictionary: [String: Any] {
        [
            "line1": line1,
            "line2": line2,
            "city": city,
            "state": state,
            "postalCode": postalCode,
            "country": country.uppercased()
        ]
    }
}

enum MerchCheckoutError: LocalizedError {
    case notAuthenticated
    case backend(String)
    case invalidResponse
    case stripeUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Please sign in to check out."
        case .backend(let m): return m
        case .invalidResponse: return "Unexpected response from the store."
        case .stripeUnavailable: return "Payments are not available in this build."
        }
    }
}

@MainActor
final class MerchCheckoutService: ObservableObject {
    static let shared = MerchCheckoutService()
    private init() {}

    @Published var isProcessing = false

    private let backendAPIBaseURL = "https://us-central1-mychannel-ca26d.cloudfunctions.net"

    struct CreatedOrder {
        let orderId: String
        let clientSecret: String
        let amountCents: Int
    }

    /// Ask the backend to create the order + PaymentIntent. The server owns all
    /// money math; we only pass the product id, quantity, and shipping address.
    func createOrder(productId: String, quantity: Int, shipping: MerchShippingAddress) async throws -> CreatedOrder {
        guard AuthenticationManager.shared.currentUser?.id != nil else {
            throw MerchCheckoutError.notAuthenticated
        }
        isProcessing = true
        defer { isProcessing = false }

        let url = URL(string: "\(backendAPIBaseURL)/create-merch-order")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AuthTokenProvider.authorize(&request)

        let body: [String: Any] = [
            "productId": productId,
            "quantity": quantity,
            "shippingAddress": shipping.asDictionary
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.configured.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MerchCheckoutError.invalidResponse
        }
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200...299).contains(http.statusCode) else {
            let msg = (json?["error"] as? String) ?? "Checkout failed (\(http.statusCode))"
            throw MerchCheckoutError.backend(msg)
        }
        guard let orderId = json?["orderId"] as? String,
              let clientSecret = json?["clientSecret"] as? String,
              let amount = json?["amount"] as? Int else {
            throw MerchCheckoutError.invalidResponse
        }
        return CreatedOrder(orderId: orderId, clientSecret: clientSecret, amountCents: amount)
    }

    /// Present the Stripe PaymentSheet to confirm the charge. Returns true on
    /// successful payment. The order is finalized server-side by the Stripe
    /// webhook — the client NEVER marks an order paid.
    func confirmPayment(clientSecret: String, merchantName: String = "MyChannel") async throws -> Bool {
        #if canImport(StripePaymentSheet)
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = merchantName
        config.allowsDelayedPaymentMethods = false

        let paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: config)

        guard let presenter = Self.topViewController() else {
            throw MerchCheckoutError.stripeUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            paymentSheet.present(from: presenter) { result in
                switch result {
                case .completed:
                    continuation.resume(returning: true)
                case .canceled:
                    continuation.resume(returning: false)
                case .failed(let error):
                    continuation.resume(throwing: MerchCheckoutError.backend(error.localizedDescription))
                }
            }
        }
        #else
        throw MerchCheckoutError.stripeUnavailable
        #endif
    }

    #if canImport(UIKit)
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
    #endif
}
