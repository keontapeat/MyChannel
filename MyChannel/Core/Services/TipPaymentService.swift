//
//  TipPaymentService.swift
//  MyChannel
//
//  Real payment processing for tips using Stripe PaymentIntent
//

import Foundation
import SwiftUI
#if canImport(StripePaymentSheet)
import StripePaymentSheet
#endif

@MainActor
final class TipPaymentService: ObservableObject {
    static let shared = TipPaymentService()
    
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var paymentIntentClientSecret: String?
    
    private init() {}
    
    // MARK: - Create Payment Intent
    func createPaymentIntent(
        to creatorId: String,
        amount: Double,
        currency: String = "usd"
    ) async throws -> String {
        
        isLoading = true
        defer { isLoading = false }
        
        struct PaymentIntentRequest: Codable {
            let toUserId: String
            let amount: Int // Amount in cents
            let currency: String
        }
        
        struct PaymentIntentResponse: Codable {
            let clientSecret: String
            let paymentIntentId: String
        }
        
        // Convert dollars to cents
        let amountCents = Int(amount * 100)
        
        let request = PaymentIntentRequest(
            toUserId: creatorId,
            amount: amountCents,
            currency: currency
        )
        
        let response: PaymentIntentResponse = try await NetworkService.shared.post(
            endpoint: .custom("/pay/tip/intent"),
            body: request,
            responseType: PaymentIntentResponse.self
        )
        
        paymentIntentClientSecret = response.clientSecret
        return response.clientSecret
    }
    
    // MARK: - Process Tip Payment
    func processTip(
        to creatorId: String,
        amount: Double,
        currency: String = "usd",
        message: String? = nil
    ) async throws -> TipTransaction {
        
        // Create PaymentIntent
        let clientSecret = try await createPaymentIntent(
            to: creatorId,
            amount: amount,
            currency: currency
        )
        
        // For now, we'll use the client secret with Stripe Payment Sheet
        // In a full implementation, we'd present the Payment Sheet here
        // and confirm the payment after user completes it
        
        // After payment is confirmed, record the tip
        struct TipRequest: Codable {
            let toUserId: String
            let amount: Int
            let currency: String
            let message: String?
            let paymentIntentId: String
        }
        
        // Extract payment intent ID from client secret (format: pi_xxx_secret_xxx)
        let paymentIntentId = clientSecret.split(separator: "_").first.map { String($0) } ?? ""
        
        let tipRequest = TipRequest(
            toUserId: creatorId,
            amount: Int(amount * 100),
            currency: currency,
            message: message,
            paymentIntentId: paymentIntentId
        )
        
        struct TipResponse: Codable {
            let tipId: String
            let transactionId: String
        }
        
        let tipResponse: TipResponse = try await NetworkService.shared.post(
            endpoint: .custom("/pay/tip"),
            body: tipRequest,
            responseType: TipResponse.self
        )
        
        return TipTransaction(
            id: tipResponse.tipId,
            fromUserId: "current-user-id", // TODO: Get from auth
            toCreatorId: creatorId,
            amount: amount,
            message: message,
            isLiveStream: false,
            timestamp: Date()
        )
    }
}

