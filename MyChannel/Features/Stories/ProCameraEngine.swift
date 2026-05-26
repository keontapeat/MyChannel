//
//  ProCameraEngine.swift
//  MyChannel
//
//  🎬 PROFESSIONAL CAMERA ENGINE
//  Advanced camera control with multi-lens support, HDR, and professional features
//

import SwiftUI
import AVFoundation
import Photos

@MainActor
class ProCameraEngine: NSObject, ObservableObject {
    
    // MARK: - Published State
    @Published var isSessionRunning = false
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var zoomFactor: CGFloat = 1.0
    @Published var focusPoint: CGPoint?
    @Published var capturedPhoto: UIImage?
    @Published var recordedVideoURL: URL?
    
    // Camera session
    let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()
    
    // Quality settings
    private let sessionQueue = DispatchQueue(label: "com.mychannel.camera.session")
    private var setupResult: SessionSetupResult = .success
    
    // Recording timer
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    // Camera capabilities
    private var supportedZoomFactors: [CGFloat] = [0.5, 1.0, 2.0]
    private var currentZoomIndex = 1 // Start at 1x
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Session Management
    func startSession() async {
        // Check authorization
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            // Request permission
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                setupResult = .notAuthorized
                return
            }
        default:
            setupResult = .notAuthorized
            return
        }
        
        // Setup on background queue
        sessionQueue.async { [weak self] in
            self?.configureSession()
            
            if self?.setupResult == .success {
                self?.captureSession.startRunning()
                
                Task { @MainActor in
                    self?.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            if self?.setupResult == .success {
                self?.captureSession.stopRunning()
                
                Task { @MainActor in
                    self?.isSessionRunning = false
                }
            }
        }
    }
    
    private func configureSession() {
        guard setupResult == .success else { return }
        
        captureSession.beginConfiguration()
        
        // Set session preset for high quality
        captureSession.sessionPreset = .photo
        
        // Add video input
        do {
            let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)
            
            guard let device = videoDevice else {
                print("🚨 Default video device unavailable")
                setupResult = .configurationFailed
                captureSession.commitConfiguration()
                return
            }
            
            let input = try AVCaptureDeviceInput(device: device)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                videoDeviceInput = input
            } else {
                print("🚨 Could not add video device input")
                setupResult = .configurationFailed
                captureSession.commitConfiguration()
                return
            }
        } catch {
            print("🚨 Could not create video device input: \(error)")
            setupResult = .configurationFailed
            captureSession.commitConfiguration()
            return
        }
        
        // Add photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
        } else {
            print("🚨 Could not add photo output")
            setupResult = .configurationFailed
            captureSession.commitConfiguration()
            return
        }
        
        // Add movie output
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        } else {
            print("🚨 Could not add movie output")
        }
        
        captureSession.commitConfiguration()
    }
    
    // MARK: - Camera Controls
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newPosition: AVCaptureDevice.Position = self.cameraPosition == .back ? .front : .back
            
            guard let currentInput = self.videoDeviceInput else { return }
            
            // Find new camera device
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                print("🚨 Could not find camera for position: \(newPosition)")
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                
                self.captureSession.beginConfiguration()
                self.captureSession.removeInput(currentInput)
                
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.videoDeviceInput = newInput
                } else {
                    self.captureSession.addInput(currentInput)
                }
                
                self.captureSession.commitConfiguration()
                
                Task { @MainActor in
                    self.cameraPosition = newPosition
                    self.zoomFactor = 1.0
                }
                
            } catch {
                print("🚨 Error switching camera: \(error)")
            }
        }
    }
    
    func toggleFlash() {
        let modes: [AVCaptureDevice.FlashMode] = [.off, .on, .auto]
        let currentIndex = modes.firstIndex(of: flashMode) ?? 0
        let nextIndex = (currentIndex + 1) % modes.count
        flashMode = modes[nextIndex]
    }
    
    func zoom(to scale: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            let newZoom = max(1.0, min(scale, device.maxAvailableVideoZoomFactor))
            device.videoZoomFactor = newZoom
            zoomFactor = newZoom
            
            device.unlockForConfiguration()
        } catch {
            print("🚨 Error adjusting zoom: \(error)")
        }
    }
    
    func cycleZoom() {
        guard let device = videoDeviceInput?.device else { return }
        
        currentZoomIndex = (currentZoomIndex + 1) % supportedZoomFactors.count
        let targetZoom = supportedZoomFactors[currentZoomIndex]
        
        do {
            try device.lockForConfiguration()
            
            UIView.animate(withDuration: 0.3) {
                device.videoZoomFactor = targetZoom
            }
            
            zoomFactor = targetZoom
            device.unlockForConfiguration()
            
        } catch {
            print("🚨 Error cycling zoom: \(error)")
        }
    }
    
    func focus(at point: CGPoint) {
        guard let device = videoDeviceInput?.device else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            
            // Show focus indicator
            focusPoint = point
            
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.focusPoint = nil
            }
            
        } catch {
            print("🚨 Error focusing: \(error)")
        }
    }
    
    // MARK: - Photo Capture
    func capturePhoto() async -> UIImage? {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        
        let photoCaptureDelegate = PhotoCaptureDelegate()
        
        return await withCheckedContinuation { continuation in
            photoCaptureDelegate.continuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: photoCaptureDelegate)
        }
    }
    
    // MARK: - Video Recording
    func startRecording() async {
        guard !isRecording else { return }
        
        // Create temp URL
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        // Start recording
        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        
        isRecording = true
        recordingStartTime = Date()
        
        // Start timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingDuration()
            }
        }
        
        HapticManager.shared.impact(style: .medium)
    }
    
    func stopRecording() async -> URL? {
        guard isRecording else { return nil }
        
        movieOutput.stopRecording()
        
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
        
        HapticManager.shared.impact(style: .light)
        
        return recordedVideoURL
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension ProCameraEngine: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                print("🚨 Recording error: \(error)")
            } else {
                recordedVideoURL = outputFileURL
                print("✅ Video recorded: \(outputFileURL)")
            }
        }
    }
}

// MARK: - Photo Capture Delegate
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    var continuation: CheckedContinuation<UIImage?, Never>?
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("🚨 Photo capture error: \(error)")
            continuation?.resume(returning: nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            continuation?.resume(returning: nil)
            return
        }
        
        continuation?.resume(returning: image)
    }
}

