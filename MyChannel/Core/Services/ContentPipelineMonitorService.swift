//
//  ContentPipelineMonitorService.swift
//  MyChannel
//
//  Phase 884: Real-Time Content Pipeline Monitor
//  Upload→transcode→publish pipeline health, queue depths, error rates, CDN propagation
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ContentPipelineMonitorService: ObservableObject {
    static let shared = ContentPipelineMonitorService()

    // MARK: - Domain Models

    struct PipelineStage: Identifiable, Codable {
        let id: String
        let name: String
        let queueDepth: Int
        let processingCount: Int
        let completedCount: Int
        let errorCount: Int
        let avgLatencySeconds: Double
        let p99LatencySeconds: Double
        let healthStatus: String
    }

    struct PipelineError: Identifiable, Codable {
        let id: String
        let stage: String
        let errorType: String
        let message: String
        let videoId: String
        let timestamp: Date
        let retryCount: Int
        let resolved: Bool
    }

    struct CDNPropagationStatus: Identifiable, Codable {
        let id: String
        let region: String
        let propagationPercent: Double
        let avgLatencyMs: Int
        let cacheHitRate: Double
        let originPulls: Int
    }

    struct ContentFreshness: Identifiable, Codable {
        let id: String
        let metric: String
        let value: Double
        let target: Double
        let status: String
    }

    // MARK: - Published State

    @Published private(set) var stages: [PipelineStage] = []
    @Published private(set) var recentErrors: [PipelineError] = []
    @Published private(set) var cdnStatus: [CDNPropagationStatus] = []
    @Published private(set) var freshnessMetrics: [ContentFreshness] = []
    @Published private(set) var totalQueueDepth: Int = 0
    @Published private(set) var pipelineHealth: Double = 100
    @Published private(set) var throughputPerMinute: Int = 0
    @Published private(set) var errorRate: Double = 0

    private var db = Firestore.firestore()
    private var refreshTimer: Timer?

    private init() {
        Task { await refresh() }
    }

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://pipeline-monitor-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enableContentPipelineMonitor else { return nil }
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
        guard AppConfig.Features.enableContentPipelineMonitor else { return }

        // Load pipeline stages
        let stageSnap = try? await db.collection("pipelineStages")
            .order(by: "name")
            .getDocuments()
        stages = stageSnap?.documents.compactMap { doc in
            let d = doc.data()
            return PipelineStage(
                id: doc.documentID,
                name: d["name"] as? String ?? "",
                queueDepth: d["queueDepth"] as? Int ?? 0,
                processingCount: d["processingCount"] as? Int ?? 0,
                completedCount: d["completedCount"] as? Int ?? 0,
                errorCount: d["errorCount"] as? Int ?? 0,
                avgLatencySeconds: d["avgLatencySeconds"] as? Double ?? 0,
                p99LatencySeconds: d["p99LatencySeconds"] as? Double ?? 0,
                healthStatus: d["healthStatus"] as? String ?? "healthy"
            )
        } ?? []
        totalQueueDepth = stages.reduce(0) { $0 + $1.queueDepth }

        // Load recent errors
        let errorSnap = try? await db.collection("pipelineErrors")
            .order(by: "timestamp", descending: true)
            .limit(to: 20)
            .getDocuments()
        recentErrors = errorSnap?.documents.compactMap { doc in
            let d = doc.data()
            return PipelineError(
                id: doc.documentID,
                stage: d["stage"] as? String ?? "",
                errorType: d["errorType"] as? String ?? "",
                message: d["message"] as? String ?? "",
                videoId: d["videoId"] as? String ?? "",
                timestamp: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                retryCount: d["retryCount"] as? Int ?? 0,
                resolved: d["resolved"] as? Bool ?? false
            )
        } ?? []

        // Load CDN status
        let cdnSnap = try? await db.collection("cdnPropagation")
            .getDocuments()
        cdnStatus = cdnSnap?.documents.compactMap { doc in
            let d = doc.data()
            return CDNPropagationStatus(
                id: doc.documentID,
                region: d["region"] as? String ?? "",
                propagationPercent: d["propagationPercent"] as? Double ?? 0,
                avgLatencyMs: d["avgLatencyMs"] as? Int ?? 0,
                cacheHitRate: d["cacheHitRate"] as? Double ?? 0,
                originPulls: d["originPulls"] as? Int ?? 0
            )
        } ?? []

        // Cloud Run for real-time metrics
        if let result = await callCloudRun(endpoint: "health") {
            pipelineHealth = result["pipelineHealth"] as? Double ?? 100
            throughputPerMinute = result["throughputPerMinute"] as? Int ?? 0
            errorRate = result["errorRate"] as? Double ?? 0
            if let freshness = result["freshnessMetrics"] as? [[String: Any]] {
                freshnessMetrics = freshness.compactMap { d in
                    ContentFreshness(
                        id: UUID().uuidString,
                        metric: d["metric"] as? String ?? "",
                        value: d["value"] as? Double ?? 0,
                        target: d["target"] as? Double ?? 0,
                        status: d["status"] as? String ?? "ok"
                    )
                }
            }
        }
    }

    // MARK: - Actions

    func triggerReprocess(videoId: String) async {
        _ = await callCloudRun(endpoint: "reprocess", body: ["videoId": videoId])
    }

    func clearStuckQueue(stage: String) async {
        _ = await callCloudRun(endpoint: "clear-stuck", body: ["stage": stage])
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
