//
//  CameraPreviewView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: View {
    @ObservedObject var viewModel: CreateStoryViewModel
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(cameraManager: cameraManager)
                .onAppear {
                    cameraManager.startSession()
                    viewModel.isCameraActive = true
                }
                .onDisappear {
                    cameraManager.stopSession()
                    viewModel.isCameraActive = false
                }
                .onChange(of: viewModel.cameraPosition) { _, newPosition in
                    cameraManager.switchCamera(to: newPosition)
                }
                .onChange(of: viewModel.flashMode) { _, newFlashMode in
                    cameraManager.setFlashMode(newFlashMode)
                }
            
            // Focus indicator
            if let focusPoint = cameraManager.focusPoint {
                FocusIndicator()
                    .position(focusPoint)
                    .animation(.easeInOut(duration: 0.3), value: focusPoint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            cameraManager.focus(at: location)
        }
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var focusPoint: CGPoint?
    
    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureMovieFileOutput?
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        
        // Configure session preset
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Failed to create video input")
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
            videoDeviceInput = videoInput
        }
        
        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }
        
        // Add video output for recording
        let videoOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
        
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            if let session = self?.captureSession, !session.isRunning {
                session.startRunning()
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            if let session = self?.captureSession, session.isRunning {
                session.stopRunning()
            }
        }
    }
    
    func switchCamera(to position: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Remove current input
            if let currentInput = self.videoDeviceInput {
                self.captureSession.removeInput(currentInput)
            }
            
            // Add new input
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                self.captureSession.commitConfiguration()
                return
            }
            
            if self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.videoDeviceInput = newInput
            }
            
            self.captureSession.commitConfiguration()
        }
    }
    
    func setFlashMode(_ flashMode: CreateStoryViewModel.FlashMode) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device,
                  device.hasFlash else { return }
            
            do {
                try device.lockForConfiguration()
                
                switch flashMode {
                case .off:
                    device.flashMode = .off
                case .on:
                    device.flashMode = .on
                case .auto:
                    device.flashMode = .auto
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Failed to set flash mode: \(error)")
            }
        }
    }
    
    func focus(at point: CGPoint) {
        DispatchQueue.main.async { [weak self] in
            self?.focusPoint = point
            
            // Hide focus indicator after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.focusPoint = nil
            }
        }
        
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device,
                  device.isFocusPointOfInterestSupported else { return }
            
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                device.unlockForConfiguration()
            } catch {
                print("Failed to set focus: \(error)")
            }
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable
struct CameraPreview: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> PreviewView {
        let preview = PreviewView()
        preview.videoPreviewLayer.session = cameraManager.captureSession
        preview.videoPreviewLayer.videoGravity = .resizeAspectFill
        return preview
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Updates handled by camera manager
    }
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Focus Indicator
struct FocusIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 0.8 : 1.0)
                .opacity(isAnimating ? 0.6 : 1.0)
            
            Circle()
                .stroke(.white, lineWidth: 1)
                .frame(width: 40, height: 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    CameraPreviewView(viewModel: CreateStoryViewModel())
}