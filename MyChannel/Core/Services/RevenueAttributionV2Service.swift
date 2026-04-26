import Foundation
import Combine

@MainActor
final class RevenueAttributionV2Service: ObservableObject {
    static let shared = RevenueAttributionV2Service()

    struct AttributionPath: Identifiable, Codable {
        let id: String
        let surfacePath: [String]
        let revenue: Double
        let conversionType: String
        let attributionConfidence: Double
    }

    @Published private(set) var attributionPaths: [AttributionPath] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableRevenueAttributionV2 else { return }

        attributionPaths = [
            AttributionPath(id: UUID().uuidString, surfacePath: ["home", "video", "checkout"], revenue: 2400, conversionType: "membership", attributionConfidence: 0.86),
            AttributionPath(id: UUID().uuidString, surfacePath: ["search", "profile", "live", "gift"], revenue: 980, conversionType: "gift", attributionConfidence: 0.73)
        ]
    }
}
