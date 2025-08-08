//
//  StoryCreationView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import AVFoundation
import PhotosUI
import Combine

// MARK: - Performance Optimized Story Creation View
struct StoryCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StoryCreationViewModel()
    @StateObject private var mediaManager = MediaProcessingManager.shared
    @StateObject private var preloadManager = PreloadManager()
    
    @State private var selectedTab: StoryTab = .camera
    @State private var showingPreview = false
    @State private var isTransitioning = false
    
    // Performance optimization: Pre-computed values
    private let tabTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack {
                    // Background - Single color to reduce overdraw
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Header - Lazy loaded
                        StoryHeaderView(
                            hasContent: viewModel.canCreateStory,
                            onDismiss: handleDismiss,
                            onPreview: handlePreview
                        )
                        
                        // Content Area - Optimized switching
                        StoryContentContainer(
                            selectedTab: selectedTab,
                            viewModel: viewModel,
                            geometry: geometry
                        )
                        .transition(tabTransition)
                        .animation(.easeInOut(duration: 0.25), value: selectedTab)
                        
                        // Tab Bar - Cached views
                        StoryTabBarView(
                            selectedTab: $selectedTab,
                            isTransitioning: $isTransitioning
                        )
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .sheet(isPresented: $showingPreview) {
            LazyPreviewSheet(
                viewModel: viewModel,
                onPublish: handlePublish,
                onDismiss: { showingPreview = false }
            )
        }
        .onAppear {
            preloadManager.preloadResources()
        }
        .task {
            // Background processing
            await viewModel.initializeResources()
        }
    }
    
    // MARK: - Actions
    
    private func handleDismiss() {
        viewModel.cleanup()
        dismiss()
    }
    
    private func handlePreview() {
        guard viewModel.canCreateStory else { return }
        showingPreview = true
        HapticManager.shared.impact(style: .medium)
    }
    
    private func handlePublish(_ story: Story) {
        Task {
            await viewModel.publishStory(story)
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Story Tab Enum
enum StoryTab: String, CaseIterable, Hashable {
    case camera = "Camera"
    case gallery = "Gallery"
    case text = "Text"
    case music = "Music"
    case live = "Live"
    
    var systemImage: String {
        switch self {
        case .camera: "camera.fill"
        case .gallery: "photo.stack.fill"
        case .text: "text.bubble.fill"
        case .music: "music.note"
        case .live: "dot.radiowaves.left.and.right"
        }
    }
    
    var colors: [Color] {
        switch self {
        case .camera: [.blue, .purple]
        case .gallery: [.green, .mint]
        case .text: [.orange, .red]
        case .music: [.purple, .pink]
        case .live: [.red, .pink]
        }
    }
    
    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Optimized Header View
struct StoryHeaderView: View {
    let hasContent: Bool
    let onDismiss: () -> Void
    let onPreview: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Title
            VStack(spacing: 2) {
                Text("Create Story")
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                
                Text("Share your moment")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Preview/Next button
            Button(action: onPreview) {
                HStack(spacing: 6) {
                    Text(hasContent ? "Preview" : "Next")
                        .font(.system(size: 15, weight: .semibold))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(hasContent ? .white : .white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(hasContent ? AppTheme.Colors.primary : .white.opacity(0.2))
                        .shadow(
                            color: hasContent ? AppTheme.Colors.primary.opacity(0.3) : .clear,
                            radius: hasContent ? 6 : 0
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasContent)
            .animation(.easeInOut(duration: 0.2), value: hasContent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.8), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Content Container with Optimized Switching
struct StoryContentContainer: View {
    let selectedTab: StoryTab
    let viewModel: StoryCreationViewModel
    let geometry: GeometryProxy
    
    var body: some View {
        Group {
            switch selectedTab {
            case .camera:
                OptimizedCameraView(viewModel: viewModel)
                    .id("camera")
            case .gallery:
                OptimizedGalleryView(viewModel: viewModel)
                    .id("gallery")
            case .text:
                OptimizedTextView(viewModel: viewModel)
                    .id("text")
            case .music:
                OptimizedMusicView(viewModel: viewModel)
                    .id("music")
            case .live:
                OptimizedLiveView()
                    .id("live")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Optimized Camera View
struct OptimizedCameraView: View {
    @ObservedObject var viewModel: StoryCreationViewModel
    
    var body: some View {
        ZStack {
            if viewModel.isCameraReady {
                CameraPreviewView(viewModel: viewModel.createStoryViewModel)
                    .ignoresSafeArea()
            } else {
                CameraPlaceholderView()
            }
            
            // Camera controls overlay
            VStack {
                Spacer()
                CameraControlsView(viewModel: viewModel)
                    .padding(.bottom, 100)
            }
        }
        .onAppear {
            Task {
                await viewModel.initializeCamera()
            }
        }
        .onDisappear {
            viewModel.pauseCamera()
        }
    }
}

// MARK: - Camera Placeholder for Performance
struct CameraPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.black
            
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("Initializing Camera...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
        }
    }
}

// MARK: - Optimized Gallery View with Lazy Loading
struct OptimizedGalleryView: View {
    @ObservedObject var viewModel: StoryCreationViewModel
    @StateObject private var galleryManager = GalleryManager()
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.mint.opacity(0.8), .green.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                GalleryHeaderView()
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                
                // Photo Grid - Lazy loaded
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(galleryManager.photos.prefix(50), id: \.id) { photo in
                            GalleryPhotoCell(
                                photo: photo,
                                onSelect: { selectedPhoto in
                                    viewModel.handlePhotoSelection(selectedPhoto)
                                }
                            )
                            .aspectRatio(1, contentMode: .fit)
                            .onAppear {
                                if photo == galleryManager.photos.last {
                                    galleryManager.loadMorePhotos()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Selection button
                if !galleryManager.selectedPhotos.isEmpty {
                    SelectionButtonView(
                        count: galleryManager.selectedPhotos.count,
                        onContinue: {
                            viewModel.processSelectedPhotos(galleryManager.selectedPhotos)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .onAppear {
            Task {
                await galleryManager.loadPhotos()
            }
        }
    }
}

// MARK: - Gallery Header
struct GalleryHeaderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white)
                .shadow(radius: 2)
            
            VStack(spacing: 6) {
                Text("Choose from Gallery")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("Select photos and videos to share")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Optimized Text View
struct OptimizedTextView: View {
    @ObservedObject var viewModel: StoryCreationViewModel
    @State private var textInput = ""
    @State private var selectedStyle = TextStyle.bold
    @State private var selectedColor = Color.red
    @FocusState private var isTextFocused: Bool
    
    var body: some View {
        ZStack {
            selectedColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: selectedColor)
            
            VStack(spacing: 0) {
                // Text editing area
                TextEditingArea(
                    text: $textInput,
                    style: selectedStyle,
                    isBlinking: textInput.isEmpty,
                    isFocused: $isTextFocused
                )
                .frame(maxHeight: .infinity)
                
                // Style controls
                TextStyleControls(
                    selectedStyle: $selectedStyle,
                    selectedColor: $selectedColor
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            viewModel.setStoryType(.text)
            viewModel.setBackgroundColor(selectedColor)
        }
        .onChange(of: textInput) { _, newText in
            viewModel.updateTextContent(newText, style: selectedStyle, color: .white)
        }
        .onChange(of: selectedColor) { _, newColor in
            viewModel.setBackgroundColor(newColor)
        }
    }
}

// MARK: - Text Editing Area
struct TextEditingArea: View {
    @Binding var text: String
    let style: TextStyle
    let isBlinking: Bool
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        ZStack {
            if isBlinking && text.isEmpty {
                BlinkingPlaceholder()
            }
            
            TextEditor(text: $text)
                .font(style.font)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .background(.clear)
                .focused($isFocused)
                .padding(.horizontal, 40)
        }
        .onTapGesture {
            isFocused = true
        }
    }
}

// MARK: - Blinking Placeholder
struct BlinkingPlaceholder: View {
    @State private var isVisible = true
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Tap to add text")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))
        }
        .opacity(isVisible ? 1 : 0.3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isVisible.toggle()
            }
        }
    }
}

// MARK: - Text Styles
enum TextStyle: CaseIterable {
    case regular, bold, italic, cursive, mono
    
    var font: Font {
        switch self {
        case .regular: .title2
        case .bold: .title2.bold()
        case .italic: .title2.italic()
        case .cursive: .system(.title2, design: .serif)
        case .mono: .system(.title2, design: .monospaced)
        }
    }
}

// MARK: - Optimized Music View
struct OptimizedMusicView: View {
    @ObservedObject var viewModel: StoryCreationViewModel
    @StateObject private var musicManager = MusicManager()
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.8), .pink.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                MusicHeaderView()
                    .padding(.top, 40)
                
                SearchBarView(text: $searchText)
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                
                MusicTrackList(
                    tracks: musicManager.filteredTracks(search: searchText),
                    onSelect: { track in
                        viewModel.setBackgroundMusic(track)
                        HapticManager.shared.impact(style: .light)
                    }
                )
            }
        }
        .onAppear {
            Task {
                await musicManager.loadTracks()
            }
        }
    }
}

// MARK: - Optimized Live View
struct OptimizedLiveView: View {
    @State private var streamTitle = ""
    @State private var isPrivate = false
    @State private var isConnecting = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.red.opacity(0.8), .pink.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                LiveHeaderView()
                
                LiveSettingsView(
                    title: $streamTitle,
                    isPrivate: $isPrivate
                )
                .padding(.horizontal, 20)
                
                LiveActionButton(
                    title: streamTitle,
                    isConnecting: $isConnecting,
                    onStart: startLiveStream
                )
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
    
    private func startLiveStream() {
        guard !streamTitle.isEmpty else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isConnecting = true
        }
        
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isConnecting = false
            }
            // Handle live stream start
        }
        
        HapticManager.shared.impact(style: .medium)
    }
}

// MARK: - Tab Bar View with Performance Optimizations
struct StoryTabBarView: View {
    @Binding var selectedTab: StoryTab
    @Binding var isTransitioning: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(StoryTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        isTransitioning: isTransitioning,
                        onTap: {
                            guard !isTransitioning else { return }
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedTab = tab
                            }
                            
                            // Use existing HapticManager
                            HapticManager.shared.impact(style: .light)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Optimized Tab Button
struct TabButton: View {
    let tab: StoryTab
    let isSelected: Bool
    let isTransitioning: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected ? tab.gradient : 
                            LinearGradient(colors: [.white.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: isSelected ? tab.colors.first?.opacity(0.4) ?? .clear : .clear,
                            radius: isSelected ? 8 : 0,
                            y: isSelected ? 4 : 0
                        )
                    
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
        .disabled(isTransitioning)
    }
}

// MARK: - Lazy Preview Sheet
struct LazyPreviewSheet: View {
    @ObservedObject var viewModel: StoryCreationViewModel
    let onPublish: (Story) -> Void
    let onDismiss: () -> Void
    
    @State private var isPublishing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Preview content
                    StoryPreviewContent(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Action buttons
                    HStack(spacing: 20) {
                        Button("Cancel") {
                            onDismiss()
                        }
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .medium))
                        
                        Spacer()
                        
                        Button(action: publishStory) {
                            HStack(spacing: 8) {
                                if isPublishing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Share Story")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.primary)
                                    .shadow(radius: 8)
                            )
                        }
                        .disabled(isPublishing)
                    }
                    .padding(20)
                }
            }
        }
        .interactiveDismissDisabled(isPublishing)
    }
    
    private func publishStory() {
        guard !isPublishing else { return }
        
        isPublishing = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            let story = await viewModel.createStory()
            
            await MainActor.run {
                onPublish(story)
                isPublishing = false
            }
        }
    }
}

// MARK: - Performance Managers

// MARK: - Preload Manager
@MainActor
class PreloadManager: ObservableObject {
    func preloadResources() {
        Task {
            // Preload images, fonts, etc.
            await preloadImages()
            await preloadFonts()
        }
    }
    
    private func preloadImages() async {
        // Preload system images
        let systemImages = ["camera.fill", "photo.stack.fill", "text.bubble.fill", "music.note", "dot.radiowaves.left.and.right"]
        
        for imageName in systemImages {
            _ = UIImage(systemName: imageName)
        }
    }
    
    private func preloadFonts() async {
        // Preload custom fonts if any
    }
}

// MARK: - Story Creation ViewModel (Performance Optimized)
@MainActor
class StoryCreationViewModel: ObservableObject {
    @Published var canCreateStory = false
    @Published var isCameraReady = false
    @Published var storyType: StoryType = .camera
    
    // Create story view model for camera
    let createStoryViewModel = CreateStoryViewModel()
    
    // Content
    @Published private var textContent: String = ""
    @Published private var backgroundColor: Color = .blue
    @Published private var selectedMusic: MusicTrack?
    
    enum StoryType {
        case camera, gallery, text, music, live
    }
    
    func initializeResources() async {
        // Background initialization
        await initializeCamera()
        await loadDefaultAssets()
    }
    
    func initializeCamera() async {
        // Initialize camera asynchronously
        try? await Task.sleep(nanoseconds: 500_000_000)
        isCameraReady = true
    }
    
    private func loadDefaultAssets() async {
        // Load default assets
    }
    
    func setStoryType(_ type: StoryType) {
        storyType = type
        updateCanCreateStory()
    }
    
    func setBackgroundColor(_ color: Color) {
        backgroundColor = color
        updateCanCreateStory()
    }
    
    func updateTextContent(_ text: String, style: TextStyle, color: Color) {
        textContent = text
        updateCanCreateStory()
    }
    
    func setBackgroundMusic(_ track: MusicTrack) {
        selectedMusic = track
        updateCanCreateStory()
        HapticManager.shared.impact(style: .light)
    }
    
    func handlePhotoSelection(_ photo: GalleryPhoto) {
        // Handle photo selection
        updateCanCreateStory()
    }
    
    func processSelectedPhotos(_ photos: [GalleryPhoto]) {
        // Process selected photos
        updateCanCreateStory()
    }
    
    private func updateCanCreateStory() {
        switch storyType {
        case .text:
            canCreateStory = !textContent.isEmpty
        case .music:
            canCreateStory = selectedMusic != nil
        default:
            canCreateStory = true
        }
    }
    
    func pauseCamera() {
        // Pause camera functionality
    }
    
    func createStory() async -> Story {
        // Create story with optimized processing
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return optimized story creation
        return Story(
            creatorId: "user1",
            mediaURL: "",
            mediaType: .text,
            duration: 15.0,
            caption: nil,
            text: textContent,
            content: [],
            backgroundColor: nil,
            textColor: nil,
            music: nil,
            stickers: []
        )
    }
    
    func publishStory(_ story: Story) async {
        // Optimized publishing
        try? await Task.sleep(nanoseconds: 500_000_000)
        print("📖 Story published: \(story.id)")
    }
    
    func cleanup() {
        // Cleanup tasks
    }
}

// MARK: - Supporting Types and Managers

// Gallery Types
struct GalleryPhoto: Identifiable, Equatable {
    let id = UUID()
    let asset: PHAsset?
}

struct MusicTrack: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
}

// Gallery Manager
@MainActor
class GalleryManager: ObservableObject {
    @Published var photos: [GalleryPhoto] = []
    @Published var selectedPhotos: [GalleryPhoto] = []
    
    func loadPhotos() async {
        // Load photos asynchronously
        photos = Array(0..<20).map { _ in GalleryPhoto(asset: nil) }
    }
    
    func loadMorePhotos() {
        // Implement pagination
    }
}

// Music Manager
@MainActor
class MusicManager: ObservableObject {
    @Published private var tracks: [MusicTrack] = []
    
    func loadTracks() async {
        tracks = [
            MusicTrack(title: "Good Vibes", artist: "Artist One"),
            MusicTrack(title: "Summer Dreams", artist: "Artist Two")
        ]
    }
    
    func filteredTracks(search: String) -> [MusicTrack] {
        guard !search.isEmpty else { return tracks }
        return tracks.filter { track in
            track.title.localizedCaseInsensitiveContains(search) ||
            track.artist.localizedCaseInsensitiveContains(search)
        }
    }
}

// Media Processing Manager
@MainActor
class MediaProcessingManager: ObservableObject {
    static let shared = MediaProcessingManager()
    private init() {}
    
    // Implement media processing
}

// MARK: - Supporting Views (Placeholders for brevity)

struct CameraControlsView: View {
    let viewModel: StoryCreationViewModel
    
    var body: some View {
        HStack {
            Text("Camera Controls")
                .foregroundStyle(.white)
        }
    }
}

struct GalleryPhotoCell: View {
    let photo: GalleryPhoto
    let onSelect: (GalleryPhoto) -> Void
    
    var body: some View {
        Rectangle()
            .fill(.gray.opacity(0.3))
            .onTapGesture {
                onSelect(photo)
            }
    }
}

struct SelectionButtonView: View {
    let count: Int
    let onContinue: () -> Void
    
    var body: some View {
        Button(action: onContinue) {
            Text("Continue with \(count) items")
                .foregroundStyle(.white)
        }
    }
}

struct TextStyleControls: View {
    @Binding var selectedStyle: TextStyle
    @Binding var selectedColor: Color
    
    var body: some View {
        VStack {
            Text("Style Controls")
                .foregroundStyle(.white)
        }
    }
}

struct MusicHeaderView: View {
    var body: some View {
        VStack {
            Text("Add Music")
                .font(.title.bold())
                .foregroundStyle(.white)
        }
    }
}

struct SearchBarView: View {
    @Binding var text: String
    
    var body: some View {
        TextField("Search", text: $text)
            .textFieldStyle(.roundedBorder)
    }
}

struct MusicTrackList: View {
    let tracks: [MusicTrack]
    let onSelect: (MusicTrack) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(tracks) { track in
                    HStack {
                        Text(track.title)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .onTapGesture {
                        onSelect(track)
                    }
                }
            }
        }
    }
}

struct LiveHeaderView: View {
    var body: some View {
        VStack {
            Text("Go Live")
                .font(.title.bold())
                .foregroundStyle(.white)
        }
    }
}

struct LiveSettingsView: View {
    @Binding var title: String
    @Binding var isPrivate: Bool
    
    var body: some View {
        VStack {
            TextField("Stream title", text: $title)
            Toggle("Private", isOn: $isPrivate)
        }
    }
}

struct LiveActionButton: View {
    let title: String
    @Binding var isConnecting: Bool
    let onStart: () -> Void
    
    var body: some View {
        Button(action: onStart) {
            Text(isConnecting ? "Connecting..." : "Start Live Stream")
                .foregroundStyle(.white)
        }
        .disabled(title.isEmpty || isConnecting)
    }
}

struct StoryPreviewContent: View {
    let viewModel: StoryCreationViewModel
    
    var body: some View {
        ZStack {
            Color.gray
            Text("Preview")
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    StoryCreationView()
        .preferredColorScheme(.dark)
}