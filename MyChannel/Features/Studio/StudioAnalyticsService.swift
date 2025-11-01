import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct StudioVideoAnalytics: Identifiable, Codable {
    let id: String
    let videoId: String
    let impressions: Int
    let views: Int
    let ctr: Double
    let avgViewDuration: TimeInterval
    let avgViewDurationPercent: Double
    let rpm: Double
    let retentionCurve: [RetentionPoint]
    let trafficSources: [String: Int]
    let demographics: Demographics
    
    struct RetentionPoint: Codable {
        let timePercent: Double
        let retentionPercent: Double
    }
    
    struct Demographics: Codable {
        let ageGroups: [String: Int]
        let genders: [String: Int]
        let countries: [String: Int]
        let devices: [String: Int]
    }
}

@MainActor
final class StudioAnalyticsService: ObservableObject {
    static let shared = StudioAnalyticsService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    func fetchVideoAnalytics(videoId: String, dateRange: DateRange = .last28Days) async -> StudioVideoAnalytics? {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("video_analytics").document(videoId).getDocument()
            if let data = doc.data() {
                return StudioVideoAnalytics(
                    id: doc.documentID,
                    videoId: videoId,
                    impressions: (data["impressions"] as? Int) ?? 0,
                    views: (data["views"] as? Int) ?? 0,
                    ctr: (data["ctr"] as? Double) ?? 0.0,
                    avgViewDuration: (data["avgViewDuration"] as? TimeInterval) ?? 0,
                    avgViewDurationPercent: (data["avgViewDurationPercent"] as? Double) ?? 0.0,
                    rpm: (data["rpm"] as? Double) ?? 0.0,
                    retentionCurve: parseRetentionCurve(data["retentionCurve"]),
                    trafficSources: (data["trafficSources"] as? [String: Int]) ?? [:],
                    demographics: parseDemographics(data["demographics"])
                )
            }
        } catch { }
        #endif
        
        // Mock fallback
        return StudioVideoAnalytics(
            id: videoId,
            videoId: videoId,
            impressions: Int.random(in: 5000...50000),
            views: Int.random(in: 1000...15000),
            ctr: Double.random(in: 0.02...0.12),
            avgViewDuration: TimeInterval.random(in: 30...180),
            avgViewDurationPercent: Double.random(in: 0.3...0.8),
            rpm: Double.random(in: 0.5...5.0),
            retentionCurve: generateMockRetentionCurve(),
            trafficSources: [
                "Browse": Int.random(in: 200...1000),
                "Search": Int.random(in: 100...500),
                "Suggested": Int.random(in: 300...800),
                "External": Int.random(in: 50...200)
            ],
            demographics: StudioVideoAnalytics.Demographics(
                ageGroups: ["13-17": 15, "18-24": 35, "25-34": 30, "35-44": 15, "45+": 5],
                genders: ["Male": 60, "Female": 35, "Other": 5],
                countries: ["US": 45, "UK": 20, "CA": 15, "AU": 10, "Other": 10],
                devices: ["Mobile": 70, "Desktop": 20, "TV": 8, "Tablet": 2]
            )
        )
    }
    
    private func parseRetentionCurve(_ data: Any?) -> [StudioVideoAnalytics.RetentionPoint] {
        guard let array = data as? [[String: Any]] else { return generateMockRetentionCurve() }
        return array.compactMap { dict in
            guard let timePercent = dict["timePercent"] as? Double,
                  let retentionPercent = dict["retentionPercent"] as? Double else { return nil }
            return StudioVideoAnalytics.RetentionPoint(timePercent: timePercent, retentionPercent: retentionPercent)
        }
    }
    
    private func parseDemographics(_ data: Any?) -> StudioVideoAnalytics.Demographics {
        guard let dict = data as? [String: Any] else {
            return StudioVideoAnalytics.Demographics(ageGroups: [:], genders: [:], countries: [:], devices: [:])
        }
        return StudioVideoAnalytics.Demographics(
            ageGroups: dict["ageGroups"] as? [String: Int] ?? [:],
            genders: dict["genders"] as? [String: Int] ?? [:],
            countries: dict["countries"] as? [String: Int] ?? [:],
            devices: dict["devices"] as? [String: Int] ?? [:]
        )
    }
    
    private func generateMockRetentionCurve() -> [StudioVideoAnalytics.RetentionPoint] {
        var points: [StudioVideoAnalytics.RetentionPoint] = []
        for i in stride(from: 0, through: 100, by: 5) {
            let timePercent = Double(i) / 100.0
            let retention = max(0.1, 1.0 - timePercent * 0.6 - Double.random(in: 0...0.2))
            points.append(StudioVideoAnalytics.RetentionPoint(timePercent: timePercent, retentionPercent: retention))
        }
        return points
    }
}

enum DateRange: String, CaseIterable {
    case last7Days = "7d"
    case last28Days = "28d"
    case last90Days = "90d"
    case lastYear = "1y"
    case allTime = "all"
    
    var displayName: String {
        switch self {
        case .last7Days: return "Last 7 days"
        case .last28Days: return "Last 28 days"
        case .last90Days: return "Last 90 days"
        case .lastYear: return "Last year"
        case .allTime: return "All time"
        }
    }
}
