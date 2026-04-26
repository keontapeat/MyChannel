import Foundation
import Combine

@MainActor
final class ShoppableVideoOrchestrationService: ObservableObject {
    static let shared = ShoppableVideoOrchestrationService()

    struct ShoppableMoment: Identifiable, Codable {
        let id: String
        let videoId: String
        let timestampSeconds: Double
        let productCount: Int
        let placementStyle: String
        let projectedCTR: Double
    }

    @Published private(set) var moments: [ShoppableMoment] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableShoppableVideoOrchestration else { return }

        moments = [
            ShoppableMoment(id: UUID().uuidString, videoId: "video_1", timestampSeconds: 42, productCount: 2, placementStyle: "lower_third", projectedCTR: 0.051),
            ShoppableMoment(id: UUID().uuidString, videoId: "video_2", timestampSeconds: 118, productCount: 3, placementStyle: "chapter_card", projectedCTR: 0.038)
        ]
    }
}
