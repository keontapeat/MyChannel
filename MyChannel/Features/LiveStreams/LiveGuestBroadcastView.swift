import SwiftUI
import LiveKit

/// Guest Mode Broadcast View using WebRTC for ultra-low latency co-streaming
struct LiveGuestBroadcastView: View {
    @StateObject private var liveService = WebRTCLiveService.shared
    @State private var streamURL: String = ""
    @State private var streamToken: String = ""
    @State private var isSettingUp = true
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isSettingUp {
                setupView
            } else {
                broadcastView
            }
        }
        .navigationTitle("Guest Mode (WebRTC)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    Task {
                        await liveService.disconnect()
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            }
        }
        .onDisappear {
            Task {
                await liveService.disconnect()
            }
        }
    }
    
    private var setupView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Start a Co-Stream")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Invite guests in real-time with sub-second latency.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                TextField("Server URL (wss://...)", text: $streamURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                SecureField("Access Token", text: $streamToken)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
            
            Button(action: startBroadcast) {
                Text("Go Live")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(streamURL.isEmpty || streamToken.isEmpty)
        }
        .padding()
    }
    
    private var broadcastView: some View {
        VStack {
            if liveService.isConnected {
                // Split Screen rendering of participants
                let participants = liveService.participants
                
                if participants.isEmpty {
                    Text("Waiting for video...")
                        .foregroundColor(.gray)
                } else if participants.count == 1 {
                    ParticipantVideoView(participant: participants[0])
                        .ignoresSafeArea()
                } else {
                    // Split screen for 2+ participants
                    VStack(spacing: 2) {
                        ForEach(participants, id: \.sid) { participant in
                            ParticipantVideoView(participant: participant)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                        }
                    }
                    .ignoresSafeArea()
                }
                
                // Controls Overlay
                VStack {
                    Spacer()
                    HStack(spacing: 30) {
                        Button(action: {}) {
                            Image(systemName: "mic.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            Task {
                                await liveService.disconnect()
                                dismiss()
                            }
                        }) {
                            Image(systemName: "phone.down.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(20)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "camera.rotate.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 40)
                }
            } else {
                ProgressView("Connecting to Edge Server...")
                    .foregroundColor(.white)
            }
        }
    }
    
    private func startBroadcast() {
        Task {
            do {
                try await liveService.connectToLiveStream(url: streamURL, token: streamToken)
                try await liveService.publishLocalCamera()
                DispatchQueue.main.async {
                    self.isSettingUp = false
                }
            } catch {
                print("Failed to connect: \(error)")
            }
        }
    }
}

/// A helper view to render a LiveKit participant's video track
struct ParticipantVideoView: View {
    let participant: Participant
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.gray.opacity(0.3)
                
                // In a real app, you would use `SwiftUIVideoView(track: videoTrack)` 
                // provided by the LiveKit Swift SDK UI components.
                // For scaffolding, we place a placeholder.
                VStack {
                    Image(systemName: "video.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.5))
                    Text(String(describing: participant.identity))
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
    }
}
