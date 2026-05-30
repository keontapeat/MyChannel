import Foundation
import AVFoundation
import Combine

/// Phase 33: Multi-Camera Angle Support
/// Manages synchronized parallel AVPlayer instances to swap camera angles with zero buffering.
@MainActor
final class MultiCamPlayerManager: ObservableObject {
    @Published var activeAngleIndex: Int = 0
    @Published var availableAngles: [String] = [] // URLs for different angles
    @Published var isPlaying: Bool = false
    
    // The active player is exposed to the UI
    @Published var currentPlayer: AVPlayer?
    
    private var players: [AVPlayer] = []
    
    init() {}
    
    func setupAngles(urls: [String]) {
        self.availableAngles = urls
        self.players = urls.compactMap { urlString in
            guard let url = URL(string: urlString) else { return nil }
            let player = AVPlayer(url: url)
            player.isMuted = true // Mute all initially
            return player
        }
        
        guard !players.isEmpty else { return }
        
        // Unmute the first one and set as active
        players[0].isMuted = false
        activeAngleIndex = 0
        currentPlayer = players[0]
    }
    
    func play() {
        let masterTime = players[activeAngleIndex].currentTime()
        for player in players {
            player.seek(to: masterTime, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        }
        isPlaying = true
    }
    
    func pause() {
        for player in players {
            player.pause()
        }
        isPlaying = false
    }
    
    func switchAngle(to index: Int) {
        guard index >= 0 && index < players.count else { return }
        guard index != activeAngleIndex else { return }
        
        let oldPlayer = players[activeAngleIndex]
        let newPlayer = players[index]
        
        // Sync time precisely
        let currentTime = oldPlayer.currentTime()
        newPlayer.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
        
        oldPlayer.isMuted = true
        newPlayer.isMuted = false
        
        activeAngleIndex = index
        currentPlayer = newPlayer
        
        print("🎥 [MultiCam] Switched to angle \(index) instantly.")
    }
}
