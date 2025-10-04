import Foundation

// Aggregates live channels from openly documented HLS sources and EPGs
final class LiveTVService {
    static let shared = LiveTVService()
    private init() {}

    func fetchChannels() async -> [LiveTVChannel] {
        // For now, return curated, legal HLS channels (sample list present in model)
        // Later we can plug in Samsung TV Plus/Pluto public guide JSONs if allowed
        return LiveTVChannel.sampleChannels
    }
}


