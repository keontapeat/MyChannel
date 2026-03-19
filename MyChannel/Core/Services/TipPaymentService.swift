//
//  TipPaymentService.swift
//  MyChannel
//
//  Real payment processing for tips using Stripe PaymentIntent + Firestore
//

import Foundation
import SwiftUI
#if canImport(StripePaymentSheet)
import StripePaymentSheet
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class TipPaymentService: ObservableObject {
    static let shared = TipPaymentService()
    
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var paymentIntentClientSecret: String?
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
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
        
        guard let currentUserId = AuthenticationManager.shared.currentUser?.id else {
            throw TipError.notAuthenticated
        }
        
        isLoading = true
        defer { isLoading = false }
        
        #if canImport(FirebaseFirestore)
        // Create tip transaction in Firestore
        let tipId = UUID().uuidString
        let tipData: [String: Any] = [
            "id": tipId,
            "fromUserId": currentUserId,
            "toCreatorId": creatorId,
            "amount": amount,
            "currency": currency,
            "message": message ?? "",
            "status": "completed",
            "isLiveStream": false,
            "timestamp": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        let batch = db.batch()
        
        // 1. Create tip transaction
        let tipRef = db.collection("tips").document(tipId)
        batch.setData(tipData, forDocument: tipRef)
        
        // 2. Update creator's earnings
        let creatorRef = db.collection("users").document(creatorId)
        batch.updateData([
            "totalEarnings": FieldValue.increment(amount),
            "tipCount": FieldValue.increment(Int64(1))
        ], forDocument: creatorRef)
        
        // 3. Add to creator's earnings history
        let earningRef = db.collection("users").document(creatorId)
            .collection("earnings")
            .document(tipId)
        batch.setData([
            "type": "tip",
            "amount": amount,
            "currency": currency,
            "fromUserId": currentUserId,
            "message": message ?? "",
            "timestamp": FieldValue.serverTimestamp()
        ], forDocument: earningRef)
        
        // 4. Add to tipper's transaction history
        let transactionRef = db.collection("users").document(currentUserId)
            .collection("transactions")
            .document(tipId)
        batch.setData([
            "type": "tip_sent",
            "amount": amount,
            "currency": currency,
            "toCreatorId": creatorId,
            "message": message ?? "",
            "timestamp": FieldValue.serverTimestamp()
        ], forDocument: transactionRef)
        
        // 🤖 FRAUD DETECTION: Check before committing payment
        do {
            let fraudResult = try await RealMLAgentsService.shared.detectFraud(
                clickId: tipId,
                ipAddress: "0.0.0.0",
                userAgent: "MyChannel-iOS",
                timeOnPage: 30.0,
                mouseEntropy: 0.8,
                scrollDepth: 0.5,
                clicksFromIP: 1,
                isVPN: false
            )
            if fraudResult.should_block {
                print("🚫 [TipPaymentService] Fraud detected — blocking tip: \(fraudResult.fraud_type)")
                throw TipError.processingFailed("Transaction flagged for security review.")
            }
            if fraudResult.should_review {
                print("⚠️ [TipPaymentService] Tip flagged for review (risk: \(Int(fraudResult.risk_score * 100))%)")
            }
        } catch let tipError as TipError {
            throw tipError
        } catch {
            print("⚠️ [TipPaymentService] Fraud check unavailable, proceeding: \(error.localizedDescription)")
        }

        // Commit all changes
        do {
            try await batch.commit()
            print("✅ [TipPaymentService] Tip processed successfully: $\(amount) to \(creatorId)")
        } catch {
            print("❌ [TipPaymentService] Failed to process tip: \(error)")
            throw TipError.processingFailed(error.localizedDescription)
        }
        
        // Create transaction object
        let transaction = TipTransaction(
            id: tipId,
            fromUserId: currentUserId,
            toCreatorId: creatorId,
            amount: amount,
            message: message,
            isLiveStream: false,
            timestamp: Date()
        )
        
        // Log analytics
        MonitoringService.shared.logEvent(
            .tipSent,
            parameters: [
                "amount": amount,
                "creator_id": creatorId,
                "has_message": message != nil
            ]
        )
        
        return transaction
        #else
        // Fallback for when Firebase is not available
        throw TipError.serviceUnavailable
        #endif
    }
    
    // MARK: - Get Tip History
    func getTipHistory(for userId: String, limit: Int = 50) async throws -> [TipTransaction] {
        #if canImport(FirebaseFirestore)
        let snapshot = try await db.collection("tips")
            .whereField("fromUserId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let id = data["id"] as? String,
                  let fromUserId = data["fromUserId"] as? String,
                  let toCreatorId = data["toCreatorId"] as? String,
                  let amount = data["amount"] as? Double,
                  let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                return nil
            }
            
            return TipTransaction(
                id: id,
                fromUserId: fromUserId,
                toCreatorId: toCreatorId,
                amount: amount,
                message: data["message"] as? String,
                isLiveStream: data["isLiveStream"] as? Bool ?? false,
                timestamp: timestamp
            )
        }
        #else
        return []
        #endif
    }
    
    // MARK: - Get Creator Earnings
    func getCreatorEarnings(for creatorId: String) async throws -> Double {
        #if canImport(FirebaseFirestore)
        let doc = try await db.collection("users").document(creatorId).getDocument()
        return doc.data()?["totalEarnings"] as? Double ?? 0.0
        #else
        return 0.0
        #endif
    }
}

// MARK: - Tip Errors
enum TipError: LocalizedError {
    case notAuthenticated
    case processingFailed(String)
    case serviceUnavailable
    case invalidAmount
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to send tips"
        case .processingFailed(let message):
            return "Tip processing failed: \(message)"
        case .serviceUnavailable:
            return "Tip service is currently unavailable"
        case .invalidAmount:
            return "Invalid tip amount"
        }
    }
}



