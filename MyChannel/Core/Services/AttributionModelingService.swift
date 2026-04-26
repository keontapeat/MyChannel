//
//  AttributionModelingService.swift
//  MyChannel
//
//  Attribution Modeling - Multi-touch attribution for marketing channels
//

import Foundation
import Combine

@MainActor
class AttributionModelingService: ObservableObject {
    static let shared = AttributionModelingService()
    
    @Published private(set) var attributionData: [ChannelAttribution] = []
    @Published private(set) var touchpoints: [Touchpoint] = []
    @Published private(set) var conversionPaths: [ConversionPath] = []
    
    struct ChannelAttribution: Identifiable, Codable {
        let id: String
        let channel: String
        let attributedConversions: Int
        let attributedRevenue: Double
        let attributionWeight: Double
        let modelType: String
    }
    
    struct Touchpoint: Identifiable, Codable {
        let id: String
        let channel: String
        let touchpointType: String
        let position: String
        let avgConversionRate: Double
        let avgPathPosition: Double
    }
    
    struct ConversionPath: Identifiable, Codable {
        let id: String
        let path: [String]
        let conversionCount: Int
        let avgPathLength: Int
        let mostCommonFirstTouch: String
        let mostCommonLastTouch: String
    }
    
    private init() {
        Task { await loadAttributionData() }
    }
    
    func loadAttributionData() async {
        guard AppConfig.Features.enableAnalyticsPredictor else { return }
        
        struct Req: Encodable { let task: String }
        struct RawAttrib: Decodable { let id: String; let channel: String; let attributedConversions: Int; let attributedRevenue: Double; let attributionWeight: Double; let modelType: String }
        struct RawTouch: Decodable { let id: String; let channel: String; let touchpointType: String; let position: String; let avgConversionRate: Double; let avgPathPosition: Double }
        struct RawPath: Decodable { let id: String; let path: [String]; let conversionCount: Int; let avgPathLength: Int; let mostCommonFirstTouch: String; let mostCommonLastTouch: String }
        struct Raw: Decodable { let attributionData: [RawAttrib]?; let touchpoints: [RawTouch]?; let conversionPaths: [RawPath]? }
        
        do {
            let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
                body: Req(task: "get_attribution_modeling"), timeout: 30)
            
            attributionData = (r.attributionData ?? []).map {
                ChannelAttribution(
                    id: $0.id,
                    channel: $0.channel,
                    attributedConversions: $0.attributedConversions,
                    attributedRevenue: $0.attributedRevenue,
                    attributionWeight: $0.attributionWeight,
                    modelType: $0.modelType
                )
            }.sorted { $0.attributedRevenue > $1.attributedRevenue }
            
            touchpoints = (r.touchpoints ?? []).map {
                Touchpoint(
                    id: $0.id,
                    channel: $0.channel,
                    touchpointType: $0.touchpointType,
                    position: $0.position,
                    avgConversionRate: $0.avgConversionRate,
                    avgPathPosition: $0.avgPathPosition
                )
            }
            
            conversionPaths = (r.conversionPaths ?? []).map {
                ConversionPath(
                    id: $0.id,
                    path: $0.path,
                    conversionCount: $0.conversionCount,
                    avgPathLength: $0.avgPathLength,
                    mostCommonFirstTouch: $0.mostCommonFirstTouch,
                    mostCommonLastTouch: $0.mostCommonLastTouch
                )
            }.sorted { $0.conversionCount > $1.conversionCount }
            
        } catch {
            print("⚠️ [AttributionModeling] Error: \(error)")
        }
    }
    
    func setAttributionModel(modelType: String) async throws {
        struct Req: Encodable { let task: String; let modelType: String }
        struct Raw: Decodable { let success: Bool? }
        let r: Raw = try await CloudRunAgentRouter.post(.analyticsPredictor, path: "/predict",
            body: Req(task: "set_attribution_model", modelType: modelType), timeout: 20)
        guard r.success == true else { throw NSError(domain: "AttributionModeling", code: -1, userInfo: nil) }
        await loadAttributionData()
    }
}
