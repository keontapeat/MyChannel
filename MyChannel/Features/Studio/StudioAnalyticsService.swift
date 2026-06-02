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
            print("📊 [StudioAnalyticsService] Fetching analytics for video: \(videoId)")
            
            // 🔥 REAL-TIME SYNC: Get actual view count from video document
            let videoDoc = try await db.collection("videos").document(videoId).getDocument()
            var actualViews = 0
            var actualImpressions = 0
            
            if let videoData = videoDoc.data() {
                actualViews = (videoData["viewCount"] as? Int) ?? 0
                actualImpressions = (videoData["impressions"] as? Int) ?? (actualViews * 3) // Estimate if not tracked
                print("✅ [StudioAnalyticsService] Got real views from video: \(actualViews)")
            }
            
            // Try to get detailed analytics
            let analyticsDoc = try await db.collection("video_analytics").document(videoId).getDocument()
            if let data = analyticsDoc.data() {
                // Use real views from video document, supplemented by analytics data
                let analytics = StudioVideoAnalytics(
                    id: analyticsDoc.documentID,
                    videoId: videoId,
                    impressions: (data["impressions"] as? Int) ?? actualImpressions,
                    views: actualViews, // 🔥 Always use actual view count from video
                    ctr: (data["ctr"] as? Double) ?? (actualViews > 0 ? Double(actualViews) / Double(max(actualImpressions, 1)) : 0.05),
                    avgViewDuration: (data["avgViewDuration"] as? TimeInterval) ?? 0,
                    avgViewDurationPercent: (data["avgViewDurationPercent"] as? Double) ?? 0.0,
                    rpm: (data["rpm"] as? Double) ?? 0.0,
                    retentionCurve: parseRetentionCurve(data["retentionCurve"]),
                    trafficSources: (data["trafficSources"] as? [String: Int]) ?? [:],
                    demographics: parseDemographics(data["demographics"])
                )
                print("✅ [StudioAnalyticsService] Returning analytics with \(actualViews) views")
                return analytics
            } else if actualViews > 0 {
                // Video exists with views but no detailed analytics yet - create basic analytics
                print("📊 [StudioAnalyticsService] Creating basic analytics from video data")
                return StudioVideoAnalytics(
                    id: videoId,
                    videoId: videoId,
                    impressions: actualImpressions,
                    views: actualViews,
                    ctr: Double(actualViews) / Double(max(actualImpressions, 1)),
                    avgViewDuration: 0,
                    avgViewDurationPercent: 0.0,
                    rpm: 0.0,
                    retentionCurve: generateMockRetentionCurve(),
                    trafficSources: ["Direct": actualViews],
                    demographics: StudioVideoAnalytics.Demographics(
                        ageGroups: [:],
                        genders: [:],
                        countries: [:],
                        devices: [:]
                    )
                )
            }
        } catch {
            print("⚠️ [StudioAnalyticsService] Error fetching analytics: \(error)")
        }
        #endif
        
        // Return nil if no data available (will show empty state in UI)
        print("ℹ️ [StudioAnalyticsService] No analytics data available for video: \(videoId)")
        return nil
    }
    
    /// 🔥 YouTube Studio parity: batch-fetch analytics for many videos at once.
    /// Powers the Advanced (table) layout columns: CTR, Avg watch time, Revenue.
    /// Runs fetches concurrently and returns a [videoId: analytics] map.
    func fetchVideoAnalyticsBatch(videoIds: [String], dateRange: DateRange = .last28Days) async -> [String: StudioVideoAnalytics] {
        guard !videoIds.isEmpty else { return [:] }
        return await withTaskGroup(of: (String, StudioVideoAnalytics?).self) { group in
            for id in videoIds {
                group.addTask { [weak self] in
                    let analytics = await self?.fetchVideoAnalytics(videoId: id, dateRange: dateRange)
                    return (id, analytics)
                }
            }
            var result: [String: StudioVideoAnalytics] = [:]
            for await (id, analytics) in group {
                if let analytics { result[id] = analytics }
            }
            return result
        }
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
