import Foundation
import ReplayKit
import AVFoundation

/// Phase 86: ReplayKit Screen Recording
/// Allows users to broadcast their screen directly (e.g. for game streaming).
@MainActor
final class ScreenRecordingEngine: ObservableObject {
    static let shared = ScreenRecordingEngine()
    
    @Published var isRecording = false
    private let recorder = RPScreenRecorder.shared()
    
    private init() {
        recorder.isMicrophoneEnabled = true
        recorder.isCameraEnabled = true
    }
    
    func startRecording() {
        guard recorder.isAvailable else {
            print("⚠️ [ScreenRecording] ReplayKit is not available.")
            return
        }
        
        recorder.startCapture(handler: { [weak self] (sampleBuffer, bufferType, error) in
            if let error = error {
                print("⚠️ [ScreenRecording] Capture error: \(error)")
                return
            }
            
            // Route the sample buffers to our BroadcastIngestEngine (WebRTC pipeline)
            switch bufferType {
            case .video:
                // BroadcastIngestEngine.shared.appendVideoSample(sampleBuffer)
                break
            case .audioApp:
                // BroadcastIngestEngine.shared.appendAudioSample(sampleBuffer)
                break
            case .audioMic:
                // BroadcastIngestEngine.shared.appendMicSample(sampleBuffer)
                break
            @unknown default:
                break
            }
            
        }) { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    print("⚠️ [ScreenRecording] Failed to start: \(error)")
                    self?.isRecording = false
                } else {
                    print("🔴 [ScreenRecording] Started screen capture.")
                    self?.isRecording = true
                }
            }
        }
    }
    
    func stopRecording() {
        recorder.stopCapture { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    print("⚠️ [ScreenRecording] Failed to stop: \(error)")
                } else {
                    print("⏹ [ScreenRecording] Stopped screen capture.")
                    self?.isRecording = false
                }
            }
        }
    }
}
