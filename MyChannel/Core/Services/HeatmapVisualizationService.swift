//
//  HeatmapVisualizationService.swift
//  MyChannel
//
//  Heatmap Visualization - User interaction heatmaps across the app
//

import Foundation
import Combine

@MainActor
class HeatmapVisualizationService: ObservableObject {
    static let shared = HeatmapVisualizationService()
    
    @Published private(set) var heatmapData: [HeatmapPoint] = []
    @Published private(set) var screenHeatmaps: [ScreenHeatmap] = []
    
    struct HeatmapPoint: Identifiable, Codable {
        let id: String
        let screen: String
        let x: Double
        let y: Double
        let clickCount: Int
        let hoverDuration: Double
    }
    
    struct ScreenHeatmap: Identifiable, Codable {
        let id: String
        let screenName: String
        let totalInteractions: Int
        let hotspots: [Hotspot]
        let generatedAt: Date
    }
    
    struct Hotspot: Identifiable, Codable {
        let id: String
        let x: Double
        let y: Double
        let radius: Double
        let intensity: Double
        let elementId: String?
    }
    
    private init() {
        Task { await loadHeatmapData() }
    }
    
    func loadHeatmapData() async {
        guard AppConfig.Features.enableAnalytics else { return }
        
        struct Req: Encodable { let task: String }
        struct RawPoint: Decodable { let id: String; let screen: String; let x: Double; let y: Double; let clickCount: Int; let hoverDuration: Double }
        struct RawHotspot: Decodable { let id: String; let x: Double; let y: Double; let radius: Double; let intensity: Double; let elementId: String? }
        struct RawScreen: Decodable { let id: String; let screenName: String; let totalInteractions: Int; let hotspots: [RawHotspot]; let generatedAt: String }
        struct Raw: Decodable { let heatmapData: [RawPoint]?; let screenHeatmaps: [RawScreen]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_heatmap_data"), timeout: 30)
            
            let decoder = ISO8601DateFormatter()
            
            heatmapData = (r.heatmapData ?? []).map {
                HeatmapPoint(
                    id: $0.id,
                    screen: $0.screen,
                    x: $0.x,
                    y: $0.y,
                    clickCount: $0.clickCount,
                    hoverDuration: $0.hoverDuration
                )
            }
            
            screenHeatmaps = (r.screenHeatmaps ?? []).map {
                ScreenHeatmap(
                    id: $0.id,
                    screenName: $0.screenName,
                    totalInteractions: $0.totalInteractions,
                    hotspots: $0.hotspots.map {
                        Hotspot(
                            id: $0.id,
                            x: $0.x,
                            y: $0.y,
                            radius: $0.radius,
                            intensity: $0.intensity,
                            elementId: $0.elementId
                        )
                    },
                    generatedAt: decoder.date(from: $0.generatedAt) ?? Date()
                )
            }
            
        } catch {
            print("⚠️ [HeatmapVisualization] Error: \(error)")
        }
    }
    
    func trackInteraction(screen: String, x: Double, y: Double, type: String) async {
        struct Req: Encodable { let task: String; let screen: String; let x: Double; let y: Double; let type: String }
        struct RawAck: Decodable { let ok: Bool? }
        let _: RawAck? = try? await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "track_heatmap_interaction", screen: screen, x: x, y: y, type: type), timeout: 10)
    }
}
