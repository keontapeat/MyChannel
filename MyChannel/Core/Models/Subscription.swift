//
//  Subscription.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

// MARK: - Subscription Model
struct Subscription: Identifiable, Codable, Equatable {
    let id: String
    let subscriberId: String
    let creatorId: String
    let createdAt: Date
    let isActive: Bool
    let notificationsEnabled: Bool
    
    init(
        id: String = UUID().uuidString,
        subscriberId: String,
        creatorId: String,
        createdAt: Date = Date(),
        isActive: Bool = true,
        notificationsEnabled: Bool = true
    ) {
        self.id = id
        self.subscriberId = subscriberId
        self.creatorId = creatorId
        self.createdAt = createdAt
        self.isActive = isActive
        self.notificationsEnabled = notificationsEnabled
    }
    
    // MARK: - Equatable
    static func == (lhs: Subscription, rhs: Subscription) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Subscription Stats Model
struct SubscriptionStats: Codable, Equatable {
    let totalSubscribers: Int
    let newSubscribersToday: Int
    let newSubscribersThisWeek: Int
    let newSubscribersThisMonth: Int
    let subscriberGrowthRate: Double // Percentage
    
    init(
        totalSubscribers: Int = 0,
        newSubscribersToday: Int = 0,
        newSubscribersThisWeek: Int = 0,
        newSubscribersThisMonth: Int = 0,
        subscriberGrowthRate: Double = 0.0
    ) {
        self.totalSubscribers = totalSubscribers
        self.newSubscribersToday = newSubscribersToday
        self.newSubscribersThisWeek = newSubscribersThisWeek
        self.newSubscribersThisMonth = newSubscribersThisMonth
        self.subscriberGrowthRate = subscriberGrowthRate
    }
    
    // MARK: - Equatable
    static func == (lhs: SubscriptionStats, rhs: SubscriptionStats) -> Bool {
        lhs.totalSubscribers == rhs.totalSubscribers &&
        lhs.newSubscribersToday == rhs.newSubscribersToday &&
        lhs.subscriberGrowthRate == rhs.subscriberGrowthRate
    }
}

// MARK: - Subscription Service Interface
protocol SubscriptionServiceProtocol {
    func subscribe(to creatorId: String) async throws -> Subscription
    func unsubscribe(from creatorId: String) async throws
    func isSubscribed(to creatorId: String) async throws -> Bool
    func getSubscriptions(for userId: String) async throws -> [Subscription]
    func getSubscribers(for creatorId: String) async throws -> [Subscription]
    func getSubscriptionStats(for creatorId: String) async throws -> SubscriptionStats
    func toggleNotifications(for subscriptionId: String) async throws -> Subscription
}

// MARK: - Mock Subscription Service
class MockSubscriptionService: SubscriptionServiceProtocol, ObservableObject {
    @Published var subscriptions: [Subscription] = []
    @Published var isLoading = false
    
    func subscribe(to creatorId: String) async throws -> Subscription {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let subscription = Subscription(
            subscriberId: "current-user-id",
            creatorId: creatorId
        )
        
        await MainActor.run {
            subscriptions.append(subscription)
        }
        
        return subscription
    }
    
    func unsubscribe(from creatorId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            subscriptions.removeAll { $0.creatorId == creatorId }
        }
    }
    
    func isSubscribed(to creatorId: String) async throws -> Bool {
        return subscriptions.contains { $0.creatorId == creatorId && $0.isActive }
    }
    
    func getSubscriptions(for userId: String) async throws -> [Subscription] {
        return subscriptions.filter { $0.subscriberId == userId }
    }
    
    func getSubscribers(for creatorId: String) async throws -> [Subscription] {
        return subscriptions.filter { $0.creatorId == creatorId }
    }
    
    func getSubscriptionStats(for creatorId: String) async throws -> SubscriptionStats {
        let subscribers = subscriptions.filter { $0.creatorId == creatorId }
        
        return SubscriptionStats(
            totalSubscribers: subscribers.count,
            newSubscribersToday: Int.random(in: 0...50),
            newSubscribersThisWeek: Int.random(in: 0...300),
            newSubscribersThisMonth: Int.random(in: 0...1200),
            subscriberGrowthRate: Double.random(in: -5...25)
        )
    }
    
    func toggleNotifications(for subscriptionId: String) async throws -> Subscription {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) else {
            throw NSError(domain: "SubscriptionError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Subscription not found"])
        }
        
        let updatedSubscription = Subscription(
            id: subscriptions[index].id,
            subscriberId: subscriptions[index].subscriberId,
            creatorId: subscriptions[index].creatorId,
            createdAt: subscriptions[index].createdAt,
            isActive: subscriptions[index].isActive,
            notificationsEnabled: !subscriptions[index].notificationsEnabled
        )
        
        subscriptions[index] = updatedSubscription
        return updatedSubscription
    }
}

// MARK: - Sample Data
extension Subscription {
    static let sampleSubscriptions: [Subscription] = [
        Subscription(
            subscriberId: "user-1",
            creatorId: User.sampleUsers[0].id,
            createdAt: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        ),
        Subscription(
            subscriberId: "user-1",
            creatorId: User.sampleUsers[1].id,
            createdAt: Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date()
        ),
        Subscription(
            subscriberId: "user-1",
            creatorId: User.sampleUsers[2].id,
            createdAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        ),
        Subscription(
            subscriberId: "user-1",
            creatorId: User.sampleUsers[3].id,
            createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        )
    ]
}

#Preview {
    VStack(spacing: 20) {
        Text("Subscription System")
            .font(.largeTitle)
            .fontWeight(.bold)
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription Features")
                .font(.headline)
            
            ForEach([
                "✅ Subscribe/Unsubscribe to creators",
                "🔔 Notification preferences",
                "📊 Subscription analytics",
                "👥 Subscriber management",
                "📈 Growth tracking"
            ], id: \.self) { feature in
                HStack {
                    Text(feature)
                        .font(.body)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        Spacer()
    }
    .padding()
}