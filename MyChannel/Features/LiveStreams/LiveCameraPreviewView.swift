//
//  LiveCameraPreviewView.swift
//  MyChannel
//
//  UIViewRepresentable wrapping AVCaptureSession for live broadcast camera preview.
//

import SwiftUI
import AVFoundation

// MARK: - Camera Preview (UIViewRepresentable)
struct LiveCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> LiveCameraPreviewUIView {
        let view = LiveCameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: LiveCameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

final class LiveCameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

// MARK: - Camera Manager
@MainActor
final class LiveCameraManager: ObservableObject {
    let session = AVCaptureSession()

    @Published var isRunning = false
    @Published var isFrontCamera = true
    @Published var isMicMuted = false
    @Published var permissionGranted = false

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?

    func requestPermissions() async {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        var videoGranted = videoStatus == .authorized
        var audioGranted = audioStatus == .authorized

        if videoStatus == .notDetermined {
            videoGranted = await AVCaptureDevice.requestAccess(for: .video)
        }
        if audioStatus == .notDetermined {
            audioGranted = await AVCaptureDevice.requestAccess(for: .audio)
        }

        permissionGranted = videoGranted && audioGranted
    }

    func startSession() {
        guard permissionGranted, !isRunning else { return }

        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        // Video
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device) {
            if session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
            }
        }

        // Audio
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let input = try? AVCaptureDeviceInput(device: audioDevice) {
            if session.canAddInput(input) {
                session.addInput(input)
                audioInput = input
            }
        }

        session.commitConfiguration()

        Task.detached { [session] in
            session.startRunning()
            await MainActor.run { [weak self] in
                self?.isRunning = true
            }
        }

        print("📷 [CameraManager] Session started (front=\(isFrontCamera))")
    }

    func stopSession() {
        Task.detached { [session] in
            session.stopRunning()
            await MainActor.run { [weak self] in
                self?.isRunning = false
            }
        }
        print("📷 [CameraManager] Session stopped")
    }

    func flipCamera() {
        guard let currentInput = videoInput else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)

        isFrontCamera.toggle()
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let newInput = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(newInput) {
            session.addInput(newInput)
            videoInput = newInput
        }

        session.commitConfiguration()
    }

    func toggleMic() {
        isMicMuted.toggle()
        audioInput?.ports.forEach { $0.isEnabled = !isMicMuted }
    }
}
