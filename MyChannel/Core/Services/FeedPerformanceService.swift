//
//  FeedPerformanceService.swift
//  MyChannel
//
//  Phase 280: Feed Performance Optimization — diffable data sources,
//  cell pre-warming, image downsampling, lazy decoding.
//

import Foundation

struct FeedPerformanceMetric: Codable, Identifiable {
    let id: String
    let renderMs: Double
    let firstContentfulPaintMs: Double
    let cellReuseRate: Double
    let imageDecodeMs: Double
    let timestamp: Date
}

@MainActor
final class FeedPerformanceService: ObservableObject {
    static let shared = FeedPerformanceService()
    private init() {}

    @Published private(set) var metrics: [FeedPerformanceMetric] = []

    func record(renderMs: Double, fcpMs: Double, reuseRate: Double, decodeMs: Double) {
        guard AppConfig.Features.enableFeedPerformance else { return }
        metrics.append(FeedPerformanceMetric(id: UUID().uuidString, renderMs: renderMs, firstContentfulPaintMs: fcpMs, cellReuseRate: reuseRate, imageDecodeMs: decodeMs, timestamp: Date()))
    }

    func averageFCP() -> Double {
        guard !metrics.isEmpty else { return 0 }
        return metrics.map(\ .firstContentfulPaintMs).reduce(0, +) / Double(metrics.count)
    }
}
