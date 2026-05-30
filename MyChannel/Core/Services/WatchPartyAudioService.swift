import Foundation
import AVFoundation

/// Phase 32: Watch Party Audio Chat
/// Simulates an audio bridge (e.g. WebRTC) for live voice chat.
/// Ducks the video volume automatically when someone is speaking.
@MainActor
final class WatchPartyAudioService: ObservableObject {
    static let shared = WatchPartyAudioService()
    
    @Published var isAudioChatActive: Bool = false
    @Published var isSpeaking: Bool = false
    
    private var dummyAudioEngine: AVAudioEngine?
    private var talkingTimer: Timer?
    
    private init() {}
    
    func joinAudioRoom(roomId: String) {
        guard !isAudioChatActive else { return }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true)
            
            // Mocking the connection
            print("🎙️ [WatchParty] Joined Audio Room: \(roomId)")
            isAudioChatActive = true
            
            // Mock someone else talking randomly to trigger ducking
            talkingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.simulateNetworkSpeaker()
                }
            }
            
        } catch {
            print("🎙️ [WatchParty] Failed to setup audio session: \(error)")
        }
    }
    
    func leaveAudioRoom() {
        guard isAudioChatActive else { return }
        talkingTimer?.invalidate()
        talkingTimer = nil
        isAudioChatActive = false
        isSpeaking = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🎙️ [WatchParty] Left Audio Room")
        } catch {
            print("🎙️ [WatchParty] Error leaving audio room: \(error)")
        }
    }
    
    private func simulateNetworkSpeaker() {
        if Bool.random() {
            isSpeaking = true
            // AVPlayer volume ducking is handled automatically via `.duckOthers` in the audio session category
            print("🎙️ [WatchParty] Participant is speaking... ducking video volume.")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1...3)) {
                self.isSpeaking = false
                print("🎙️ [WatchParty] Participant stopped speaking.")
            }
        }
    }
}
