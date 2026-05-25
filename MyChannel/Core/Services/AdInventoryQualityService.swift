import Foundation
import Combine

@MainActor
final class AdInventoryQualityService: ObservableObject {
    static let shared = AdInventoryQualityService()

    struct InventoryQualitySnapshot: Identifiable, Codable {
        let id: String
        let surface: String
        let qualityScore: Double
        let viewabilityReadiness: Double
        let unsafeRate: Double
        let tier: String
    }

    @Published private(set) var snapshots: [InventoryQualitySnapshot] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableAdInventoryQuality else { return }

        snapshots = [
            InventoryQualitySnapshot(id: UUID().uuidString, surface: "Home Feed", qualityScore: 0.93, viewabilityReadiness: 0.89, unsafeRate: 0.01, tier: "premium"),
            InventoryQualitySnapshot(id: UUID().uuidString, surface: "Video Detail", qualityScore: 0.90, viewabilityReadiness: 0.94, unsafeRate: 0.02, tier: "premium")
        ]
    }
}
