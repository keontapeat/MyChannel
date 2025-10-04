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
        // Simulate photo capture
        let mockURL = URL(string: "https://picsum.photos/400/800?random=\(Int.random(in: 1...100))")!
        let mediaItem = CreateStoryViewModel.MediaItem(
            url: mockURL,
            type: .image,
            duration: nil
        )
        onMediaCaptured(mediaItem)
        dismiss()
    }
    
    private func startRecording() {
        isRecording = true
        
        // Auto-stop after 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if isRecording {
                stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        
        // Simulate video capture
        let mockURL = URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
        let mediaItem = CreateStoryViewModel.MediaItem(
            url: mockURL,
            type: .video,
            duration: Double.random(in: 5...15)
        )
        onMediaCaptured(mediaItem)
        dismiss()
    }
}

#Preview {
    ModernCameraView { mediaItem in
        print("Media captured: \(mediaItem.url)")
    }
}