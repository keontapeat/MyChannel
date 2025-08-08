// 
//  StoryCreationView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct StoryCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storyCreator = StoryCreatorViewModel()
    @StateObject private var createStoryVM = CreateStoryViewModel()
    
    @State private var selectedTab: StoryCreationTab = .camera
    @State private var showingPhotoPicker = false
    @State private var showingPreview = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    
    enum StoryCreationTab: String, CaseIterable {
        case camera = "Camera"
        case gallery = "Gallery" 
        case text = "Text"
        case music = "Music"
        case live = "Live"
        
        var icon: String {
            switch self {
            case .camera: return "camera.fill"
            case .gallery: return "photo.stack.fill"
            case .text: return "text.bubble.fill"
            case .music: return "music.note"
            case .live: return "dot.radiowaves.left.and.right"
            }
        }
        
        var gradientColors: [Color] {
            switch self {
            case .camera: return [.blue, .purple]
            case .gallery: return [.green, .mint]
            case .text: return [.orange, .red]
            case .music: return [.purple, .pink]
            case .live: return [.red, .pink]
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Professional Header
                    ProfessionalStoryHeader(
                        onDismiss: {
                            dismiss()
                        },
                        onPreview: {
                            showingPreview = true
                        },
                        hasContent: createStoryVM.canPost
                    )
                    
                    // Main Content Area
                    ZStack {
                        switch selectedTab {
                        case .camera:
                            CameraPreviewView(viewModel: createStoryVM)
                                .ignoresSafeArea()
                            
                        case .gallery:
                            StoryGalleryView(
                                selectedPhotos: $selectedPhotos,
                                onPhotosSelected: { photos in
                                    handlePhotosSelected(photos)
                                }
                            )
                            
                        case .text:
                            StoryTextEditorView(
                                createStoryVM: createStoryVM
                            )
                            
                        case .music:
                            StoryMusicPickerView(
                                createStoryVM: createStoryVM
                            )
                            
                        case .live:
                            StoryLiveSetupView(
                                onStartLive: {
                                    // Handle live stream start
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Professional Tab Bar
                    ProfessionalStoryTabBar(
                        selectedTab: $selectedTab,
                        tabs: StoryCreationTab.allCases
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .sheet(isPresented: $showingPreview) {
            if createStoryVM.canPost {
                StoryCreationPreviewView(
                    createStoryVM: createStoryVM,
                    onPublish: { story in
                        publishStory(story)
                        dismiss()
                    },
                    onDismiss: {
                        showingPreview = false
                    }
                )
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handlePhotosSelected(_ photos: [PhotosPickerItem]) {
        // Process selected photos
        for photo in photos.prefix(1) { // Only take first photo for now
            photo.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            // Create mock URL for the image
                            if let url = saveImageToTempFile(image) {
                                let mediaItem = CreateStoryViewModel.MediaItem(
                                    url: url,
                                    type: .image,
                                    duration: nil
                                )
                                createStoryVM.setMedia(mediaItem)
                            }
                        }
                    }
                case .failure:
                    break
                }
            }
        }
    }
    
    private func saveImageToTempFile(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        try? data.write(to: tempURL)
        return tempURL
    }
    
    private func publishStory(_ story: Story) {
        print("📖 Publishing story: \(story.id)")
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Professional Story Header
struct ProfessionalStoryHeader: View {
    let onDismiss: () -> Void
    let onPreview: () -> Void
    let hasContent: Bool
    
    var body: some View {
        HStack(spacing: 20) {
            // Close Button
            Button(action: onDismiss) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.6))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Title
            VStack(spacing: 2) {
                Text("Create Story")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Share your moment")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Preview/Next Button
            Button(action: onPreview) {
                HStack(spacing: 6) {
                    Text(hasContent ? "Preview" : "Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(hasContent ? .white : .white.opacity(0.5))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(hasContent ? .white : .white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(hasContent ? AppTheme.Colors.primary : .white.opacity(0.2))
                        .shadow(
                            color: hasContent ? AppTheme.Colors.primary.opacity(0.3) : .clear,
                            radius: hasContent ? 8 : 0,
                            x: 0,
                            y: 2
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!hasContent)
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

// MARK: - Story Gallery View
struct StoryGalleryView: View {
    @Binding var selectedPhotos: [PhotosPickerItem]
    let onPhotosSelected: ([PhotosPickerItem]) -> Void
    
    @State private var showingPhotoPicker = false
    @State private var loadedImages: [UIImage] = []
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.mint.opacity(0.8), .green.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                    
                    VStack(spacing: 8) {
                        Text("Choose from Gallery")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Select photos and videos to share")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Gallery Grid Preview
                if !loadedImages.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(Array(loadedImages.prefix(6).enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: { showingPhotoPicker = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            
                            Text("Select Photos & Videos")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if !selectedPhotos.isEmpty {
                        Text("Selected \(selectedPhotos.count) item\(selectedPhotos.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.top, 40)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 10,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedPhotos) { _, newPhotos in
            loadSelectedImages(from: newPhotos)
            onPhotosSelected(newPhotos)
        }
    }
    
    private func loadSelectedImages(from items: [PhotosPickerItem]) {
        loadedImages.removeAll()
        
        for item in items.prefix(6) {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            loadedImages.append(image)
                        }
                    }
                case .failure:
                    break
                }
            }
        }
    }
}

// MARK: - Story Text Editor View
struct StoryTextEditorView: View {
    @ObservedObject var createStoryVM: CreateStoryViewModel
    @State private var text: String = ""
    @State private var selectedBackgroundColor: Color = .red
    @State private var selectedTextColor: Color = .white
    @State private var selectedFont: CreateStoryViewModel.TextOverlay.FontStyle = .bold
    @State private var textAlignment: TextAlignment = .center
    @FocusState private var isTextFieldFocused: Bool
    
    private let backgroundColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown,
        .black, .gray
    ]
    
    var body: some View {
        ZStack {
            // Background Color
            selectedBackgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Text Input Area
                ZStack {
                    if text.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Tap to add text")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    TextEditor(text: $text)
                        .font(selectedFont.font)
                        .foregroundColor(selectedTextColor)
                        .multilineTextAlignment(textAlignment)
                        .background(Color.clear)
                        .focused($isTextFieldFocused)
                        .padding(.horizontal, 40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: text) { _, newText in
                            updateTextOverlay()
                        }
                }
                .frame(maxHeight: .infinity)
                .onTapGesture {
                    isTextFieldFocused = true
                }
                
                // Controls
                VStack(spacing: 20) {
                    // Font Selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(CreateStoryViewModel.TextOverlay.FontStyle.allCases, id: \.self) { font in
                                Button(action: {
                                    selectedFont = font
                                    updateTextOverlay()
                                }) {
                                    Text("Aa")
                                        .font(font.font)
                                        .foregroundColor(selectedFont == font ? selectedBackgroundColor : .white)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(selectedFont == font ? .white : .white.opacity(0.2))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Color Selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(backgroundColors, id: \.self) { color in
                                Button(action: {
                                    selectedBackgroundColor = color
                                    updateTextOverlay()
                                }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(.white, lineWidth: selectedBackgroundColor == color ? 3 : 0)
                                        )
                                        .shadow(radius: selectedBackgroundColor == color ? 4 : 0)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            createStoryVM.storyType = .text
            createStoryVM.backgroundGradient = [selectedBackgroundColor]
            updateTextOverlay()
        }
    }
    
    private func updateTextOverlay() {
        let textOverlay = CreateStoryViewModel.TextOverlay(
            text: text,
            color: selectedTextColor,
            backgroundColor: selectedBackgroundColor.opacity(0.3),
            fontStyle: selectedFont
        )
        createStoryVM.addTextOverlay(textOverlay)
    }
}

// MARK: - Story Music Picker View
struct StoryMusicPickerView: View {
    @ObservedObject var createStoryVM: CreateStoryViewModel
    @State private var searchText: String = ""
    @State private var selectedMusic: CreateStoryViewModel.MusicItem?
    @State private var isPlaying: Bool = false
    
    private let popularTracks = [
        CreateStoryViewModel.MusicItem(
            title: "Good Vibes", 
            artist: "Artist One", 
            previewURL: "https://sample.com/track1.mp3",
            artworkURL: "https://picsum.photos/300/300?random=1"
        ),
        CreateStoryViewModel.MusicItem(
            title: "Summer Dreams", 
            artist: "Artist Two", 
            previewURL: "https://sample.com/track2.mp3",
            artworkURL: "https://picsum.photos/300/300?random=2"
        ),
        CreateStoryViewModel.MusicItem(
            title: "Night Life", 
            artist: "Artist Three", 
            previewURL: "https://sample.com/track3.mp3",
            artworkURL: "https://picsum.photos/300/300?random=3"
        ),
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.8), .pink.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                    
                    VStack(spacing: 8) {
                        Text("Add Music")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Make your story more engaging")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.top, 40)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("Search music...", text: $searchText)
                        .foregroundColor(.white)
                        .placeholder(when: searchText.isEmpty) {
                            Text("Search music...")
                                .foregroundColor(.white.opacity(0.6))
                        }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.top, 30)
                
                // Music List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Text("Popular Tracks")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        ForEach(popularTracks, id: \.id) { track in
                            MusicTrackRowView(
                                track: track,
                                isSelected: selectedMusic?.id == track.id,
                                isPlaying: isPlaying && selectedMusic?.id == track.id,
                                onSelect: {
                                    selectedMusic = track
                                    createStoryVM.setBackgroundMusic(track)
                                },
                                onPlayPause: {
                                    if selectedMusic?.id == track.id {
                                        isPlaying.toggle()
                                    } else {
                                        selectedMusic = track
                                        isPlaying = true
                                    }
                                }
                            )
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Music Track Row
struct MusicTrackRowView: View {
    let track: CreateStoryViewModel.MusicItem
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPlayPause: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Play/Pause Button
            Button(action: onPlayPause) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Track Info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Select Button
            Button(action: onSelect) {
                Text(isSelected ? "Selected" : "Select")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .purple : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isSelected ? .white : .white.opacity(0.2))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? .white.opacity(0.1) : .clear)
        )
    }
}

// MARK: - Story Live Setup View
struct StoryLiveSetupView: View {
    let onStartLive: () -> Void
    
    @State private var liveTitle: String = ""
    @State private var isPrivate: Bool = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.red.opacity(0.8), .pink.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Go Live")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Share what's happening right now")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                
                VStack(spacing: 20) {
                    // Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stream Title")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("What's happening?", text: $liveTitle)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    
                    // Privacy Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Private Stream")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Only your followers can see this stream")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isPrivate)
                            .toggleStyle(SwitchToggleStyle(tint: .white))
                    }
                    
                    // Start Live Button
                    Button(action: onStartLive) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                                .scaleEffect(1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                            
                            Text("Start Live Stream")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                                .shadow(radius: 8)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(liveTitle.isEmpty)
                    .opacity(liveTitle.isEmpty ? 0.6 : 1.0)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
}

// MARK: - Professional Story Tab Bar
struct ProfessionalStoryTabBar: View {
    @Binding var selectedTab: StoryCreationView.StoryCreationTab
    let tabs: [StoryCreationView.StoryCreationTab]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(tabs, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        selectedTab == tab ?
                                        LinearGradient(colors: tab.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [.white.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .frame(width: 60, height: 60)
                                    .shadow(
                                        color: selectedTab == tab ? tab.gradientColors.first?.opacity(0.4) ?? .clear : .clear,
                                        radius: selectedTab == tab ? 8 : 0,
                                        x: 0,
                                        y: 4
                                    )
                                
                                Image(systemName: tab.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedTab)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.7))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
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

// MARK: - Story Creation Preview View
struct StoryCreationPreviewView: View {
    @ObservedObject var createStoryVM: CreateStoryViewModel
    let onPublish: (Story) -> Void
    let onDismiss: () -> Void
    
    @State private var isPublishing: Bool = false
    @State private var storyCaption: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    // Preview Content
                    ZStack {
                        switch createStoryVM.storyType {
                        case .photo:
                            if let media = createStoryVM.selectedMedia {
                                AsyncImage(url: media.url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.gray
                                }
                                .clipped()
                            }
                            
                        case .text:
                            createStoryVM.backgroundGradient.first ?? .blue
                            
                            if let textOverlay = createStoryVM.textOverlay {
                                Text(textOverlay.text)
                                    .font(textOverlay.fontStyle.font)
                                    .foregroundColor(textOverlay.color)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            
                        default:
                            Color.gray
                                .overlay(
                                    Text("Story Preview")
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Controls
                    HStack {
                        Button("Cancel") {
                            onDismiss()
                        }
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button("Share Story") {
                            publishStory()
                        }
                        .foregroundColor(AppTheme.Colors.primary)
                        .disabled(isPublishing)
                    }
                    .padding()
                }
            }
        }
    }
    
    private func publishStory() {
        isPublishing = true
        
        Task {
            let story = await createStoryVM.createStory()
            
            await MainActor.run {
                onPublish(story)
                isPublishing = false
            }
        }
    }
}

// MARK: - Supporting Extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview
struct StoryCreationView_Previews: PreviewProvider {
    static var previews: some View {
        StoryCreationView()
            .preferredColorScheme(.dark)
    }
}