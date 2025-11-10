// RealTimeDashboardEngine.swift - 📊 LIVE DASHBOARDS!
import Foundation
@MainActor
class RealTimeDashboardEngine: ObservableObject {
    static let shared = RealTimeDashboardEngine()
    @Published var metrics: [String: Double] = [:]
    func update(_ metric: String, value: Double) { metrics[metric] = value }
}
