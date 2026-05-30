import Foundation
import LiveKit

/// A Beast Mode service that powers 1-on-1 Guest Mode streaming, 
/// sub-second latency broadcasts, and live video rooms using WebRTC.
final class WebRTCLiveService: ObservableObject {
    static let shared = WebRTCLiveService()
    
    private var room: Room?
    @Published var isConnected: Bool = false
    @Published var participants: [Participant] = []
    
    private init() {}
    
    /// Connect to a LiveKit WebSocket Edge server for ultra-low latency broadcasting
    func connectToLiveStream(url: String, token: String) async throws {
        // Create a new Room instance
        let room = Room()
        self.room = room
        
        room.add(delegate: self)
        
        // Connect to the LiveKit server
        try await room.connect(url: url, token: token)
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.updateParticipants()
        }
    }
    
    /// Disconnects from the broadcast and cleans up camera/mic resources
    func disconnect() async {
        guard let room = room else { return }
        await room.disconnect()
        self.room = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.participants.removeAll()
        }
    }
    
    /// Publishes the user's camera and microphone to the WebRTC room
    func publishLocalCamera() async throws {
        guard let room = room else { return }
        let localParticipant = room.localParticipant
        
        // Enable camera and microphone
        try await localParticipant.setCamera(enabled: true)
        try await localParticipant.setMicrophone(enabled: true)
    }
    
    private func updateParticipants() {
        guard let room = room else { return }
        var currentParticipants = [Participant]()
        
        let local = room.localParticipant
        currentParticipants.append(local)
        
        currentParticipants.append(contentsOf: room.remoteParticipants.values.map { $0 as Participant })
        self.participants = currentParticipants
    }
}

extension WebRTCLiveService: RoomDelegate {
    func room(_ room: Room, participantDidConnect participant: RemoteParticipant) {
        print("👤 Beast Mode: Guest joined the live stream! \(participant.identity)")
        DispatchQueue.main.async {
            self.updateParticipants()
        }
    }
    
    func room(_ room: Room, participantDidDisconnect participant: RemoteParticipant) {
        print("👤 Guest left the live stream: \(participant.identity)")
        DispatchQueue.main.async {
            self.updateParticipants()
        }
    }
}
