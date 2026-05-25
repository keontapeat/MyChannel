import Foundation
import Combine

@MainActor
final class YieldStrategyService: ObservableObject {
    static let shared = YieldStrategyService()

    struct YieldStrategy: Identifiable, Codable {
        let id: String
        let segment: String
        let floorPrice: Double
        let waterfallDepth: Int
        let auctionMix: String
        let projectedLift: Double
    }

    @Published private(set) var strategies: [YieldStrategy] = []

    private init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard AppConfig.Features.enableYieldStrategy else { return }

        strategies = [
            YieldStrategy(id: UUID().uuidString, segment: "US Premium Video", floorPrice: 9.5, waterfallDepth: 4, auctionMix: "hybrid", projectedLift: 0.12),
            YieldStrategy(id: UUID().uuidString, segment: "Global Shorts", floorPrice: 4.1, waterfallDepth: 3, auctionMix: "open", projectedLift: 0.07)
        ]
    }
}
