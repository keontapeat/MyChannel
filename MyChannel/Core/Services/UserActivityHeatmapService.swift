//
//  UserActivityHeatmapService.swift
//  MyChannel
//
//  Phase 883: Real-Time User Activity Heatmap
//  Live user activity by region, device distribution, feature usage, session quality
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class UserActivityHeatmapService: ObservableObject {
    static let shared = UserActivityHeatmapService()

    // MARK: - Domain Models

    struct RegionActivity: Identifiable, Codable {
        let id: String
        let region: String
        let countryCode: String
        let activeUsers: Int
        let newUsers: Int
        let avgSessionMinutes: Double
        let engagementScore: Double
        let topFeature: String
    }

    struct DeviceDistribution: Identifiable, Codable {
        let id: String
        let deviceType: String
        let count: Int
        let percentage: Double
        let avgSessionMinutes: Double
        let crashRate: Double
    }

    struct FeatureUsage: Identifiable, Codable {
        let id: String
        let feature: String
        let activeUsers: Int
        let usageCount24h: Int
        let adoptionRate: Double
        let satisfactionScore: Double
    }

    struct SessionQuality: Identifiable, Codable {
        let id: String
        let qualityBand: String
        let userCount: Int
        let avgDuration: Double
        let avgActions: Int
        let retentionLikelihood: Double
    }

    struct SignupVelocity: Identifiable, Codable {
        let id: String
        let timestamp: Date
        let signupsPerHour: Int
        let signupsPerDay: Int
        let conversionRate: Double
        let topSource: String
    }

    // MARK: - Published State

    @Published private(set) var regionActivity: [RegionActivity] = []
    @Published private(set) var deviceDistribution: [DeviceDistribution] = []
    @Published private(set) var featureUsage: [FeatureUsage] = []
    @Published private(set) var sessionQuality: [SessionQuality] = []
    @Published private(set) var signupVelocity: SignupVelocity?
    @Published private(set) var concurrentUsers: Int = 0
    @Published private(set) var engagementIntensity: Double = 0

    private var db = Firestore.firestore()
    private var refreshTimer: Timer?

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://user-heatmap-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableUserActivityHeatmap else { return nil }
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
        guard AppConfig.Features.enableUserActivityHeatmap else { return }

        // Load region activity
        let regionSnap = try? await db.collection("userActivityByRegion")
            .order(by: "activeUsers", descending: true)
            .limit(to: 20)
            .getDocuments()
        regionActivity = regionSnap?.documents.compactMap { doc in
            let d = doc.data()
            return RegionActivity(
                id: doc.documentID,
                region: d["region"] as? String ?? "",
                countryCode: d["countryCode"] as? String ?? "",
                activeUsers: d["activeUsers"] as? Int ?? 0,
                newUsers: d["newUsers"] as? Int ?? 0,
                avgSessionMinutes: d["avgSessionMinutes"] as? Double ?? 0,
                engagementScore: d["engagementScore"] as? Double ?? 0,
                topFeature: d["topFeature"] as? String ?? ""
            )
        } ?? []

        // Load device distribution
        let deviceSnap = try? await db.collection("deviceDistribution")
            .order(by: "count", descending: true)
            .limit(to: 10)
            .getDocuments()
        deviceDistribution = deviceSnap?.documents.compactMap { doc in
            let d = doc.data()
            return DeviceDistribution(
                id: doc.documentID,
                deviceType: d["deviceType"] as? String ?? "",
                count: d["count"] as? Int ?? 0,
                percentage: d["percentage"] as? Double ?? 0,
                avgSessionMinutes: d["avgSessionMinutes"] as? Double ?? 0,
                crashRate: d["crashRate"] as? Double ?? 0
            )
        } ?? []

        // Load feature usage
        let featureSnap = try? await db.collection("featureUsage")
            .order(by: "activeUsers", descending: true)
            .limit(to: 15)
            .getDocuments()
        featureUsage = featureSnap?.documents.compactMap { doc in
            let d = doc.data()
            return FeatureUsage(
                id: doc.documentID,
                feature: d["feature"] as? String ?? "",
                activeUsers: d["activeUsers"] as? Int ?? 0,
                usageCount24h: d["usageCount24h"] as? Int ?? 0,
                adoptionRate: d["adoptionRate"] as? Double ?? 0,
                satisfactionScore: d["satisfactionScore"] as? Double ?? 0
            )
        } ?? []

        // Load session quality
        let sessionSnap = try? await db.collection("sessionQuality")
            .order(by: "userCount", descending: true)
            .limit(to: 5)
            .getDocuments()
        sessionQuality = sessionSnap?.documents.compactMap { doc in
            let d = doc.data()
            return SessionQuality(
                id: doc.documentID,
                qualityBand: d["qualityBand"] as? String ?? "",
                userCount: d["userCount"] as? Int ?? 0,
                avgDuration: d["avgDuration"] as? Double ?? 0,
                avgActions: d["avgActions"] as? Int ?? 0,
                retentionLikelihood: d["retentionLikelihood"] as? Double ?? 0
            )
        } ?? []

        // Cloud Run for real-time concurrent users & intensity
        if let result = await callCloudRun(endpoint: "realtime") {
            concurrentUsers = result["concurrentUsers"] as? Int ?? 0
            engagementIntensity = result["engagementIntensity"] as? Double ?? 0
            let vel = result["signupVelocity"] as? [String: Any]
            if let vel {
                signupVelocity = SignupVelocity(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    signupsPerHour: vel["signupsPerHour"] as? Int ?? 0,
                    signupsPerDay: vel["signupsPerDay"] as? Int ?? 0,
                    conversionRate: vel["conversionRate"] as? Double ?? 0,
                    topSource: vel["topSource"] as? String ?? ""
                )
            }
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
