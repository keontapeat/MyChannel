//
//  ContentTrendingHeatmapService.swift
//  MyChannel
//
//  Phase 263: Content Trending Heatmap Visualization
//  Visualizes trending content across categories, regions, time periods
//

import Foundation
import Combine

@MainActor
class ContentTrendingHeatmapService: ObservableObject {
    static let shared = ContentTrendingHeatmapService()
    
    @Published private(set) var heatmapData: [HeatmapCell] = []
    @Published private(set) var trendingCategories: [TrendingCategory] = []
    @Published private(set) var hourlyTrends: [HourlyTrend] = []
    @Published private(set) var regionalHotspots: [RegionalHotspot] = []
    
    struct HeatmapCell: Identifiable, Codable {
        let id: String
        let category: String
        let region: String
        let hour: Int
        let intensity: Double
        let viewCount: Int
        let engagementScore: Double
    }
    
    struct TrendingCategory: Identifiable, Codable {
        let id: String
        let category: String
        let trendScore: Double
        let viewCount: Double
        let growthRate: Double
        let topVideos: [String]
    }
    
    struct HourlyTrend: Identifiable, Codable {
        let id: String
        let hour: Int
        let totalViews: Double
        let uniqueViewers: Int
        let engagementRate: Double
    }
    
    struct RegionalHotspot: Identifiable, Codable {
        let id: String
        let region: String
        let countryCode: String
        let activityLevel: Double
        let topCategories: [String]
        let viewerCount: Int
    }
    
    private init() {
        Task { await loadHeatmapData() }
    }
    
    func loadHeatmapData() async {
        guard AppConfig.Features.enableRealTimeTrendDetector else { return }
        
        struct Req: Encodable { let task: String }
        struct RawCell: Decodable { let id: String; let category: String; let region: String; let hour: Int; let intensity: Double; let viewCount: Int; let engagementScore: Double }
        struct RawCat: Decodable { let id: String; let category: String; let trendScore: Double; let viewCount: Double; let growthRate: Double; let topVideos: [String] }
        struct RawHour: Decodable { let id: String; let hour: Int; let totalViews: Double; let uniqueViewers: Int; let engagementRate: Double }
        struct RawRegion: Decodable { let id: String; let region: String; let countryCode: String; let activityLevel: Double; let topCategories: [String]; let viewerCount: Int }
        struct Raw: Decodable { let heatmapCells: [RawCell]?; let trendingCategories: [RawCat]?; let hourlyTrends: [RawHour]?; let regionalHotspots: [RawRegion]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.trendForecaster, path: "/predict",
                body: Req(task: "get_trending_heatmap_data"), timeout: 30)
            
            heatmapData = (r.heatmapCells ?? []).map {
                HeatmapCell(
                    id: $0.id,
                    category: $0.category,
                    region: $0.region,
                    hour: $0.hour,
                    intensity: $0.intensity,
                    viewCount: $0.viewCount,
                    engagementScore: $0.engagementScore
                )
            }
            
            trendingCategories = (r.trendingCategories ?? []).map {
                TrendingCategory(
                    id: $0.id,
                    category: $0.category,
                    trendScore: $0.trendScore,
                    viewCount: $0.viewCount,
                    growthRate: $0.growthRate,
                    topVideos: $0.topVideos
                )
            }
            
            hourlyTrends = (r.hourlyTrends ?? []).map {
                HourlyTrend(
                    id: $0.id,
                    hour: $0.hour,
                    totalViews: $0.totalViews,
                    uniqueViewers: $0.uniqueViewers,
                    engagementRate: $0.engagementRate
                )
            }
            
            regionalHotspots = (r.regionalHotspots ?? []).map {
                RegionalHotspot(
                    id: $0.id,
                    region: $0.region,
                    countryCode: $0.countryCode,
                    activityLevel: $0.activityLevel,
                    topCategories: $0.topCategories,
                    viewerCount: $0.viewerCount
                )
            }
            
        } catch {
            print("⚠️ [ContentTrendingHeatmap] Error: \(error)")
        }
    }
    
    func getHeatmapForCategory(category: String) async -> [HeatmapCell] {
        heatmapData.filter { $0.category == category }
    }
    
    func getHeatmapForRegion(region: String) async -> [HeatmapCell] {
        heatmapData.filter { $0.region == region }
    }
}
