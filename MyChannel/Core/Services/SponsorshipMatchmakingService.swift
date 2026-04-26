import Foundation
import Combine

@MainActor
final class SponsorshipMatchmakingService: ObservableObject {
    static let shared = SponsorshipMatchmakingService()

    struct SponsorshipMatch: Identifiable, Codable {
        let id: String
        let creatorId: String
        let brandName: String
        let fitScore: Double
        let audienceOverlap: Double
        let readinessScore: Double
    }

    @Published private(set) var matches: [SponsorshipMatch] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableSponsorshipMatchmaking else { return }

        matches = [
            SponsorshipMatch(id: UUID().uuidString, creatorId: "creator_1", brandName: "Acme Audio", fitScore: 0.88, audienceOverlap: 0.67, readinessScore: 0.9),
            SponsorshipMatch(id: UUID().uuidString, creatorId: "creator_2", brandName: "North Peak", fitScore: 0.81, audienceOverlap: 0.61, readinessScore: 0.84)
        ]
    }
}
