//
//  PredictiveAlertService.swift
//  MyChannel
//
//  Phase 886: Predictive Platform Alerts
//  ML-based anomaly prediction, capacity forecasting, revenue dip early warning
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class PredictiveAlertService: ObservableObject {
    static let shared = PredictiveAlertService()

    // MARK: - Domain Models

    struct PredictedAlert: Identifiable, Codable {
        let id: String
        let alertType: AlertType
        let severity: AlertSeverity
        let title: String
        let description: String
        let predictedAt: Date
        let expectedAt: Date
        let confidence: Double
        let affectedMetric: String
        let currentValue: Double
        let predictedValue: Double
        let recommendedAction: String
        let autoActionTaken: Bool
    }

    enum AlertType: String, Codable, CaseIterable {
        case anomaly = "ANOMALY"
        case capacity = "CAPACITY"
        case revenueDip = "REVENUE_DIP"
        case viralContent = "VIRAL_CONTENT"
        case infraStress = "INFRA_STRESS"
        case churnRisk = "CHURN_RISK"
        case fraudSpike = "FRAUD_SPIKE"
    }

    enum AlertSeverity: String, Codable {
        case critical = "CRITICAL"
        case high = "HIGH"
        case medium = "MEDIUM"
        case low = "LOW"
        case info = "INFO"
    }

    struct PredictionAccuracy: Codable {
        let alertType: AlertType
        let totalPredictions: Int
        let correctPredictions: Int
        let accuracyPercent: Double
        let falsePositiveRate: Double
        let averageLeadTimeMinutes: Double
    }

    // MARK: - Published State

    @Published private(set) var activePredictions: [PredictedAlert] = []
    @Published private(set) var predictionAccuracy: [PredictionAccuracy] = []
    @Published private(set) var isMonitoring = false
    @Published private(set) var lastPredictionTime: Date?
    @Published private(set) var predictionCount24h: Int = 0

    private var db = Firestore.firestore()
    private var monitorTimer: Timer?

    private init() {}

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://predictive-alerts-fkri6ifojq-uc.a.run.app"

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard AppConfig.Features.enablePredictiveAlerts else { return nil }
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

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.runPredictionCycle() }
        }
        Task { await runPredictionCycle() }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        isMonitoring = false
    }

    func runPredictionCycle() async {
        guard AppConfig.Features.enablePredictiveAlerts else { return }
        lastPredictionTime = Date()

        // Call Cloud Run prediction endpoint
        if let result = await callCloudRun(endpoint: "predict") {
            if let predictions = result["predictions"] as? [[String: Any]] {
                activePredictions = predictions.compactMap { parsePrediction($0) }
            }
            predictionCount24h = result["predictionCount24h"] as? Int ?? predictionCount24h

            if let accuracy = result["accuracy"] as? [[String: Any]] {
                predictionAccuracy = accuracy.compactMap { d in
                    guard let type = AlertType(rawValue: d["alertType"] as? String ?? "") else { return nil }
                    return PredictionAccuracy(
                        alertType: type,
                        totalPredictions: d["totalPredictions"] as? Int ?? 0,
                        correctPredictions: d["correctPredictions"] as? Int ?? 0,
                        accuracyPercent: d["accuracyPercent"] as? Double ?? 0,
                        falsePositiveRate: d["falsePositiveRate"] as? Double ?? 0,
                        averageLeadTimeMinutes: d["averageLeadTimeMinutes"] as? Double ?? 0
                    )
                }
            }
        }

        // Persist high-confidence predictions
        for prediction in activePredictions where prediction.confidence >= 0.8 {
            try? await db.collection("predictedAlerts").document(prediction.id).setData([
                "alertType": prediction.alertType.rawValue,
                "severity": prediction.severity.rawValue,
                "title": prediction.title,
                "description": prediction.description,
                "predictedAt": Timestamp(date: prediction.predictedAt),
                "expectedAt": Timestamp(date: prediction.expectedAt),
                "confidence": prediction.confidence,
                "affectedMetric": prediction.affectedMetric,
                "currentValue": prediction.currentValue,
                "predictedValue": prediction.predictedValue,
                "recommendedAction": prediction.recommendedAction,
                "autoActionTaken": prediction.autoActionTaken
            ])
        }
    }

    func dismissPrediction(_ id: String) {
        activePredictions.removeAll { $0.id == id }
        Task {
            try? await db.collection("predictedAlerts").document(id).updateData(["dismissed": true])
        }
    }

    // MARK: - Helpers

    private func parsePrediction(_ d: [String: Any]) -> PredictedAlert? {
        guard let type = AlertType(rawValue: d["alertType"] as? String ?? ""),
              let severity = AlertSeverity(rawValue: d["severity"] as? String ?? ""),
              let title = d["title"] as? String else { return nil }
        return PredictedAlert(
            id: d["id"] as? String ?? UUID().uuidString,
            alertType: type,
            severity: severity,
            title: title,
            description: d["description"] as? String ?? "",
            predictedAt: (d["predictedAt"] as? Timestamp)?.dateValue() ?? Date(),
            expectedAt: (d["expectedAt"] as? Timestamp)?.dateValue() ?? Date(),
            confidence: d["confidence"] as? Double ?? 0,
            affectedMetric: d["affectedMetric"] as? String ?? "",
            currentValue: d["currentValue"] as? Double ?? 0,
            predictedValue: d["predictedValue"] as? Double ?? 0,
            recommendedAction: d["recommendedAction"] as? String ?? "",
            autoActionTaken: d["autoActionTaken"] as? Bool ?? false
        )
    }
}
