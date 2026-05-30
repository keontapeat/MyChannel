import Foundation
import SwiftUI
import FirebaseFirestore

/// Phase 50: Advanced Video Analytics Heatmaps
/// Tracks user scrubbing behavior and generates a heatmap of engagement.
@MainActor
final class HeatmapAnalyticsEngine: ObservableObject {
    static let shared = HeatmapAnalyticsEngine()
    private let db = Firestore.firestore()
    
    // Key: time bucket (e.g. seconds), Value: count of views/scrubs
    @Published var currentHeatmap: [Int: Int] = [:]
    
    private var trackingBuffer: [Int: Int] = [:]
    private var lastTrackedSecond: Int = -1
    
    private init() {}
    
    /// Called continuously during playback
    func trackPlayback(at second: Int) {
        guard second != lastTrackedSecond else { return }
        lastTrackedSecond = second
        
        trackingBuffer[second, default: 0] += 1
        currentHeatmap[second, default: 0] += 1
        
        // Batch sync every 10 seconds of unique playback
        if trackingBuffer.count >= 10 {
            syncToBackend()
        }
    }
    
    /// Tracks explicit scrubs to boost heatmap at destination
    func trackScrub(to second: Int) {
        // A scrub indicates high interest in the destination
        trackingBuffer[second, default: 0] += 5
        currentHeatmap[second, default: 0] += 5
        lastTrackedSecond = second
    }
    
    private func syncToBackend() {
        guard !trackingBuffer.isEmpty else { return }
        // In a real app, send this buffer to an analytics endpoint or Firestore
        // For demo, we just clear the buffer
        trackingBuffer.removeAll()
    }
    
    /// Load heatmap data for a video
    func loadHeatmap(for videoId: String) {
        // Mock data fetch
        var mockData: [Int: Int] = [:]
        for i in 0..<100 {
            mockData[i] = Int.random(in: 1...100)
        }
        self.currentHeatmap = mockData
    }
}

/// A SwiftUI view that renders the heatmap over the progress bar
struct HeatmapOverlayView: View {
    let heatmap: [Int: Int]
    let duration: Double
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if duration > 0 && !heatmap.isEmpty {
                    let maxCount = Double(heatmap.values.max() ?? 1)
                    
                    // Discretize into chunks based on width
                    let chunks = Int(geo.size.width / 4) // 4px per chunk
                    let timePerChunk = duration / Double(chunks)
                    
                    ForEach(0..<chunks, id: \.self) { chunkIndex in
                        let timeRange = (Double(chunkIndex) * timePerChunk)..<(Double(chunkIndex + 1) * timePerChunk)
                        
                        let totalInChunk = heatmap.filter { timeRange.contains(Double($0.key)) }.values.reduce(0, +)
                        let intensity = Double(totalInChunk) / maxCount
                        
                        Rectangle()
                            .fill(Color.white)
                            .opacity(intensity * 0.5)
                            .frame(height: max(geo.size.height * intensity, 2))
                            .frame(maxHeight: geo.size.height, alignment: .bottom)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
