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
                    viewModel.cameraState.isActive = true
                }
                .onDisappear {
                    cameraManager.stopSession()
                    viewModel.cameraState.isActive = false
                }
                .onChange(of: viewModel.cameraState.position) { newPosition in
                    cameraManager.switchCamera(to: newPosition)
                }
                .onChange(of: viewModel.cameraState.flashMode) { newFlashMode in
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