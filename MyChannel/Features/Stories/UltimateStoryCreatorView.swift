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
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingModePicker = false
    @State private var showingAITools = false
    @State private var showingTemplates = false
    @State private var showingEffects = false
    @State private var showingPhotoPicker = false
    @State private var showingStickerPicker = false
    @State private var showingMusicPicker = false
    @State private var isDraggingElement = false
    @State private var selectedElement: EditableElement?
    @State private var modeRecordingTask: Task<Void, Never>?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingDiscardAlert = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
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
        // 📸 PHOTO PICKER SHEET
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 1,
            matching: .any(of: [.images, .videos]),
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItems) { newItems in
            Task {
                await loadSelectedMedia(from: newItems)
            }
        }
        // 🎵 MUSIC PICKER SHEET
        .sheet(isPresented: $showingMusicPicker) {
            MusicPickerSheet(
                selectedMusic: .constant(nil),
                onMusicSelected: { music in
                    viewModel.setMusic(MusicTrack(
                        title: music.title,
                        artist: music.artist,
                        duration: music.duration,
                        url: URL(string: music.previewURL) ?? URL(string: "https://example.com")!,
                        thumbnailURL: music.artworkURL.flatMap { URL(string: $0) }
                    ))
                    showingMusicPicker = false
                }
            )
            .presentationDetents([.height(500), .large])
            .presentationDragIndicator(.visible)
        }
        // 🎨 STICKER PICKER SHEET
        .sheet(isPresented: $showingStickerPicker) {
            StickerPickerSheet { sticker in
                // Extract emoji from sticker data
                let emojiString: String
                if let data = sticker.data as? String {
                    emojiString = data
                } else {
                    emojiString = "😀"
                }
                viewModel.addStickerElement(Sticker(
                    imageName: emojiString,
                    category: .emoji
                ))
                showingStickerPicker = false
            }
            .presentationDetents([.height(400), .large])
            .presentationDragIndicator(.visible)
        }
        // ❌ DISCARD CONFIRMATION
        .alert("Discard Story?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You'll lose all your changes if you go back now.")
        }
        // ⚠️ ERROR ALERT
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
    }
    
    // MARK: - Load Selected Media from Photo Picker
    private func loadSelectedMedia(from items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        
        // Check if it's a video
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
            // Load video
            do {
                if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
                    await viewModel.setMedia(.video(movie.url))
                    HapticManager.shared.notification(type: .success)
                }
            } catch {
                print("🚨 Failed to load video: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load video. Please try again."
                    showingError = true
                }
            }
        } else {
            // Load image
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.setMedia(.image(image))
                    HapticManager.shared.notification(type: .success)
                }
            } catch {
                print("🚨 Failed to load image: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load image. Please try again."
                    showingError = true
                }
            }
        }
        
        // Clear selection
        await MainActor.run {
            selectedPhotoItems = []
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
                    HapticManager.shared.impact(style: .light)
                    viewModel.addTextElement()
                },
                onStickerAdd: {
                    HapticManager.shared.impact(style: .light)
                    showingStickerPicker = true
                },
                onDrawingStart: {
                    HapticManager.shared.impact(style: .light)
                    viewModel.startDrawing()
                },
                onMusicAdd: {
                    HapticManager.shared.impact(style: .light)
                    showingMusicPicker = true
                },
                onFilterAdd: {
                    HapticManager.shared.impact(style: .light)
                    showingEffects = true
                },
                onTemplateApply: {
                    HapticManager.shared.impact(style: .light)
                    showingTemplates = true
                },
                onAIEnhance: {
                    HapticManager.shared.impact(style: .light)
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
                    HapticManager.shared.impact(style: .light)
                    showingPhotoPicker = true
                }
                
                Spacer()
                
                // 📹 CAPTURE BUTTON (CENTER)
                if !viewModel.hasMedia {
                    ProCaptureButton(
                        isRecording: cameraEngine.isRecording,
                        recordingDuration: cameraEngine.recordingDuration,
                        mode: viewModel.recordingMode,
                        onTap: {
                            handleCaptureTap()
                        },
                        onLongPressStart: {
                            guard viewModel.recordingMode == .normal else { return }
                            modeRecordingTask?.cancel()
                            modeRecordingTask = Task {
                                await startRecording()
                            }
                        },
                        onLongPressEnd: {
                            guard viewModel.recordingMode == .normal else { return }
                            modeRecordingTask?.cancel()
                            modeRecordingTask = Task {
                                await stopRecording()
                            }
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
        modeRecordingTask?.cancel()
        modeRecordingTask = nil
    }
    
    private func capturePhoto() {
        HapticManager.shared.impact(style: .medium)
        
        Task {
            if let image = await cameraEngine.capturePhoto() {
                await viewModel.setMedia(.image(image))
            }
        }
    }
    
    private func startRecording() async {
        HapticManager.shared.impact(style: .medium)
        await cameraEngine.startRecording()
    }
    
    private func stopRecording() async {
        HapticManager.shared.impact(style: .light)
        if let videoURL = await cameraEngine.stopRecording() {
            await processCapturedVideo(at: videoURL)
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
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
    
    private func handleCaptureTap() {
        switch viewModel.recordingMode {
        case .normal:
            capturePhoto()
        case .boomerang:
            modeRecordingTask?.cancel()
            modeRecordingTask = Task {
                await recordBoomerangClip()
            }
        case .superzoom:
            toggleSuperzoomRecording()
        case .handsFree, .slowMotion, .timeWarp:
            toggleHandsFreeRecording()
        }
    }
    
    private func toggleHandsFreeRecording() {
        modeRecordingTask?.cancel()
        modeRecordingTask = Task {
            if cameraEngine.isRecording {
                await stopRecording()
            } else {
                await startRecording()
                if let duration = viewModel.recordingMode.autoRecordDuration {
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                    if cameraEngine.isRecording {
                        await stopRecording()
                    }
                }
            }
        }
    }
    
    private func toggleSuperzoomRecording() {
        modeRecordingTask?.cancel()
        modeRecordingTask = Task {
            if cameraEngine.isRecording {
                await stopRecording()
            } else {
                await recordSuperzoomClip()
            }
        }
    }
    
    private func recordBoomerangClip() async {
        await startRecording()
        let duration = viewModel.recordingMode.autoRecordDuration ?? 1.2
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        if cameraEngine.isRecording {
            await stopRecording()
        }
    }
    
    private func recordSuperzoomClip() async {
        await startRecording()
        await animateSuperzoom(duration: viewModel.recordingMode.autoRecordDuration ?? 3.0)
        if cameraEngine.isRecording {
            await stopRecording()
        }
        await MainActor.run {
            cameraEngine.zoom(to: 1.0)
        }
    }
    
    private func animateSuperzoom(duration: TimeInterval) async {
        let steps = max(1, Int(duration * 10))
        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let zoom = 1.0 + progress * 2.0
            await MainActor.run {
                cameraEngine.zoom(to: CGFloat(zoom))
            }
            try? await Task.sleep(nanoseconds: UInt64((duration / Double(steps)) * 1_000_000_000))
        }
    }
    
    private func processCapturedVideo(at url: URL) async {
        if let message = viewModel.recordingMode.processingMessage {
            await MainActor.run {
                viewModel.processingMessage = message
                viewModel.isProcessing = true
            }
        }
        
        do {
            let processedURL = try await viewModel.processCapturedVideo(
                at: url,
                focusPoint: cameraEngine.focusPoint ?? CGPoint(x: 0.5, y: 0.5),
                mode: viewModel.recordingMode
            )
            await viewModel.setMedia(.video(processedURL))
        } catch {
            print("🚨 Failed to process video: \(error)")
            await viewModel.setMedia(.video(url))
        }
        
        await MainActor.run {
            viewModel.isProcessing = false
            viewModel.processingMessage = ""
            cameraEngine.zoom(to: 1.0)
        }
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
    @State private var player: AVPlayer?
    @State private var isPlaying = true
    
    var body: some View {
        ZStack {
            if let player = player {
                StoryVideoPlayerRepresentable(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Color.black
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            // Tap to toggle play/pause
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if isPlaying {
                        player?.pause()
                    } else {
                        player?.play()
                    }
                    isPlaying.toggle()
                    HapticManager.shared.impact(style: .light)
                }
            
            // Play/Pause indicator
            if !isPlaying {
                Image(systemName: "play.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(radius: 10)
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = false
        
        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }
}

// MARK: - Video Player UIKit Wrapper
struct StoryVideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

class PlayerUIView: UIView {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Video Transferable for Photo Picker
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
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

// ScaleButtonStyle moved to Core/Components/ButtonStyles.swift

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

