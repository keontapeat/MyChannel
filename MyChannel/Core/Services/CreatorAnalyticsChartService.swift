#if canImport(DGCharts)
import DGCharts
#endif
import Foundation
import SwiftUI

/// Creator analytics chart data service — powers charts in Creator Studio.
@MainActor
final class CreatorAnalyticsChartService: ObservableObject {
    static let shared = CreatorAnalyticsChartService()

    @Published var viewsData: [ChartDataPoint] = []
    @Published var revenueData: [ChartDataPoint] = []
    @Published var subscriberData: [ChartDataPoint] = []
    @Published var isLoading = false

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    private init() {}

    func loadAnalytics(for creatorId: String, days: Int = 28) async {
        isLoading = true
        defer { isLoading = false }
        let calendar = Calendar.current
        let today = Date()
        viewsData = (0..<days).map { offset -> ChartDataPoint in
            let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today)!
            let label = DateFormatter.shortDate.string(from: date)
            let value = Double.random(in: 500...50000)
            return ChartDataPoint(label: label, value: value)
        }
        revenueData = (0..<days).map { offset -> ChartDataPoint in
            let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today)!
            let label = DateFormatter.shortDate.string(from: date)
            let value = Double.random(in: 10...500)
            return ChartDataPoint(label: label, value: value)
        }
        subscriberData = (0..<days).map { offset -> ChartDataPoint in
            let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today)!
            let label = DateFormatter.shortDate.string(from: date)
            let value = Double.random(in: 0...200)
            return ChartDataPoint(label: label, value: value)
        }
    }

    var totalViews: Double { viewsData.reduce(0) { $0 + $1.value } }
    var totalRevenue: Double { revenueData.reduce(0) { $0 + $1.value } }
    var totalNewSubscribers: Double { subscriberData.reduce(0) { $0 + $1.value } }
}

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
