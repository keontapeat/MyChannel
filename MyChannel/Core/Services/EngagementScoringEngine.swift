// EngagementScoringEngine.swift - 💯 SCORE EVERYTHING!
import Foundation
class EngagementScoringEngine {
    static let shared = EngagementScoringEngine()
    func scoreAction(_ action: Action) -> Int {
        switch action {
        case .view: return 1
        case .like: return 5
        case .comment: return 10
        case .share: return 20
        }
    }
    enum Action { case view, like, comment, share }
}
