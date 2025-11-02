//
//  FeaturedVideoPaymentService.swift
//  MyChannel
//
//  Service for handling featured video payments using StoreKit
//

import Foundation
import StoreKit
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class FeaturedVideoPaymentService: ObservableObject {
    static let shared = FeaturedVideoPaymentService()
    
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var availableProducts: [Product] = []
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    // Product IDs for featured video durations (configure in App Store Connect)
    private let productIDs: [FeaturedVideoRequest.FeaturedDuration: String] = [
        .oneDay: "mychannel.feat.1day",
        .oneWeek: "mychannel.feat.1week",
        .twoWeeks: "mychannel.feat.2weeks",
        .oneMonth: "mychannel.feat.1month"
    ]
    
    private init() {
        Task {
            await loadProducts()
        }
    }
    
    // MARK: - Product Loading
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        let ids = Array(productIDs.values)
        do {
            let products = try await Product.products(for: Set(ids))
            availableProducts = products
        } catch {
            lastError = error.localizedDescription
            print("❌ Error loading featured video products: \(error)")
        }
    }
    
    // MARK: - Purchase Featured Video
    func purchaseFeaturedVideo(
        video: Video,
        duration: FeaturedVideoRequest.FeaturedDuration,
        customDays: Int? = nil
    ) async throws -> FeaturedVideoRequest {
        
        guard let product = availableProducts.first(where: { $0.id == productIDs[duration] ?? "" }) else {
            throw FeaturedVideoError.productNotFound
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Process payment
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // Create request in Firestore
                let request = try await createFeaturedRequest(
                    video: video,
                    duration: duration,
                    customDays: customDays,
                    transactionId: String(transaction.id),
                    amount: Double(truncating: NSDecimalNumber(decimal: product.price))
                )
                
                // Finish transaction
                await transaction.finish()
                
                return request
                
            case .unverified(_, let error):
                throw FeaturedVideoError.paymentVerificationFailed(error.localizedDescription)
            }
            
        case .userCancelled:
            throw FeaturedVideoError.userCancelled
            
        case .pending:
            throw FeaturedVideoError.paymentPending
            
        @unknown default:
            throw FeaturedVideoError.unknownError
        }
    }
    
    // MARK: - Create Featured Request
    private func createFeaturedRequest(
        video: Video,
        duration: FeaturedVideoRequest.FeaturedDuration,
        customDays: Int?,
        transactionId: String,
        amount: Double
    ) async throws -> FeaturedVideoRequest {
        
        let now = Date()
        let days = duration == .custom ? (customDays ?? 1) : duration.days
        let expiresAt = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        
        let request = FeaturedVideoRequest(
            id: UUID().uuidString,
            videoId: video.id,
            creatorId: video.creatorId,
            videoTitle: video.title,
            videoThumbnail: video.thumbnailURL,
            creatorName: video.creator.displayName,
            requestedDuration: duration,
            amountPaid: amount,
            paymentTransactionId: transactionId,
            paymentStatus: .completed,
            paidAt: now,
            status: .pending,
            reviewedBy: nil,
            reviewedAt: nil,
            rejectionReason: nil,
            featuredAt: nil,
            expiresAt: expiresAt,
            isActive: false,
            createdAt: now,
            updatedAt: now
        )
        
        #if canImport(FirebaseFirestore)
        // Save to Firestore
        let ref = db.collection("featured_video_requests").document(request.id)
        try await ref.setData([
            "id": request.id,
            "videoId": request.videoId,
            "creatorId": request.creatorId,
            "videoTitle": request.videoTitle,
            "videoThumbnail": request.videoThumbnail,
            "creatorName": request.creatorName,
            "requestedDuration": request.requestedDuration.rawValue,
            "amountPaid": request.amountPaid,
            "paymentTransactionId": request.paymentTransactionId,
            "paymentStatus": request.paymentStatus.rawValue,
            "paidAt": Timestamp(date: request.paidAt),
            "status": request.status.rawValue,
            "reviewedBy": NSNull(),
            "reviewedAt": NSNull(),
            "rejectionReason": NSNull(),
            "featuredAt": NSNull(),
            "expiresAt": Timestamp(date: request.expiresAt ?? now),
            "isActive": request.isActive,
            "createdAt": Timestamp(date: request.createdAt),
            "updatedAt": Timestamp(date: request.updatedAt)
        ])
        #endif
        
        return request
    }
    
    // MARK: - Get Price for Duration
    func getPrice(for duration: FeaturedVideoRequest.FeaturedDuration) -> Double {
        if let product = availableProducts.first(where: { $0.id == productIDs[duration] ?? "" }) {
            return Double(truncating: NSDecimalNumber(decimal: product.price))
        }
        return duration.price // Fallback to hardcoded price
    }
}

// MARK: - Featured Video Errors
enum FeaturedVideoError: LocalizedError {
    case productNotFound
    case paymentVerificationFailed(String)
    case userCancelled
    case paymentPending
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Featured video product not found. Please try again."
        case .paymentVerificationFailed(let reason):
            return "Payment verification failed: \(reason)"
        case .userCancelled:
            return "Payment was cancelled"
        case .paymentPending:
            return "Payment is pending approval"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

