//
//  UltimateStoryCreatorView.swift
//  MyChannel
//
//  🔥🔥🔥 THE ULTIMATE STORY CREATOR - BEST IN THE WORLD! 🔥🔥🔥
//  Professional story creation with AI-powered tools, advanced editing, and premium features
//

import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Ultimate Story Creator
struct UltimateStoryCreatorView: View {
    @StateObject private var viewModel = UltimateStoryViewModel()
    @StateObject private var cameraEngine = ProCameraEngine()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingModePicker = false
    @State private var showingAITools = false
    @State private var showingTemplates = false
    @State private var showingEffects = false
    @State private var isDraggingElement = false
    @State private var selectedElement: EditableElement?
    
    var onStoryCreated: (Story) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 🎬 CAMERA CANVAS (Main recording area)
                cameraCanvas
                
                // ✨ FLOATING UI LAYERS (Non-intrusive controls)
                floatingControls
                
                // 🎨 EDITING WORKSPACE (When media captured)
                if viewModel.hasMedia {
                    editingWorkspace
                }
                
                // 🚀 ACTION BAR (Bottom controls)
                actionBar
                    .frame(maxHeight: .infinity, alignment: .bottom)
                
                // 💫 MODALS & SHEETS
                modalOverlays
                
                // ⏱️ PROCESSING OVERLAY
                if viewModel.isProcessing {
                    processingOverlay
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden()
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - Camera Canvas
    private var cameraCanvas: some View {
        ZStack {
            // Camera feed or captured media
            if let media = viewModel.currentMedia {
                // Show captured media
                mediaPreview(media)
                    .transition(.opacity)
            } else {
                // Live camera feed
                ProCameraPreview(engine: cameraEngine)
                    .onTapGesture(coordinateSpace: .local) { location in
                        // Tap to focus
                        cameraEngine.focus(at: location)
                    }
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                cameraEngine.zoom(to: value)
                            }
                    )
            }
            
            // 🎯 FOCUS INDICATOR
            if let focusPoint = cameraEngine.focusPoint {
                FocusIndicatorView()
                    .position(focusPoint)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // 📐 GRID OVERLAY (Rule of thirds)
            if viewModel.showGrid {
                GridOverlay()
                    .transition(.opacity)
            }
            
            // 🎭 AR EFFECTS & FILTERS
            if let effect = viewModel.selectedEffect {
                AREffectOverlay(effect: effect)
                    .transition(.opacity)
            }
            
            // ✍️ EDITABLE ELEMENTS (Text, stickers, drawings)
            ForEach(viewModel.editableElements) { element in
                EditableElementView(
                    element: element,
                    isSelected: selectedElement?.id == element.id,
                    onTap: { selectedElement = element },
                    onDrag: { translation in
                        viewModel.updateElement(element.id, offset: translation)
                    },
                    onScale: { scale in
                        viewModel.updateElement(element.id, scale: scale)
                    },
                    onRotate: { angle in
                        viewModel.updateElement(element.id, rotation: angle)
                    }
                )
            }
        }
        .background(Color.black)
    }
    
    // MARK: - Floating Controls (Top)
    private var floatingControls: some View {
        VStack {
            HStack(spacing: 12) {
                // Close button
                FloatingButton(icon: "xmark", size: 44) {
                    confirmDismiss()
                }
                
                Spacer()
                
                // 🎛️ Camera controls
                HStack(spacing: 12) {
                    // Flash toggle
                    FloatingButton(
                        icon: cameraEngine.flashMode.icon,
                        isActive: cameraEngine.flashMode != .off,
                        size: 44
                    ) {
                        cameraEngine.toggleFlash()
                    }
                    
                    // Switch camera
                    FloatingButton(icon: "arrow.triangle.2.circlepath.camera", size: 44) {
                        cameraEngine.switchCamera()
                    }
                    
                    // Grid toggle
                    FloatingButton(
                        icon: "grid",
                        isActive: viewModel.showGrid,
                        size: 44
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.showGrid.toggle()
                        }
                    }
                    
                    // Settings
                    FloatingButton(icon: "slider.horizontal.3", size: 44) {
                        showingModePicker = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            Spacer()
        }
    }
    
    // MARK: - Editing Workspace
    private var editingWorkspace: some View {
        VStack {
            Spacer()
            
            // 🎨 EDITING TOOLS BAR
            EditingToolsBar(
                selectedTool: $viewModel.selectedTool,
                onTextAdd: {
                    viewModel.addTextElement()
                },
                onStickerAdd: {
                    // Show sticker picker
                },
                onDrawingStart: {
                    viewModel.startDrawing()
                },
                onMusicAdd: {
                    // Show music picker
                },
                onFilterAdd: {
                    showingEffects = true
                },
                onTemplateApply: {
                    showingTemplates = true
                },
                onAIEnhance: {
                    showingAITools = true
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - Action Bar (Bottom)
    private var actionBar: some View {
        VStack(spacing: 16) {
            // 🎯 MODE SELECTOR (if no media captured yet)
            if !viewModel.hasMedia {
                ModeSelector(
                    selectedMode: $viewModel.recordingMode,
                    modes: RecordingMode.allCases
                )
                .padding(.horizontal, 20)
            }
            
            // 🎬 MAIN ACTION CONTROLS
            HStack(spacing: 20) {
                // Photo library
                PhotoLibraryButton {
                    viewModel.openPhotoPicker()
                }
                
                Spacer()
                
                // 📹 CAPTURE BUTTON (CENTER)
                if !viewModel.hasMedia {
                    ProCaptureButton(
                        isRecording: cameraEngine.isRecording,
                        recordingDuration: cameraEngine.recordingDuration,
                        mode: viewModel.recordingMode,
                        onTap: {
                            capturePhoto()
                        },
                        onLongPressStart: {
                            startRecording()
                        },
                        onLongPressEnd: {
                            stopRecording()
                        }
                    )
                } else {
                    // ✅ POST BUTTON (When media captured)
                    PostButton {
                        postStory()
                    }
                }
                
                Spacer()
                
                // Speed control
                if !viewModel.hasMedia {
                    SpeedControlButton(
                        currentSpeed: $viewModel.recordingSpeed,
                        speeds: [0.3, 0.5, 1.0, 2.0, 3.0]
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Modal Overlays
    private var modalOverlays: some View {
        Group {
            // 🎨 Effects Picker
            if showingEffects {
                EffectPickerView(
                    selectedEffect: $viewModel.selectedEffect,
                    onDismiss: { showingEffects = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 📋 Templates Gallery
            if showingTemplates {
                TemplateGalleryView(
                    onTemplateSelect: { template in
                        viewModel.applyTemplate(template)
                        showingTemplates = false
                    },
                    onDismiss: { showingTemplates = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 🤖 AI Tools Panel
            if showingAITools {
                AIToolsPanel(
                    viewModel: viewModel,
                    onDismiss: { showingAITools = false }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingEffects)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingTemplates)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingAITools)
    }
    
    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(viewModel.processingMessage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                if viewModel.processingProgress > 0 {
                    ProgressView(value: viewModel.processingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(width: 200)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func setupCamera() {
        Task {
            await cameraEngine.startSession()
        }
    }
    
    private func cleanup() {
        cameraEngine.stopSession()
    }
    
    private func capturePhoto() {
        HapticManager.shared.impact(style: .medium)
        
        Task {
            if let image = await cameraEngine.capturePhoto() {
                await viewModel.setMedia(.image(image))
            }
        }
    }
    
    private func startRecording() {
        HapticManager.shared.impact(style: .medium)
        
        Task {
            await cameraEngine.startRecording()
        }
    }
    
    private func stopRecording() {
        HapticManager.shared.impact(style: .light)
        
        Task {
            if let videoURL = await cameraEngine.stopRecording() {
                await viewModel.setMedia(.video(videoURL))
            }
        }
    }
    
    private func postStory() {
        HapticManager.shared.impact(style: .heavy)
        
        Task {
            do {
                let story = try await viewModel.createStory()
                onStoryCreated(story)
                dismiss()
            } catch {
                print("🚨 Failed to create story: \(error)")
            }
        }
    }
    
    private func confirmDismiss() {
        if viewModel.hasMedia {
            // Show confirmation
            // For now, just dismiss
        }
        dismiss()
    }
    
    private func mediaPreview(_ media: CapturedMedia) -> some View {
        ZStack {
            switch media {
            case .image(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .video(let url):
                StoryVideoPlayerView(url: url)
            }
        }
    }
}

// MARK: - Media Preview View
struct StoryVideoPlayerView: View {
    let url: URL
    
    var body: some View {
        // TODO: Implement video player
        Color.black
    }
}

// MARK: - Floating Button
struct FloatingButton: View {
    let icon: String
    var isActive: Bool = false
    var size: CGFloat = 44
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? AppTheme.Colors.primary : Color.black.opacity(0.5))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Pro Capture Button
struct ProCaptureButton: View {
    let isRecording: Bool
    let recordingDuration: TimeInterval
    let mode: RecordingMode
    let onTap: () -> Void
    let onLongPressStart: () -> Void
    let onLongPressEnd: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Outer ring (recording indicator)
            Circle()
                .stroke(isRecording ? Color.red : Color.white, lineWidth: 4)
                .frame(width: 80, height: 80)
                .scaleEffect(isPressed ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isPressed)
            
            // Inner button
            ZStack {
                if isRecording {
                    // Recording: Square shape
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red)
                        .frame(width: 32, height: 32)
                } else {
                    // Idle: Circle
                    Circle()
                        .fill(mode.color)
                        .frame(width: 64, height: 64)
                }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3), value: isPressed)
            
            // Recording duration
            if isRecording {
                Text(formatDuration(recordingDuration))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .offset(y: -60)
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    if !isRecording {
                        onTap()
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.2)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onLongPressStart()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onLongPressEnd()
                }
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Photo Library Button
struct PhotoLibraryButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Speed Control Button
struct SpeedControlButton: View {
    @Binding var currentSpeed: Double
    let speeds: [Double]
    
    @State private var showingPicker = false
    
    var body: some View {
        Button(action: { showingPicker.toggle() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text("\(formatSpeed(currentSpeed))×")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if speed == 1.0 { return "1" }
        return String(format: "%.1f", speed)
    }
}

// MARK: - Post Button
struct PostButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Post Story")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 200, height: 56)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Focus Indicator
struct FocusIndicatorView: View {
    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                    opacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        opacity = 0
                    }
                }
            }
    }
}

// MARK: - Grid Overlay
struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                // Vertical lines (rule of thirds)
                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))
                
                path.move(to: CGPoint(x: width * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: width * 2 / 3, y: height))
                
                // Horizontal lines (rule of thirds)
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))
                
                path.move(to: CGPoint(x: 0, y: height * 2 / 3))
                path.addLine(to: CGPoint(x: width, y: height * 2 / 3))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
    }
}

// MARK: - AR Effect Overlay
struct AREffectOverlay: View {
    let effect: AREffect
    
    var body: some View {
        // TODO: Implement AR effects
        Color.clear
    }
}

// MARK: - Mode Selector
struct ModeSelector: View {
    @Binding var selectedMode: RecordingMode
    let modes: [RecordingMode]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(modes) { mode in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMode = mode
                        }
                        HapticManager.shared.impact(style: .light)
                    }) {
                        VStack(spacing: 4) {
                            Text(mode.title)
                                .font(.system(size: 14, weight: selectedMode == mode ? .bold : .medium))
                                .foregroundColor(selectedMode == mode ? .white : .white.opacity(0.6))
                            
                            if selectedMode == mode {
                                Circle()
                                    .fill(mode.color)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    UltimateStoryCreatorView { story in
        print("Story created: \(story.id)")
    }
}

