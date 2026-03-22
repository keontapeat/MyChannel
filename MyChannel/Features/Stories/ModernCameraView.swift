//
//  ModernCameraView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import AVFoundation

struct ModernCameraView: View {
    let onMediaCaptured: (CreateStoryViewModel.MediaItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var isRecording = false
    @State private var flashMode: CreateStoryViewModel.FlashMode = .off
    @State private var cameraPosition: AVCaptureDevice.Position = .back
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Camera preview
            CameraPreview(cameraManager: cameraManager)
                .onAppear {
                    cameraManager.startSession()
                }
                .onDisappear {
                    cameraManager.stopSession()
                }
            
            // Camera controls overlay
            VStack {
                // Top controls
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Flash button
                    Button(action: toggleFlash) {
                        Image(systemName: flashMode.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(flashMode == .on ? .yellow : .white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    // Camera switch button
                    Button(action: switchCamera) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Bottom controls
                HStack {
                    Spacer()
                    
                    // Capture button
                    CaptureButton(
                        isRecording: isRecording,
                        onTap: capturePhoto,
                        onLongPress: { pressed in
                            if pressed {
                                startRecording()
                            } else {
                                stopRecording()
                            }
                        }
                    )
                    
                    Spacer()
                }
                .padding()
            }
        }
        .statusBarHidden()
    }
    
    private func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        }
        cameraManager.setFlashMode(flashMode)
    }
    
    private func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        cameraManager.switchCamera(to: cameraPosition)
    }
    
    private func capturePhoto() {
        cameraManager.capturePhoto { [self] imageURL in
            guard let imageURL = imageURL else { return }
            let mediaItem = CreateStoryViewModel.MediaItem(
                url: imageURL,
                type: .image,
                duration: nil
            )
            DispatchQueue.main.async {
                onMediaCaptured(mediaItem)
                dismiss()
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        cameraManager.startVideoRecording()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if isRecording {
                stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        
        cameraManager.stopVideoRecording { [self] videoURL in
            guard let videoURL = videoURL else { return }
            let mediaItem = CreateStoryViewModel.MediaItem(
                url: videoURL,
                type: .video,
                duration: 15.0
            )
            DispatchQueue.main.async {
                onMediaCaptured(mediaItem)
                dismiss()
            }
        }
    }
}

#Preview {
    ModernCameraView { mediaItem in
        print("Media captured: \(mediaItem.url)")
    }
}