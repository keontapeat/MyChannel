//
//  SharedModels.swift
//  MyChannel
//
//  SHARED TYPES TO AVOID AMBIGUITY
//  Contains all frequently-used types in one place
//

import Foundation
import SwiftUI

// MARK: - Time Period

enum TimePeriod: String, CaseIterable, Identifiable {
    case day = "24 Hours"
    case week = "7 Days"
    case month = "30 Days"
    case quarter = "90 Days"
    case year = "Year"
    case allTime = "All Time"
    
    var id: String { rawValue }
}

// MARK: - Earnings Data Point

struct EarningsDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let source: String?
}

// MARK: - Video Clip

struct VideoClip: Identifiable {
    let id: String
    let url: URL
    var duration: TimeInterval
    var startTime: TimeInterval
    let endTime: TimeInterval
    let thumbnail: UIImage?
    var transition: VideoTransition = .none
    var speed: Double = 1.0
    var originalDuration: TimeInterval
    
    init(id: String, url: URL, duration: TimeInterval, startTime: TimeInterval, endTime: TimeInterval? = nil, thumbnail: UIImage? = nil, transition: VideoTransition = .none, speed: Double = 1.0) {
        self.id = id
        self.url = url
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime ?? duration
        self.thumbnail = thumbnail
        self.transition = transition
        self.speed = speed
        self.originalDuration = duration
    }
}

enum VideoTransition: String, Codable, CaseIterable {
    case none = "None"
    case fade = "Fade"
    case slide = "Slide"
    case zoom = "Zoom"
    case wipe = "Wipe"
    case dissolve = "Dissolve"
    
    var icon: String {
        switch self {
        case .none: return "minus"
        case .fade: return "circle.lefthalf.filled"
        case .slide: return "arrow.right"
        case .zoom: return "plus.magnifyingglass"
        case .wipe: return "wand.and.rays"
        case .dissolve: return "sparkles"
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Story Error

enum StoryError: Error, LocalizedError {
    case noMedia
    case exportFailed(String)
    case invalidVideo(String)
    case recordingFailed(String)
    case processingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noMedia:
            return "No media selected"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .invalidVideo(let message):
            return "Invalid video: \(message)"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        }
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double = 1.5
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

