//
//  RevenuePulseService.swift
//  MyChannel
//
//  Phase 882: Real-Time Revenue Pulse
//  Live revenue ticker, ad fill rate, subscription churn alerts, payout health
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class RevenuePulseService: ObservableObject {
    static let shared = RevenuePulseService()

    // MARK: - Domain Models

    struct RevenueTick: Identifiable, Codable {
        let id: String
        let timestamp: Date
        let totalRevenue: Double
        let adRevenue: Double
        let subscriptionRevenue: Double
        let commerceRevenue: Double
        let arpu: Double
        let rpm: Double
    }

    struct AdFillMetrics: Identifiable, Codable {
        let id: String
        let timestamp: Date
        let fillRate: Double
        let ecpm: Double
        let impressions: Int
        let requests: Int
        let byAdType: [String: Double]
    }

    struct SubscriptionPulse: Identifiable, Codable {
        let id: String
        let timestamp: Date
        let activeSubscribers: Int
        let newSubscriptions: Int
        let churned: Int
        let churnRate: Double
        let mrr: Double
        let arr: Double
    }

    struct PayoutHealth: Identifiable, Codable {
        let id: String
        let timestamp: Date
        let pendingPayouts: Int
        let totalPayoutAmount: Double
        let avgSettlementHours: Double
        let failedPayouts: Int
        let slaCompliance: Double
    }

    struct RevenueAlert: Identifiable, Codable {
        let id: String
        let type: String
        let severity: String
        let message: String
        let metric: String
        let currentValue: Double
        let expectedValue: Double
        let timestamp: Date
    }

    // MARK: - Published State

    @Published private(set) var currentTick: RevenueTick?
    @Published private(set) var tickHistory: [RevenueTick] = []
    @Published private(set) var adFillMetrics: AdFillMetrics?
    @Published private(set) var subscriptionPulse: SubscriptionPulse?
    @Published private(set) var payoutHealth: PayoutHealth?
    @Published private(set) var revenueAlerts: [RevenueAlert] = []
    @Published private(set) var revenueToday: Double = 0
    @Published private(set) var revenueDelta: Double = 0
    @Published private(set) var forecastVsActual: Double = 0

    private var db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var refreshTimer: Timer?

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://revenue-pulse-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableRevenuePulse else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.configured.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableRevenuePulse else { return }

        // Load revenue ticks
        let tickSnap = try? await db.collection("revenueTicks")
            .order(by: "timestamp", descending: true)
            .limit(to: 60)
            .getDocuments()
        tickHistory = tickSnap?.documents.compactMap { doc in
            let d = doc.data()
            return RevenueTick(
                id: doc.documentID,
                timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                totalRevenue: d["totalRevenue"] as? Double ?? 0,
                adRevenue: d["adRevenue"] as? Double ?? 0,
                subscriptionRevenue: d["subscriptionRevenue"] as? Double ?? 0,
                commerceRevenue: d["commerceRevenue"] as? Double ?? 0,
                arpu: d["arpu"] as? Double ?? 0,
                rpm: d["rpm"] as? Double ?? 0
            )
        } ?? []
        currentTick = tickHistory.first
        revenueToday = currentTick?.totalRevenue ?? 0

        // Load ad fill
        let adSnap = try? await db.collection("adFillMetrics")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments()
        adFillMetrics = adSnap?.documents.first.map { doc in
            let d = doc.data()
            return AdFillMetrics(
                id: doc.documentID,
                timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                fillRate: d["fillRate"] as? Double ?? 0,
                ecpm: d["ecpm"] as? Double ?? 0,
                impressions: d["impressions"] as? Int ?? 0,
                requests: d["requests"] as? Int ?? 0,
                byAdType: d["byAdType"] as? [String: Double] ?? [:]
            )
        }

        // Load subscription pulse
        let subSnap = try? await db.collection("subscriptionPulse")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments()
        subscriptionPulse = subSnap?.documents.first.map { doc in
            let d = doc.data()
            return SubscriptionPulse(
                id: doc.documentID,
                timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                activeSubscribers: d["activeSubscribers"] as? Int ?? 0,
                newSubscriptions: d["newSubscriptions"] as? Int ?? 0,
                churned: d["churned"] as? Int ?? 0,
                churnRate: d["churnRate"] as? Double ?? 0,
                mrr: d["mrr"] as? Double ?? 0,
                arr: d["arr"] as? Double ?? 0
            )
        }

        // Load payout health
        let payoutSnap = try? await db.collection("payoutHealth")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments()
        payoutHealth = payoutSnap?.documents.first.map { doc in
            let d = doc.data()
            return PayoutHealth(
                id: doc.documentID,
                timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                pendingPayouts: d["pendingPayouts"] as? Int ?? 0,
                totalPayoutAmount: d["totalPayoutAmount"] as? Double ?? 0,
                avgSettlementHours: d["avgSettlementHours"] as? Double ?? 0,
                failedPayouts: d["failedPayouts"] as? Int ?? 0,
                slaCompliance: d["slaCompliance"] as? Double ?? 0
            )
        }

        // Load revenue alerts
        let alertSnap = try? await db.collection("revenueAlerts")
            .order(by: "timestamp", descending: true)
            .limit(to: 10)
            .getDocuments()
        revenueAlerts = alertSnap?.documents.compactMap { doc in
            let d = doc.data()
            return RevenueAlert(
                id: doc.documentID,
                type: d["type"] as? String ?? "",
                severity: d["severity"] as? String ?? "info",
                message: d["message"] as? String ?? "",
                metric: d["metric"] as? String ?? "",
                currentValue: d["currentValue"] as? Double ?? 0,
                expectedValue: d["expectedValue"] as? Double ?? 0,
                timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            )
        } ?? []

        // Cloud Run for forecast vs actual
        if let result = await callCloudRun(endpoint: "forecast") {
            forecastVsActual = result["forecastVsActual"] as? Double ?? 0
        }
    }

    func startAutoRefresh(intervalSeconds: TimeInterval = 60) {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
