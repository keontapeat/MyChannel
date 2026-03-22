//
//  VisualSearchSheet.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import SwiftUI
import AVFoundation
import Vision
import VisionKit

// 📷 Visual Search Sheet
// Camera-based search using OCR and image recognition
struct VisualSearchSheet: View {
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isShowingCamera = false
    @State private var isShowingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var extractedText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                if isProcessing {
                    processingView
                } else if !extractedText.isEmpty {
                    resultsView
                } else {
                    mainView
                }
            }
            .padding()
            .navigationTitle("Visual Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraView { image in
                    selectedImage = image
                    processImage(image)
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker { image in
                    selectedImage = image
                    processImage(image)
                }
            }
        }
    }
    
    // MARK: - Main View
    private var mainView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.Colors.primary)
            
            // Title
            VStack(spacing: 12) {
                Text("Visual Search")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Take a photo or select an image to search for text")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 16) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    isShowingCamera = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                        
                        Text("Take Photo")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(AppTheme.CornerRadius.md)
                }
                
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    isShowingImagePicker = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 20))
                        
                        Text("Choose from Library")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.md)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                .scaleEffect(1.5)
            
            Text("Analyzing image...")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(AppTheme.CornerRadius.md)
                    .opacity(0.7)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 24) {
            // Success Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Text Found!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            // Extracted Text
            ScrollView {
                Text(extractedText)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding()
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(AppTheme.CornerRadius.md)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    onComplete(extractedText)
                }) {
                    Text("Search for this text")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(AppTheme.CornerRadius.md)
                }
                
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    resetView()
                }) {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Image Processing
    private func processImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let text = try await extractTextFromImage(image)
                await MainActor.run {
                    extractedText = text
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to extract text from image"
                    isProcessing = false
                }
            }
        }
    }
    
    private func extractTextFromImage(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw VisualSearchError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: VisualSearchError.noTextFound)
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    return try? observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: " ")
                
                if fullText.isEmpty {
                    continuation.resume(throwing: VisualSearchError.noTextFound)
                } else {
                    continuation.resume(returning: fullText)
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func resetView() {
        selectedImage = nil
        extractedText = ""
        errorMessage = nil
        isProcessing = false
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
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
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Errors
enum VisualSearchError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in image"
        case .processingFailed:
            return "Failed to process image"
        }
    }
}
