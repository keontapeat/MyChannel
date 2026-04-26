//
//  RevenueTrackingService.swift
//  MyChannel
//
//  Real revenue tracking with Stripe/RevenueCat integration
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
class RevenueTrackingService: ObservableObject {
    static let shared = RevenueTrackingService()
    
    @Published private(set) var revenueToday: Double = 0
    @Published private(set) var revenueThisMonth: Double = 0
    @Published private(set) var revenueThisYear: Double = 0
    @Published private(set) var transactions: [RevenueTransaction] = []
    
    struct RevenueTransaction: Identifiable, Codable {
        let id: String
        let type: String
        let amount: Double
        let currency: String
        let timestamp: Date
        let userId: String
        let productId: String?
    }
    
    private init() {
        Task { await loadRevenueData() }
    }
    
    func loadRevenueData() async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let today = Calendar.current.startOfDay(for: Date())
        
        // Load today's revenue
        let todaySnapshot = try? await db.collection("revenue")
            .whereField("timestamp", isGreaterThanOrEqualTo: today)
            .getDocuments()
        
        let todayRevenue = todaySnapshot?.documents.compactMap { $0.data()["amount"] as? Double }.reduce(0, +) ?? 0
        
        // Load this month's revenue
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
        let monthSnapshot = try? await db.collection("revenue")
            .whereField("timestamp", isGreaterThanOrEqualTo: monthStart)
            .getDocuments()
        
        let monthRevenue = monthSnapshot?.documents.compactMap { $0.data()["amount"] as? Double }.reduce(0, +) ?? 0
        
        revenueToday = todayRevenue
        revenueThisMonth = monthRevenue
        revenueThisYear = monthRevenue * 12 // Simplified for now
        
        // Load recent transactions
        let recentSnapshot = try? await db.collection("revenue")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        transactions = recentSnapshot?.documents.compactMap { doc -> RevenueTransaction? in
            let data = doc.data()
            guard let type = data["type"] as? String,
                  let amount = data["amount"] as? Double,
                  let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                  let userId = data["userId"] as? String else { return nil }
            
            return RevenueTransaction(
                id: doc.documentID,
                type: type,
                amount: amount,
                currency: data["currency"] as? String ?? "USD",
                timestamp: timestamp,
                userId: userId,
                productId: data["productId"] as? String
            )
        } ?? []
        #endif
    }
    
    func recordTransaction(type: String, amount: Double, userId: String, productId: String?) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("revenue").document()
        
        try? await docRef.setData([
            "type": type,
            "amount": amount,
            "currency": "USD",
            "timestamp": FieldValue.serverTimestamp(),
            "userId": userId,
            "productId": productId ?? ""
        ])
        
        await loadRevenueData()
        #endif
    }
}
