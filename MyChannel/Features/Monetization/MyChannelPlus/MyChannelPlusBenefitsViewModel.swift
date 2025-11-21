//
//  MyChannelPlusBenefitsViewModel.swift
//  MyChannel
//
//  Created by AI Assistant
//

import Foundation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class MyChannelPlusBenefitsViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var memberSince: Date?
    @Published var stats: PremiumStats = .empty
    @Published var benefits: [MyChannelPlusBenefit] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Load Data
    
    func loadBenefitsData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load user data
            if let userId = getCurrentUserId() {
                currentUser = try await UserFirestoreService.shared.fetchUser(id: userId)
            }
            
            // Load subscription data
            if let subscription = try await loadSubscriptionData() {
                memberSince = subscription.startDate
            }
            
            // Load premium stats
            stats = try await loadPremiumStats()
            
            // Load benefits & offers
            benefits = try await loadBenefits()
            
            print("✅ [Plus Benefits] Data loaded successfully")
        } catch {
            print("🚨 [Plus Benefits] Error loading data: \(error)")
            self.error = error
        }
    }
    
    // MARK: - Load Subscription Data
    
    private func loadSubscriptionData() async throws -> MyChannelPlusSubscription? {
        guard let userId = getCurrentUserId() else { return nil }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let doc = try await db.collection("subscriptions")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "active")
            .whereField("plan", isEqualTo: "plus")
            .limit(to: 1)
            .getDocuments()
            .documents
            .first
        
        guard let data = doc?.data() else { return nil }
        
        return MyChannelPlusSubscription(
            id: doc?.documentID ?? "",
            userId: userId,
            plan: "plus",
            status: "active",
            startDate: (data["startDate"] as? Timestamp)?.dateValue() ?? Date(),
            endDate: (data["endDate"] as? Timestamp)?.dateValue(),
            price: data["price"] as? Double ?? 14.99
        )
        #else
        return nil
        #endif
    }
    
    // MARK: - Load Premium Stats
    
    private func loadPremiumStats() async throws -> PremiumStats {
        guard let userId = getCurrentUserId() else { return .empty }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let doc = try await db.collection("premium_stats").document(userId).getDocument()
        
        guard let data = doc.data() else { return .empty }
        
        return PremiumStats(
            adFreeHours: data["adFreeHours"] as? Int ?? 0,
            backgroundPlayHours: data["backgroundPlayHours"] as? Int ?? 0,
            videosDownloaded: data["videosDownloaded"] as? Int ?? 0,
            liveStreamsWatched: data["liveStreamsWatched"] as? Int ?? 0,
            vsMatchesParticipated: data["vsMatchesParticipated"] as? Int ?? 0,
            exclusiveContentHours: data["exclusiveContentHours"] as? Int ?? 0
        )
        #else
        return .empty
        #endif
    }
    
    // MARK: - Load Benefits
    
    private func loadBenefits() async throws -> [MyChannelPlusBenefit] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snapshot = try await db.collection("plus_benefits")
            .whereField("isActive", isEqualTo: true)
            .order(by: "priority")
            .limit(to: 10)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            return MyChannelPlusBenefit(
                id: doc.documentID,
                title: data["title"] as? String ?? "",
                description: data["description"] as? String ?? "",
                imageURL: data["imageURL"] as? String ?? "",
                actionURL: data["actionURL"] as? String
            )
        }
        #else
        // Mock data for development
        return [
            MyChannelPlusBenefit(
                id: "1",
                title: "Download videos for offline viewing",
                description: "Watch your favorite videos anywhere, anytime",
                imageURL: "https://picsum.photos/280/180",
                actionURL: nil
            ),
            MyChannelPlusBenefit(
                id: "2",
                title: "Exclusive Plus content",
                description: "Access premium shows and movies",
                imageURL: "https://picsum.photos/280/180",
                actionURL: nil
            ),
            MyChannelPlusBenefit(
                id: "3",
                title: "Priority customer support",
                description: "Get help when you need it",
                imageURL: "https://picsum.photos/280/180",
                actionURL: nil
            )
        ]
        #endif
    }
    
    // MARK: - Track Stat
    
    func trackStat(_ type: PremiumStatType, value: Double = 1.0) async {
        guard let userId = getCurrentUserId() else { return }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let ref = db.collection("premium_stats").document(userId)
        
        do {
            let fieldName: String
            switch type {
            case .adFreeWatchTime:
                fieldName = "adFreeHours"
            case .backgroundPlay:
                fieldName = "backgroundPlayHours"
            case .videoDownload:
                fieldName = "videosDownloaded"
            case .liveStreamWatch:
                fieldName = "liveStreamsWatched"
            case .vsMatchParticipation:
                fieldName = "vsMatchesParticipated"
            case .exclusiveContent:
                fieldName = "exclusiveContentHours"
            }
            
            try await ref.setData([
                fieldName: FieldValue.increment(Int64(value)),
                "lastUpdated": FieldValue.serverTimestamp()
            ], merge: true)
            
            print("✅ [Plus Stats] Tracked \(type): +\(value)")
        } catch {
            print("🚨 [Plus Stats] Error tracking stat: \(error)")
        }
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
}

// MARK: - Models

struct PremiumStats {
    var adFreeHours: Int
    var backgroundPlayHours: Int
    var videosDownloaded: Int
    var liveStreamsWatched: Int
    var vsMatchesParticipated: Int
    var exclusiveContentHours: Int
    
    static let empty = PremiumStats(
        adFreeHours: 0,
        backgroundPlayHours: 0,
        videosDownloaded: 0,
        liveStreamsWatched: 0,
        vsMatchesParticipated: 0,
        exclusiveContentHours: 0
    )
}

struct MyChannelPlusBenefit: Identifiable {
    let id: String
    let title: String
    let description: String
    let imageURL: String
    let actionURL: String?
}

struct MyChannelPlusSubscription {
    let id: String
    let userId: String
    let plan: String
    let status: String
    let startDate: Date
    let endDate: Date?
    let price: Double
}

enum PremiumStatType {
    case adFreeWatchTime
    case backgroundPlay
    case videoDownload
    case liveStreamWatch
    case vsMatchParticipation
    case exclusiveContent
}

