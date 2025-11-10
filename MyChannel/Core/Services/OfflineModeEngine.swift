// OfflineModeEngine.swift - 📱 OFFLINE VIEWING!
import Foundation
@MainActor
class OfflineModeEngine: ObservableObject {
    static let shared = OfflineModeEngine()
    @Published var downloadedVideos: [String] = []
    func download(_ videoId: String) async { downloadedVideos.append(videoId) }
}
