import Foundation
import Combine

@MainActor
final class AdDemandForecastingService: ObservableObject {
    static let shared = AdDemandForecastingService()

    struct DemandForecast: Identifiable, Codable {
        let id: String
        let market: String
        let fillRate: Double
        let expectedCPM: Double
        let demandScore: Double
        let forecastWindow: String
    }

    struct OpportunityAlert: Identifiable, Codable {
        let id: String
        let title: String
        let market: String
        let revenueUpside: Double
        let confidence: Double
    }

    @Published private(set) var forecasts: [DemandForecast] = []
    @Published private(set) var opportunityAlerts: [OpportunityAlert] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableAdDemandForecasting else { return }

        forecasts = [
            DemandForecast(id: UUID().uuidString, market: "US Shorts", fillRate: 0.91, expectedCPM: 8.4, demandScore: 0.88, forecastWindow: "7d"),
            DemandForecast(id: UUID().uuidString, market: "US Longform", fillRate: 0.86, expectedCPM: 11.2, demandScore: 0.83, forecastWindow: "7d")
        ]
        opportunityAlerts = [
            OpportunityAlert(id: UUID().uuidString, title: "Weekend demand spike", market: "US Shorts", revenueUpside: 1240, confidence: 0.81)
        ]
    }
}
