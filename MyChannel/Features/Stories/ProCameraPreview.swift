//
//  ProCameraPreview.swift
//  MyChannel
//
//  📹 PROFESSIONAL CAMERA PREVIEW
//  Real-time camera feed with overlay support
//

import SwiftUI
import AVFoundation

struct ProCameraPreview: UIViewRepresentable {
    @ObservedObject var engine: ProCameraEngine
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.videoPreviewLayer.session = engine.captureSession
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Update if needed
    }
    
    class CameraPreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}


