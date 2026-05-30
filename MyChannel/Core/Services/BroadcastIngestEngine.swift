import Foundation
import AVFoundation

/// Phase 54: Low-latency WebRTC Livestreaming Ingest
/// Connects local camera and microphone feeds to a mock WebRTC ingest server.
@MainActor
final class BroadcastIngestEngine: ObservableObject {
    static let shared = BroadcastIngestEngine()
    
    @Published var isBroadcasting: Bool = false
    @Published var broadcastError: String?
    
    private var captureSession: AVCaptureSession?
    
    private init() {}
    
    /// Starts local camera capture and connects to the WebRTC ingest proxy
    func startBroadcast() {
        guard !isBroadcasting else { return }
        
        // 1. Setup local AV session
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }
        session.sessionPreset = .high
        
        do {
            // Video input
            if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if session.canAddInput(videoInput) { session.addInput(videoInput) }
            }
            
            // Audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) { session.addInput(audioInput) }
            }
            
            // Video Data Output (simulating feeding frames to WebRTC)
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
            
            // Note: In a real WebRTC app, we'd assign a sample buffer delegate here and pass CMSampleBuffers to the WebRTC VideoTrack.
            
            Task.detached {
                session.startRunning()
            }
            
            isBroadcasting = true
            print("📡 [BroadcastIngest] Started local WebRTC broadcast ingest.")
        } catch {
            broadcastError = error.localizedDescription
            print("⚠️ [BroadcastIngest] Failed to start broadcast: \(error)")
        }
    }
    
    func stopBroadcast() {
        guard isBroadcasting else { return }
        
        let sessionToStop = self.captureSession
        self.captureSession = nil
        isBroadcasting = false
        
        Task.detached {
            sessionToStop?.stopRunning()
        }
        
        print("🔌 [BroadcastIngest] Stopped broadcast.")
    }
}
