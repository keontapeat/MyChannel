//
//  MLAnomalyDetectionService.swift
//  MyChannel
//
//  Anomaly Detection Dashboard - ML-powered anomaly detection, threshold alerts
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class MLAnomalyDetectionService: ObservableObject {
    static let shared = MLAnomalyDetectionService()
    
    @Published private(set) var detectedAnomalies: [Anomaly] = []
    @Published private(set) var anomalyScore: Double = 0
    @Published private(set) var baselineMetrics: [String: Double] = [:]
    @Published private(set) var thresholdBreaches: [ThresholdBreach] = []
    
    struct Anomaly: Identifiable, Codable {
        let id: String
        let metric: String
        let currentValue: Double
        let expectedValue: Double
        let deviationPercentage: Double
        let severity: String
        let detectedAt: Date
        let suggestedAction: String?
        let rootCause: String?
    }
    
    struct ThresholdBreach: Identifiable, Codable {
        let id: String
        let metric: String
        let threshold: Double
        let currentValue: Double
        let breachTime: Date
        let isCritical: Bool
    }
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.detectAnomalies() }
        }
        Task { await detectAnomalies() }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func detectAnomalies() async {
        guard AppConfig.Features.enableAnalyticsPredictor else { return }
        
        struct Req: Encodable { let task: String }
        struct RawAnomaly: Decodable { let id: String; let metric: String; let currentValue: Double; let expectedValue: Double; let deviationPercentage: Double; let severity: String; let detectedAt: String; let suggestedAction: String?; let rootCause: String? }
        struct RawBreach: Decodable { let id: String; let metric: String; let threshold: Double; let currentValue: Double; let breachTime: String; let isCritical: Bool }
        struct Raw: Decodable { let detectedAnomalies: [RawAnomaly]?; let anomalyScore: Double?; let baselineMetrics: [String: Double]?; let thresholdBreaches: [RawBreach]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "detect_anomalies"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            detectedAnomalies = (r.detectedAnomalies ?? []).map {
                Anomaly(
                    id: $0.id,
                    metric: $0.metric,
                    currentValue: $0.currentValue,
                    expectedValue: $0.expectedValue,
                    deviationPercentage: $0.deviationPercentage,
                    severity: $0.severity,
                    detectedAt: decoder.date(from: $0.detectedAt) ?? Date(),
                    suggestedAction: $0.suggestedAction,
                    rootCause: $0.rootCause
                )
            }.sorted { $0.deviationPercentage > $1.deviationPercentage }
            
            thresholdBreaches = (r.thresholdBreaches ?? []).map {
                ThresholdBreach(
                    id: $0.id,
                    metric: $0.metric,
                    threshold: $0.threshold,
                    currentValue: $0.currentValue,
                    breachTime: decoder.date(from: $0.breachTime) ?? Date(),
                    isCritical: $0.isCritical
                )
            }
            
            anomalyScore = r.anomalyScore ?? 0
            baselineMetrics = r.baselineMetrics ?? [:]
            
            for anomaly in detectedAnomalies.filter({ $0.severity == "critical" }) {
                try? await EnhancedAlertSystemService.shared.createAlert(
                    type: "anomaly",
                    severity: "critical",
                    title: "Anomaly: \(anomaly.metric)",
                    message: "Deviation: \(String(format: "%.1f%%", anomaly.deviationPercentage)) - \(anomaly.rootCause ?? "Unknown cause")",
                    source: "ml_anomaly_detection"
                )
            }
            
        } catch {
            print("⚠️ [MLAnomalyDetection] Error: \(error)")
        }
    }
    
    func setThreshold(metric: String, threshold: Double, isCritical: Bool) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("metricThresholds").document(metric).setData([
            "metric": metric,
            "threshold": threshold,
            "isCritical": isCritical,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #endif
    }
}
