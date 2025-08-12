//
//  CreateStoryView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct CreateStoryView: View {
    @StateObject private var viewModel = CreateStoryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingTextEditor = false
    @State private var showingStickers = false
    @State private var showingMusicPicker = false
    @State private var showCaptionEditor = false
    @State private var dragOffset = CGSize.zero
    @State private var lastScale: CGFloat = 1.0
    @State private var currentScale: CGFloat = 1.0
    
    let onStoryCreated: (Story) -> Void
    
    init(onStoryCreated: @escaping (Story) -> Void) {
        self.onStoryCreated = onStoryCreated
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Main Content Area
                ZStack {
                    // Story Preview Area
                    StoryPreviewCanvas(
                        viewModel: viewModel,
                        geometry: geometry
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                // Convert to normalized coordinates within the canvas frame
                                let size = geometry.size
                                let loc = value.location
                                let normalized = CGPoint(
                                    x: max(0, min(1, loc.x / size.width)),
                                    y: max(0, min(1, loc.y / size.height))
                                )
                                viewModel.focus(at: normalized)
                            }
                    )
                    
                    // Overlays and interactive elements
                    ForEach(viewModel.stickers) { sticker in
                        InteractiveStickerView(
                            sticker: sticker,
                            onUpdate: { updatedSticker in
                                viewModel.updateSticker(updatedSticker)
                            },
                            onRemove: {
                                viewModel.removeSticker(sticker)
                            }
                        )
                    }
                    
                    if let textOverlay = viewModel.textOverlay {
                        InteractiveTextOverlay(
                            textOverlay: textOverlay,
                            onUpdate: { updatedOverlay in
                                viewModel.updateTextOverlay(updatedOverlay)
                            },
                            onRemove: {
                                viewModel.removeTextOverlay()
                            }
                        )
                    }
                }
                .clipped()
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                currentScale = lastScale * value
                            }
                            .onEnded { value in
                                lastScale = currentScale
                                viewModel.updateScale(currentScale)
                            },
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                viewModel.updateOffset(value.translation)
                                dragOffset = .zero
                            }
                    )
                )
                
                // Top Controls
                VStack {
                    StoryCreationHeader(
                        viewModel: viewModel,
                        onDismiss: { dismiss() },
                        onFlashToggle: { viewModel.toggleFlash() },
                        onCameraSwitch: { viewModel.switchCamera() }
                    )
                    
                    Spacer()
                    
                    // Bottom Controls
                    StoryCreationControls(
                        viewModel: viewModel,
                        onCameraTap: { showingCamera = true },
                        onPhotoTap: { showingPhotoPicker = true },
                        onTextTap: { showingTextEditor = true },
                        onStickerTap: { showingStickers = true },
                        onMusicTap: { showingMusicPicker = true },
                        onPost: {
                            Task {
                                await postStory()
                            }
                        }
                    )
                    // Minimal publish options (compact pill buttons)
                    PublishCompactBar(
                        captionPreview: viewModel.caption,
                        audience: $viewModel.audience,
                        onEditCaption: { showCaptionEditor = true }
                    )
                }
                .padding()
                
                // Loading overlay
                if viewModel.isProcessing {
                    ProcessingOverlay()
                }
            }
        }
        .statusBarHidden()
        .sheet(isPresented: $showingCamera) {
            ModernCameraView { capturedMedia in
                viewModel.setMedia(capturedMedia)
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ModernPhotoPicker { selectedMedia in
                viewModel.setMedia(selectedMedia)
            }
        }
        .sheet(isPresented: $showingTextEditor) {
            TextEditorSheet { textStyle in
                viewModel.addTextOverlay(textStyle)
            }
            .presentationDetents([.height(300), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingStickers) {
            StickerPickerSheet { sticker in
                viewModel.addSticker(sticker)
            }
            .presentationDetents([.height(400), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingMusicPicker) {
            MusicPickerSheet { music in
                viewModel.setBackgroundMusic(music)
            }
            .presentationDetents([.height(500), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCaptionEditor) {
            CaptionEditorSheet(text: $viewModel.caption)
                .presentationDetents([.height(220), .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    private func postStory() async {
        let story = await viewModel.createStory()
        await MainActor.run {
            onStoryCreated(story)
            dismiss()
        }
    }
}

// MARK: - Story Preview Canvas
struct StoryPreviewCanvas: View {
    @ObservedObject var viewModel: CreateStoryViewModel
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Background based on story type
            Group {
                switch viewModel.storyType {
                case .camera:
                    if viewModel.isCameraActive {
                        CameraPreviewView(viewModel: viewModel)
                    } else {
                        Color.black.opacity(0.8)
                            .overlay(
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text("Tap camera to start")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            )
                    }
                    
                case .photo, .video:
                    if let media = viewModel.selectedMedia {
                        AsyncImage(url: media.url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    
                case .text:
                    LinearGradient(
                        colors: viewModel.backgroundGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .clipped()
            .scaleEffect(viewModel.scale)
            .offset(viewModel.offset)
        }
        .aspectRatio(9/16, contentMode: .fit)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .overlay(alignment: .topLeading) {
            if let fp = viewModel.focusPoint {
                FocusPulseView()
                    .position(x: fp.x * geometry.size.width, y: fp.y * geometry.size.height)
                    .id(viewModel.focusPulseID)
            }
        }
    }
}

// MARK: - Focus Pulse
struct FocusPulseView: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: 60, height: 60)
                .scaleEffect(animate ? 1.15 : 0.9)
                .opacity(animate ? 0.0 : 1.0)
            Circle().stroke(Color.white.opacity(0.6), lineWidth: 1)
                .frame(width: 30, height: 30)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { animate = true }
        }
    }
}

// MARK: - Story Creation Header
struct StoryCreationHeader: View {
    @ObservedObject var viewModel: CreateStoryViewModel
    let onDismiss: () -> Void
    let onFlashToggle: () -> Void
    let onCameraSwitch: () -> Void
    
    var body: some View {
        HStack {
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Camera controls (only show when using camera)
            if viewModel.storyType == .camera {
                HStack(spacing: 16) {
                    // Flash button
                    Button(action: onFlashToggle) {
                        Image(systemName: viewModel.flashMode.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(viewModel.flashMode == .on ? .yellow : .white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    // Camera switch button
                    Button(action: onCameraSwitch) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
            }
            
            // Timer/Duration display
            if viewModel.isRecording {
                Text(viewModel.recordingDuration)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.8))
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Story Creation Controls
struct StoryCreationControls: View {
    @ObservedObject var viewModel: CreateStoryViewModel
    let onCameraTap: () -> Void
    let onPhotoTap: () -> Void
    let onTextTap: () -> Void
    let onStickerTap: () -> Void
    let onMusicTap: () -> Void
    let onPost: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Creation tools
            HStack(spacing: 24) {
                CreationToolButton(
                    icon: "camera.fill",
                    title: "Camera",
                    isSelected: viewModel.storyType == .camera,
                    action: onCameraTap
                )
                
                CreationToolButton(
                    icon: "photo.fill",
                    title: "Photo",
                    isSelected: viewModel.storyType == .photo,
                    action: onPhotoTap
                )
                
                CreationToolButton(
                    icon: "textformat.abc",
                    title: "Text",
                    isSelected: viewModel.storyType == .text,
                    action: onTextTap
                )
                
                CreationToolButton(
                    icon: "face.smiling.fill",
                    title: "Sticker",
                    isSelected: false,
                    action: onStickerTap
                )
                
                CreationToolButton(
                    icon: "music.note",
                    title: "Music",
                    isSelected: viewModel.hasBackgroundMusic,
                    action: onMusicTap
                )
            }
            
            // Capture/Post button
            HStack(spacing: 16) {
                if viewModel.canPost {
                    Button(action: onPost) {
                        HStack(spacing: 8) {
                            if viewModel.isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            
                            Text(viewModel.isProcessing ? "Posting..." : "Share Story")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.Colors.primary)
                        .cornerRadius(25)
                        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(viewModel.isProcessing)
                } else {
                    // Capture button for camera mode
                    if viewModel.storyType == .camera {
                        CaptureButton(
                            isRecording: viewModel.isRecording,
                            onTap: { viewModel.capturePhoto() },
                            onLongPress: { pressed in
                                if pressed {
                                    viewModel.startRecording()
                                } else {
                                    viewModel.stopRecording()
                                }
                            }
                        )
                        .overlay(alignment: .topTrailing) {
                            if viewModel.isRecording {
                                Text(viewModel.recordingDuration)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(.red.opacity(0.8), in: Capsule())
                                    .offset(y: -54)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Publish extras (caption + audience)
struct PublishExtrasView: View {
    @Binding var caption: String
    @Binding var audience: CreateStoryViewModel.Audience
    var body: some View {
        VStack(spacing: 10) {
            TextField("Add a caption...", text: $caption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(.white)
                .tint(.white)
            HStack {
                Text("Audience").foregroundStyle(.white.opacity(0.8))
                Spacer()
                Picker("Audience", selection: $audience) {
                    ForEach(CreateStoryViewModel.Audience.allCases, id: \.self) { a in
                        Text(a.rawValue.capitalized).tag(a)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Compact publish bar + caption editor sheet
private struct PublishCompactBar: View {
    let captionPreview: String
    @Binding var audience: CreateStoryViewModel.Audience
    let onEditCaption: () -> Void
    @State private var showAudienceDialog = false
    var body: some View {
        HStack(spacing: 10) {
            Button(action: onEditCaption) {
                HStack(spacing: 6) {
                    Image(systemName: captionPreview.isEmpty ? "text.bubble" : "text.bubble.fill")
                    Text(captionPreview.isEmpty ? "Add caption" : String(captionPreview.prefix(18)))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
            }
            Spacer()
            Button(action: { showAudienceDialog = true }) {
                HStack(spacing: 6) {
                    Image(systemName: audience == .public ? "globe" : "person.2.fill")
                    Text(audience.rawValue.capitalized)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
            }
            .confirmationDialog("Audience", isPresented: $showAudienceDialog, titleVisibility: .visible) {
                Button("Public") { audience = .public }
                Button("Friends") { audience = .friends }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

// MARK: - Creation Tool Button
struct CreationToolButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? AppTheme.Colors.primary : .white)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}

// MARK: - Capture Button
struct CaptureButton: View {
    let isRecording: Bool
    let onTap: () -> Void
    let onLongPress: (Bool) -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .fill(isRecording ? .red : .white)
                    .frame(width: isRecording ? 35 : 58, height: isRecording ? 35 : 58)
                    .scaleEffect(isPressed ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
                
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0.1,
            perform: { },
            onPressingChanged: { pressing in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = pressing
                }
                onLongPress(pressing)
            }
        )
    }
}

// MARK: - Processing Overlay
struct ProcessingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Creating your story...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.black.opacity(0.8))
            .cornerRadius(16)
        }
    }
}

// MARK: - Caption Editor Sheet
private struct CaptionEditorSheet: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 4)
                .padding(.top, 6)
            Text("Caption")
                .font(.headline)
                .foregroundStyle(.white)
            TextField("Add a caption...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .tint(.white)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    CreateStoryView { story in
        print("Story created: \(story.id)")
    }
}