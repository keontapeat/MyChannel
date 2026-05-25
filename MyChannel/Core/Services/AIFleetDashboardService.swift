//
//  AIFleetDashboardService.swift
//  MyChannel
//
//  Phase 885: Real-Time AI Agent Fleet Dashboard
//  190+ Cloud Run agent status, task queues, inference latency, cost tracking
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class AIFleetDashboardService: ObservableObject {
    static let shared = AIFleetDashboardService()

    // MARK: - Domain Models

    struct AgentStatus: Identifiable, Codable {
        let id: String
        let agentName: String
        let cloudRunUrl: String
        let status: AgentHealth
        let taskQueueDepth: Int
        let inferenceLatencyP50: Double
        let inferenceLatencyP99: Double
        let costPerDay: Double
        let modelHealth: Double
        let coldStartsToday: Int
        let utilizationPercent: Double
        let lastActiveAt: Date
        let autoScaleEvents: Int
    }

    enum AgentHealth: String, Codable {
        case live = "LIVE"
        case idle = "IDLE"
        case coldStart = "COLD_START"
        case degraded = "DEGRADED"
        case offline = "OFFLINE"
    }

    struct FleetSummary: Codable {
        let totalAgents: Int
        let liveAgents: Int
        let idleAgents: Int
        let degradedAgents: Int
        let offlineAgents: Int
        let totalCostToday: Double
        let avgLatencyP50: Double
        let avgUtilization: Double
        let coldStartsTotal: Int
    }

    struct AgentCostBreakdown: Identifiable, Codable {
        let id: String
        let category: String
        let agentCount: Int
        let dailyCost: Double
        let monthlyCost: Double
        let costPerInference: Double
    }

    // MARK: - Published State

    @Published private(set) var agents: [AgentStatus] = []
    @Published private(set) var fleetSummary: FleetSummary?
    @Published private(set) var costBreakdown: [AgentCostBreakdown] = []
    @Published private(set) var utilizationHeatmap: [String: Double] = [:]
    @Published private(set) var isLoading = false

    private var db = Firestore.firestore()
    private var refreshTimer: Timer?

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://ai-fleet-dashboard-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableAIFleetDashboard else { return nil }
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
        guard AppConfig.Features.enableAIFleetDashboard else { return }
        isLoading = true
        defer { isLoading = false }

        // Load agent statuses from Firestore
        let snap = try? await db.collection("aiAgentStatus")
            .order(by: "lastActiveAt", descending: true)
            .limit(to: 200)
            .getDocuments()
        agents = snap?.documents.compactMap { doc in
            let d = doc.data()
            guard let health = AgentHealth(rawValue: d["status"] as? String ?? "") else { return nil }
            return AgentStatus(
                id: doc.documentID,
                agentName: d["agentName"] as? String ?? "",
                cloudRunUrl: d["cloudRunUrl"] as? String ?? "",
                status: health,
                taskQueueDepth: d["taskQueueDepth"] as? Int ?? 0,
                inferenceLatencyP50: d["inferenceLatencyP50"] as? Double ?? 0,
                inferenceLatencyP99: d["inferenceLatencyP99"] as? Double ?? 0,
                costPerDay: d["costPerDay"] as? Double ?? 0,
                modelHealth: d["modelHealth"] as? Double ?? 100,
                coldStartsToday: d["coldStartsToday"] as? Int ?? 0,
                utilizationPercent: d["utilizationPercent"] as? Double ?? 0,
                lastActiveAt: (d["lastActiveAt"] as? Timestamp)?.dateValue() ?? Date(),
                autoScaleEvents: d["autoScaleEvents"] as? Int ?? 0
            )
        } ?? []

        // Compute fleet summary
        let live = agents.filter { $0.status == .live }.count
        let idle = agents.filter { $0.status == .idle }.count
        let degraded = agents.filter { $0.status == .degraded }.count
        let offline = agents.filter { $0.status == .offline }.count
        fleetSummary = FleetSummary(
            totalAgents: agents.count,
            liveAgents: live,
            idleAgents: idle,
            degradedAgents: degraded,
            offlineAgents: offline,
            totalCostToday: agents.reduce(0) { $0 + $1.costPerDay },
            avgLatencyP50: agents.isEmpty ? 0 : agents.reduce(0.0) { $0 + $1.inferenceLatencyP50 } / Double(agents.count),
            avgUtilization: agents.isEmpty ? 0 : agents.reduce(0.0) { $0 + $1.utilizationPercent } / Double(agents.count),
            coldStartsTotal: agents.reduce(0) { $0 + $1.coldStartsToday }
        )

        // Build utilization heatmap
        utilizationHeatmap = Dictionary(grouping: agents, by: { $0.agentName.components(separatedBy: "-").first ?? "other" })
            .mapValues { $0.reduce(0.0) { $0 + $1.utilizationPercent } / Double($0.count) }

        // Cloud Run for cost breakdown
        if let result = await callCloudRun(endpoint: "cost-breakdown") {
            if let breakdown = result["breakdown"] as? [[String: Any]] {
                costBreakdown = breakdown.compactMap { d in
                    AgentCostBreakdown(
                        id: UUID().uuidString,
                        category: d["category"] as? String ?? "",
                        agentCount: d["agentCount"] as? Int ?? 0,
                        dailyCost: d["dailyCost"] as? Double ?? 0,
                        monthlyCost: d["monthlyCost"] as? Double ?? 0,
                        costPerInference: d["costPerInference"] as? Double ?? 0
                    )
                }
            }
        }
    }

    // MARK: - Actions

    func restartAgent(_ agentName: String) async {
        _ = await callCloudRun(endpoint: "restart", body: ["agentName": agentName])
    }

    func scaleAgent(_ agentName: String, instances: Int) async {
        _ = await callCloudRun(endpoint: "scale", body: ["agentName": agentName, "instances": instances])
    }

    func startAutoRefresh(intervalSeconds: TimeInterval = 120) {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
