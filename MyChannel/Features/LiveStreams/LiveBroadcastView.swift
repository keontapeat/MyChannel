//
//  LiveBroadcastView.swift
//  MyChannel
//
//  Full-screen broadcast screen with camera preview, LIVE badge,
//  viewer count, duration timer, chat overlay, and end stream controls.
//

import SwiftUI
import AVFoundation

struct LiveBroadcastView: View {
    let stream: FirestoreLiveStream
    let onEnd: () -> Void

    @StateObject private var camera = LiveCameraManager()
    @ObservedObject private var liveManager = LiveStreamManager.shared

    @State private var elapsed: TimeInterval = 0
    @State private var showChat = true
    @State private var showEndConfirm = false
    @State private var chatText = ""
    @State private var timer: Timer?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Camera Preview (full screen)
            if camera.isRunning {
                LiveCameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                    Text("Starting camera…")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.subheadline)
                }
            }

            // Gradient overlays for readability
            VStack {
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .ignoresSafeArea()

            // Controls overlay
            VStack(spacing: 0) {
                topBar
                Spacer()
                if showChat && stream.enableChat {
                    chatOverlay
                }
                bottomBar
            }
        }
        .statusBarHidden()
        .onAppear {
            Task {
                await camera.requestPermissions()
                camera.startSession()
            }
            startTimer()
        }
        .onDisappear {
            camera.stopSession()
            stopTimer()
        }
        .alert("End Live Stream?", isPresented: $showEndConfirm) {
            Button("End Stream", role: .destructive) { endStream() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your viewers will be disconnected and the stream will end.")
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 12) {
            // LIVE badge
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: .red, radius: 4)
                Text("LIVE")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.red)
            .cornerRadius(4)

            // Duration
            Text(formattedDuration)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.5))
                .cornerRadius(4)

            // Viewer count
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 11))
                Text("\(stream.viewerCount)")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.5))
            .cornerRadius(4)

            Spacer()

            // Close / End
            Button {
                showEndConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack(spacing: 20) {
            // Flip camera
            Button {
                camera.flipCamera()
                HapticManager.shared.impact(style: .light)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 22))
                    Text("Flip")
                        .font(.system(size: 10))
                }
                .foregroundColor(.white)
            }

            // Mute mic
            Button {
                camera.toggleMic()
                HapticManager.shared.impact(style: .light)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: camera.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 22))
                    Text(camera.isMicMuted ? "Unmute" : "Mute")
                        .font(.system(size: 10))
                }
                .foregroundColor(camera.isMicMuted ? .red : .white)
            }

            // Toggle chat
            if stream.enableChat {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showChat.toggle() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: showChat ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                            .font(.system(size: 22))
                        Text("Chat")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white)
                }
            }

            Spacer()

            // End Stream
            Button {
                showEndConfirm = true
            } label: {
                Text("End Stream")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    // MARK: - Chat Overlay
    private var chatOverlay: some View {
        VStack(spacing: 8) {
            // Recent messages (mock for MVP; real Firestore listener can be added)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(sampleChatMessages, id: \.self) { msg in
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                    }
                }
            }
            .frame(height: 150)
            .padding(.horizontal, 16)

            // Chat input
            HStack(spacing: 8) {
                TextField("Say something…", text: $chatText)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(20)
                    .foregroundColor(.white)

                Button {
                    guard !chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    Task {
                        await liveManager.sendChatMessage(streamId: stream.id, content: chatText)
                        chatText = ""
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers
    private var formattedDuration: String {
        let h = Int(elapsed) / 3600
        let m = (Int(elapsed) % 3600) / 60
        let s = Int(elapsed) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func endStream() {
        camera.stopSession()
        stopTimer()
        Task {
            await liveManager.endStream()
        }
        HapticManager.shared.impact(style: .heavy)
        onEnd()
        dismiss()
    }

    private var sampleChatMessages: [String] {
        [
            "🔥 Welcome to the stream!",
            "👋 Hey everyone!",
            "🎉 Let's gooo!",
        ]
    }
}

#Preview("Live Broadcast") {
    LiveBroadcastView(
        stream: LiveStreamManager.sampleStreams[0],
        onEnd: {}
    )
}
