import Foundation
import Combine

@MainActor
final class MonetizationPerformanceService: ObservableObject {
    static let shared = MonetizationPerformanceService()

    struct MonetizationMetric: Identifiable, Codable {
        let id: String
        let metricName: String
        let currentValue: Double
        let targetValue: Double
        let status: String
    }

    struct MonetizationAlert: Identifiable, Codable {
        let id: String
        let title: String
        let severity: String
        let message: String
    }

    @Published private(set) var metrics: [MonetizationMetric] = []
    @Published private(set) var alerts: [MonetizationAlert] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableMonetizationPerformance else { return }

        metrics = [
            MonetizationMetric(id: UUID().uuidString, metricName: "Revenue per DAU", currentValue: 1.84, targetValue: 2.1, status: "warning"),
            MonetizationMetric(id: UUID().uuidString, metricName: "Payout SLA", currentValue: 0.97, targetValue: 0.99, status: "warning")
        ]
        alerts = [
            MonetizationAlert(id: UUID().uuidString, title: "Payout latency elevated", severity: "medium", message: "Average settlement time exceeds the 24h target."),
            MonetizationAlert(id: UUID().uuidString, title: "Shorts fill rate improving", severity: "info", message: "Ad demand forecast indicates upside through the weekend.")
        ]
    }
}
