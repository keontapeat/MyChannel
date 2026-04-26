//
//  InfraCommandService.swift
//  MyChannel
//
//  Phase 894: Infrastructure Command Dashboard
//  Cost trends, auto-scaling events, SLO compliance, incident history, capacity heatmap
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class InfraCommandService: ObservableObject {
    static let shared = InfraCommandService()

    // MARK: - Domain Models

    struct CostTrend: Identifiable, Codable {
        let id: String
        let date: Date
        let service: String
        let cost: Double
        let budget: Double
        let variance: Double
        let recommendation: String?
    }

    struct ScalingEvent: Identifiable, Codable {
        let id: String
        let service: String
        let eventType: String
        let fromInstances: Int
        let toInstances: Int
        let trigger: String
        let timestamp: Date
    }

    struct SLOCompliance: Identifiable, Codable {
        let id: String
        let service: String
        let sloTarget: Double
        let actualPerformance: Double
        let compliance: Double
        let errorBudgetRemaining: Double
        let status: String
    }

    struct IncidentHistory: Identifiable, Codable {
        let id: String
        let title: String
        let severity: String
        let affectedServices: [String]
        let startedAt: Date
        let resolvedAt: Date?
        let mttrMinutes: Int?
        let rootCause: String?
    }

    struct CapacityHeatmap: Identifiable, Codable {
        let id: String
        let service: String
        let region: String
        let utilizationPercent: Double
        let reservedInstances: Int
        let onDemandInstances: Int
        let reservedCost: Double
        let onDemandCost: Double
        let riskScore: Double
    }

    // MARK: - Published State

    @Published private(set) var costTrends: [CostTrend] = []
    @Published private(set) var scalingEvents: [ScalingEvent] = []
    @Published private(set) var sloCompliance: [SLOCompliance] = []
    @Published private(set) var incidentHistory: [IncidentHistory] = []
    @Published private(set) var capacityHeatmap: [CapacityHeatmap] = []
    @Published private(set) var totalMonthlyCost: Double = 0
    @Published private(set) var infraRiskScore: Double = 0
    @Published private(set) var sloOverallCompliance: Double = 100

    private var db = Firestore.firestore()

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://infra-command-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableInfraCommand else { return nil }
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Refresh

    func refresh() async {
        guard AppConfig.Features.enableInfraCommand else { return }

        // Load SLO compliance from Firestore
        let sloSnap = try? await db.collection("sloCompliance").getDocuments()
        sloCompliance = sloSnap?.documents.compactMap { doc in
            let d = doc.data()
            return SLOCompliance(
                id: doc.documentID,
                service: d["service"] as? String ?? "",
                sloTarget: d["sloTarget"] as? Double ?? 99.9,
                actualPerformance: d["actualPerformance"] as? Double ?? 100,
                compliance: d["compliance"] as? Double ?? 100,
                errorBudgetRemaining: d["errorBudgetRemaining"] as? Double ?? 100,
                status: d["status"] as? String ?? "healthy"
            )
        } ?? []
        sloOverallCompliance = sloCompliance.isEmpty ? 100 : sloCompliance.reduce(0.0) { $0 + $1.compliance } / Double(sloCompliance.count)

        // Load incident history
        let incidentSnap = try? await db.collection("incidents")
            .order(by: "startedAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        incidentHistory = incidentSnap?.documents.compactMap { doc in
            let d = doc.data()
            return IncidentHistory(
                id: doc.documentID,
                title: d["title"] as? String ?? "",
                severity: d["severity"] as? String ?? "LOW",
                affectedServices: d["affectedServices"] as? [String] ?? [],
                startedAt: (d["startedAt"] as? Timestamp)?.dateValue() ?? Date(),
                resolvedAt: (d["resolvedAt"] as? Timestamp)?.dateValue(),
                mttrMinutes: d["mttrMinutes"] as? Int,
                rootCause: d["rootCause"] as? String
            )
        } ?? []

        // Cloud Run for cost, scaling, capacity
        if let result = await callCloudRun(endpoint: "dashboard") {
            if let costs = result["costTrends"] as? [[String: Any]] {
                costTrends = costs.compactMap { d in
                    CostTrend(
                        id: UUID().uuidString,
                        date: (d["date"] as? Timestamp)?.dateValue() ?? Date(),
                        service: d["service"] as? String ?? "",
                        cost: d["cost"] as? Double ?? 0,
                        budget: d["budget"] as? Double ?? 0,
                        variance: d["variance"] as? Double ?? 0,
                        recommendation: d["recommendation"] as? String
                    )
                }
            }
            if let events = result["scalingEvents"] as? [[String: Any]] {
                scalingEvents = events.compactMap { d in
                    ScalingEvent(
                        id: UUID().uuidString,
                        service: d["service"] as? String ?? "",
                        eventType: d["eventType"] as? String ?? "",
                        fromInstances: d["fromInstances"] as? Int ?? 0,
                        toInstances: d["toInstances"] as? Int ?? 0,
                        trigger: d["trigger"] as? String ?? "",
                        timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    )
                }
            }
            if let cap = result["capacityHeatmap"] as? [[String: Any]] {
                capacityHeatmap = cap.compactMap { d in
                    CapacityHeatmap(
                        id: UUID().uuidString,
                        service: d["service"] as? String ?? "",
                        region: d["region"] as? String ?? "",
                        utilizationPercent: d["utilizationPercent"] as? Double ?? 0,
                        reservedInstances: d["reservedInstances"] as? Int ?? 0,
                        onDemandInstances: d["onDemandInstances"] as? Int ?? 0,
                        reservedCost: d["reservedCost"] as? Double ?? 0,
                        onDemandCost: d["onDemandCost"] as? Double ?? 0,
                        riskScore: d["riskScore"] as? Double ?? 0
                    )
                }
            }
            totalMonthlyCost = result["totalMonthlyCost"] as? Double ?? 0
            infraRiskScore = result["infraRiskScore"] as? Double ?? 0
        }
    }
}
