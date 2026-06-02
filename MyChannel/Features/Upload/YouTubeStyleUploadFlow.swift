//
//  YouTubeStyleUploadFlow.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import SwiftUI
import PhotosUI
import AVFoundation
import Photos

// 🎬 YouTube-Professional Upload Flow
// Billion-dollar UI design with enterprise backend
struct YouTubeStyleUploadFlow: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var uploadManager = VideoUploadManager()
    @State private var currentStep: UploadStep = .contentSelection
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var videoThumbnail: UIImage?
    @State private var videoDuration: TimeInterval = 0
    @State private var videoFileSize: Int64 = 0
    @State private var isProcessingVideo = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    
    // Video details
    @State private var videoTitle = ""
    @State private var videoDescription = ""
    // 🔥 YOUTUBE PARITY: Default to Public so uploads appear on the home feed immediately.
    @State private var selectedVisibility: VideoVisibility = .publicVideo
    @State private var selectedCategory = "Entertainment"
    @State private var videoTags: [String] = []
    @State private var newTag = ""
    @State private var thumbnailTime: Double = 0
    @State private var customThumbnail: UIImage?
    @State private var selectedThumbnailIndex = 0
    @State private var generatedThumbnails: [UIImage] = []
    
    // AI & A/B Testing
    @State private var isGeneratingMetadata = false
    @State private var isABTestingEnabled = false
    @State private var videoThumbnailB: UIImage?
    @State private var selectedThumbnailIndexB: Int?
    
    // Photos library recent videos
    @State private var recentVideos: [RecentVideo] = []
    @State private var isLoadingVideos = true
    @State private var showUploadError = false
    @State private var uploadErrorMessage = ""
    
    // Creation mode (bottom tab bar on contentSelection)
    @State private var selectedCreateMode: CreateContentMode = .video
    @State private var showLiveSetup = false
    @State private var showPostComposer = false
    
    private let categories = [
        "Entertainment", "Music", "Gaming", "Sports", "News", "Education",
        "Technology", "Lifestyle", "Comedy", "Travel", "Food", "Fashion"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Professional Header
                professionalHeader
                
                // Progress Indicator
                progressIndicator
                
                // Content based on current step
                Group {
                    switch currentStep {
                    case .contentSelection:
                        contentSelectionView
                    case .videoPreview:
                        videoPreviewView
                    case .videoDetails:
                        videoDetailsView
                    case .thumbnailSelection:
                        thumbnailSelectionView
                    case .publishing:
                        publishingView
                    case .completed:
                        completedView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if currentStep == .contentSelection {
                    createModeBar
                        .background(Color(.systemBackground))
                } else {
                    bottomActionBar
                        .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedVideo,
            matching: .videos
        )
        .sheet(isPresented: $showingCamera) {
            CameraRecorderView { url in
                videoURL = url
                processSelectedVideo()
            }
        }
        .fullScreenCover(isPresented: $showLiveSetup) {
            GoLiveSetupView(onClose: { showLiveSetup = false }, onStart: { _ in
                showLiveSetup = false
            })
        }
        .fullScreenCover(isPresented: $showPostComposer) {
            NavigationStack {
                CreateCommunityPostView(creator: appState.currentUser ?? User.defaultUser)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showPostComposer = false }
                        }
                    }
            }
        }
        .onChange(of: selectedVideo) { _ in
            if selectedVideo != nil {
                loadSelectedVideo()
            }
        }
    }
    
    // MARK: - Professional Header
    
    private var professionalHeader: some View {
        HStack(spacing: 12) {
            Button(action: handleBackAction) {
                Image(systemName: currentStep == .contentSelection ? "xmark" : "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            
            Text(currentStep.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
            
            if currentStep.canSkip {
                Button("Skip") {
                    nextStep()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color.red.opacity(0.08))
                .clipShape(Capsule())
            } else {
                Color.clear.frame(width: 56, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Progress Indicator
    
    @ViewBuilder
    private var progressIndicator: some View {
        if currentStep != .contentSelection {
            HStack(spacing: 8) {
                ForEach(Array(UploadStep.allCases.enumerated()), id: \.offset) { index, _ in
                    Capsule()
                        .fill(index <= currentStep.rawValue ? Color.red : Color(.systemGray5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }
    
    // MARK: - Content Selection View
    
    private var contentSelectionView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Button(action: { showingPhotoPicker = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Browse")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Color.red)
                        .clipShape(Capsule())
                    }
                    
                    Button(action: { showingCamera = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Record")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    if !recentVideos.isEmpty {
                        Text("\(recentVideos.count) videos")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent uploads")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Pick a video from your library or record a new one.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !recentVideos.isEmpty {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Ready")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.red)
                            Text("Fast select")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 12)
            
            if isLoadingVideos {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading videos...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if recentVideos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.4))
                    
                    Text("No Videos Found")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Tap Browse or Record to get started")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2),
                        GridItem(.flexible(), spacing: 2)
                    ], spacing: 2) {
                        ForEach(recentVideos) { video in
                            RecentVideoCell(video: video)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectRecentVideo(video)
                                }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .onAppear { loadRecentVideos() }
    }
    
    // MARK: - Video Preview View
    
    private var videoPreviewView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text("Preview")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.black)
                            .aspectRatio(16/9, contentMode: .fit)
                        
                        if let thumbnail = videoThumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        
                        Circle()
                            .fill(Color.black.opacity(0.58))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .offset(x: 2)
                            )
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text(formatDuration(videoDuration))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Capsule())
                            .padding(12)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Thumbnail Time")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatTime(thumbnailTime))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $thumbnailTime, in: 0...videoDuration) { _ in
                        generateThumbnailAtTime(thumbnailTime)
                    }
                    .accentColor(.red)
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                
                HStack(spacing: 12) {
                    if let thumbnail = videoThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(formatDuration(videoDuration))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Ready to edit and publish")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("Landscape preview · optimized for upload")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                
                HStack(spacing: 12) {
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle")
                                .font(.system(size: 18))
                            Text("Preview")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 23))
                    }
                    
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 17))
                            Text("1080p")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 23))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - Video Details View
    
    private var videoDetailsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let thumbnail = videoThumbnail {
                    HStack(spacing: 12) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 112, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(videoTitle.isEmpty ? "Untitled video" : videoTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            Text("\(formatDuration(videoDuration)) · \(selectedCategory)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(selectedVisibility.rawValue.capitalized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Title")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: generateAIMetadata) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Generate with AI")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Capsule())
                        }
                        .disabled(isGeneratingMetadata)
                    }
                    
                    TextField("Add a title that describes your video", text: $videoTitle)
                        .font(.system(size: 16))
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField("Tell viewers about your video", text: $videoDescription, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(4...8)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visibility")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(VideoVisibility.allCases, id: \.self) { visibility in
                            VisibilityOptionCard(
                                visibility: visibility,
                                isSelected: selectedVisibility == visibility
                            ) {
                                selectedVisibility = visibility
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Menu {
                        ForEach(categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedCategory)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("Add tags", text: $newTag)
                            .font(.system(size: 16))
                            .onSubmit {
                                addTag()
                            }
                        
                        Button("Add") {
                            addTag()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .disabled(newTag.isEmpty)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if !videoTags.isEmpty {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(videoTags, id: \.self) { tag in
                                UploadFlowTagChip(tag: tag) {
                                    videoTags.removeAll { $0 == tag }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
    }
    
    // MARK: - Thumbnail Selection View
    
    private var thumbnailSelectionView: some View {
        VStack(spacing: 24) {
            Text("Choose Thumbnail")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // A/B Testing Toggle
            Toggle(isOn: $isABTestingEnabled.animation()) {
                VStack(alignment: .leading) {
                    Text("Test and Compare (A/B Test)")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Upload up to 3 thumbnails and we'll automatically select the winning one based on CTR.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .tint(.purple)
            .padding(.bottom, 8)
            
            // Thumbnail A
            Text(isABTestingEnabled ? "Thumbnail A" : "Primary Thumbnail")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Generated Thumbnails
            if !generatedThumbnails.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(Array(generatedThumbnails.enumerated()), id: \.offset) { index, thumbnail in
                        Button(action: {
                            selectedThumbnailIndex = index
                            videoThumbnail = thumbnail
                        }) {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedThumbnailIndex == index ? Color.red : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                        }
                    }
                }
            }
            
            if isABTestingEnabled {
                Text("Thumbnail B (Challenger)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
                
                if !generatedThumbnails.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(Array(generatedThumbnails.enumerated()), id: \.offset) { index, thumbnail in
                            Button(action: {
                                selectedThumbnailIndexB = index
                                videoThumbnailB = thumbnail
                            }) {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                selectedThumbnailIndexB == index ? Color.purple : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                                    .opacity(selectedThumbnailIndex == index ? 0.3 : 1.0)
                            }
                            .disabled(selectedThumbnailIndex == index)
                        }
                    }
                }
            }
            
            // Custom Thumbnail Upload
            Button(action: {
                // Upload custom thumbnail
            }) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(isABTestingEnabled ? .purple : .red)
                    
                    Text("Upload Custom Thumbnail")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isABTestingEnabled ? .purple : .red)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background((isABTestingEnabled ? Color.purple : Color.red).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .onAppear {
            generateThumbnails()
        }
    }
    
    // MARK: - Publishing View
    
    private var publishingView: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 60)
            
            // Upload Progress
            VStack(spacing: 24) {
                // Animated upload icon
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.2), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: uploadManager.uploadProgress)
                        .stroke(Color.red, lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: uploadManager.uploadProgress)
                    
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                }
                
                VStack(spacing: 8) {
                    Text("Publishing Your Video")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(uploadManager.isUploading ? "Uploading..." : (uploadManager.uploadError != nil ? "Failed" : "Processing"))
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(uploadManager.uploadProgress * 100))% complete")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Cancel button
            Button("Cancel Upload") {
                uploadManager.cancelUpload()
                currentStep = .videoDetails
            }
            .font(.system(size: 16))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .onAppear {
            startUpload()
        }
        .alert("Upload Failed", isPresented: $showUploadError) {
            Button("Try Again") {
                currentStep = .publishing
            }
            Button("Edit Details") {
                currentStep = .videoDetails
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(uploadErrorMessage)
        }
    }
    
    // MARK: - Completed View
    
    private var completedView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                // Success animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                }
                
                VStack(spacing: 12) {
                    Text("Video Published!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Your video is now live and ready to be discovered")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button("View Video") {
                    if let video = uploadManager.uploadedVideo {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToVideo"),
                            object: video
                        )
                    }
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 26))
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Create Mode Bar (contentSelection bottom tab)
    
    private var createModeBar: some View {
        HStack(spacing: 0) {
            ForEach(CreateContentMode.allCases, id: \.self) { mode in
                Button {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedCreateMode = mode
                    }
                    switch mode {
                    case .video, .flicks:
                        break
                    case .live:
                        showLiveSetup = true
                    case .post:
                        showPostComposer = true
                    }
                } label: {
                    if selectedCreateMode == mode {
                        Text(mode.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.primary))
                    } else {
                        Text(mode.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                    }
                }
                .buttonStyle(.plain)
                if mode != CreateContentMode.allCases.last {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
    
    // MARK: - Bottom Action Bar
    
    @ViewBuilder
    private var bottomActionBar: some View {
        if currentStep != .contentSelection && currentStep != .completed && currentStep != .publishing {
            VStack(spacing: 12) {
                if currentStep == .videoDetails {
                    HStack {
                        Text(videoTitle.isEmpty ? "Add a title to continue" : "Looks good — you can publish next")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                Button(action: nextStep) {
                    HStack(spacing: 8) {
                        Text(currentStep.nextButtonTitle)
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 26)
                            .fill(canProceed ? Color.red : Color.gray.opacity(0.35))
                    )
                    .shadow(color: canProceed ? Color.red.opacity(0.18) : .clear, radius: 14, x: 0, y: 8)
                }
                .disabled(!canProceed)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.thinMaterial)
        }
    }
    
    // MARK: - Helper Methods
    
    private var canProceed: Bool {
        switch currentStep {
        case .contentSelection:
            return videoURL != nil
        case .videoPreview:
            return true
        case .videoDetails:
            return !videoTitle.isEmpty
        case .thumbnailSelection:
            return videoThumbnail != nil
        case .publishing, .completed:
            return false
        }
    }
    
    private func handleBackAction() {
        if currentStep == .contentSelection {
            dismiss()
        } else {
            previousStep()
        }
    }
    
    private func nextStep() {
        guard canProceed else { return }
        
        // If we're moving from thumbnail selection to publishing, start the upload
        if currentStep == .thumbnailSelection {
            currentStep = .publishing
            startUpload()
            return
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            if let nextStep = UploadStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
            }
        }
    }
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let previousStep = UploadStep(rawValue: currentStep.rawValue - 1) {
                currentStep = previousStep
            }
        }
    }
    
    private func loadSelectedVideo() {
        guard let selectedVideo = selectedVideo else { return }
        
        isProcessingVideo = true
        
        Task {
            do {
                if let data = try await selectedVideo.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("mp4")
                    
                    try data.write(to: tempURL)
                    
                    await MainActor.run {
                        self.videoURL = tempURL
                        self.processSelectedVideo()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessingVideo = false
                }
            }
        }
    }
    
    private func processSelectedVideo() {
        guard let videoURL = videoURL else { return }
        
        Task {
            do {
                let asset = AVAsset(url: videoURL)
                
                // Get duration
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                // Get file size
                let fileSize = try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int64 ?? 0
                
                // Generate initial thumbnail
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let time = CMTime(seconds: min(2.0, durationSeconds / 2), preferredTimescale: 600)
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                
                await MainActor.run {
                    self.videoDuration = durationSeconds
                    self.videoFileSize = fileSize
                    self.videoThumbnail = thumbnail
                    self.thumbnailTime = min(2.0, durationSeconds / 2)
                    self.isProcessingVideo = false
                    
                    // Auto-advance to next step
                    self.nextStep()
                }
                
            } catch {
                await MainActor.run {
                    self.isProcessingVideo = false
                }
            }
        }
    }
    
    private func generateThumbnailAtTime(_ time: TimeInterval) {
        guard let videoURL = videoURL else { return }
        
        Task {
            do {
                let asset = AVAsset(url: videoURL)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                
                let cmTime = CMTime(seconds: time, preferredTimescale: 600)
                let cgImage = try imageGenerator.copyCGImage(at: cmTime, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                
                await MainActor.run {
                    self.videoThumbnail = thumbnail
                }
            } catch {
                print("Failed to generate thumbnail: \(error)")
            }
        }
    }
    
    private func generateThumbnails() {
        guard let videoURL = videoURL else { return }
        
        Task {
            let asset = AVAsset(url: videoURL)
            let timeRatios = [0.1, 0.25, 0.4, 0.55, 0.7, 0.85]
            let capturedDuration = videoDuration
            
            // Generate all 6 thumbnails in parallel — each task uses its own generator instance
            let thumbnails: [UIImage] = await withTaskGroup(of: (Int, UIImage?).self) { group in
                for (i, ratio) in timeRatios.enumerated() {
                    group.addTask {
                        let gen = AVAssetImageGenerator(asset: asset)
                        gen.appliesPreferredTrackTransform = true
                        let t = CMTime(seconds: capturedDuration * ratio, preferredTimescale: 600)
                        let img = (try? gen.copyCGImage(at: t, actualTime: nil)).map(UIImage.init)
                        return (i, img)
                    }
                }
                var pairs: [(Int, UIImage?)] = []
                for await pair in group { pairs.append(pair) }
                return pairs.sorted { $0.0 < $1.0 }.compactMap { $0.1 }
            }
            
            await MainActor.run {
                self.generatedThumbnails = thumbnails
                if let first = thumbnails.first {
                    self.videoThumbnail = first
                    self.selectedThumbnailIndex = 0
                }
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !videoTags.contains(trimmedTag) && videoTags.count < 10 {
            videoTags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func startUpload() {
        guard let videoURL = videoURL else { return }
        
        // Configure VideoUploadManager with the details from the flow
        uploadManager.videoURL = videoURL
        uploadManager.title = videoTitle
        uploadManager.description = videoDescription
        uploadManager.selectedTags = Set(videoTags)
        uploadManager.isPublic = selectedVisibility == .publicVideo
        uploadManager.isUnlisted = selectedVisibility == .unlisted
        uploadManager.thumbnail = videoThumbnail
        uploadManager.videoDuration = videoDuration
        
        // Map category string to VideoCategory
        if let category = VideoCategory(rawValue: selectedCategory.lowercased()) {
            uploadManager.selectedCategory = category
        }
        
        Task { @MainActor in
            print("🎬 Starting upload with VideoUploadManager")
            await uploadManager.uploadVideo()
            
            // uploadVideo() internally calls resetForm() which clears some state,
            // but uploadedVideo remains set on success, and uploadError on failure.
            if uploadManager.uploadedVideo != nil {
                print("✅ Upload completed and video posted successfully")
                self.currentStep = .completed
            } else if let error = uploadManager.uploadError {
                print("🚨 Upload failed: \(error)")
                self.uploadErrorMessage = error
                self.showUploadError = true
                self.currentStep = .videoDetails
            } else {
                // No error and no uploadedVideo means success (resetForm may have cleared it)
                print("✅ Upload completed successfully")
                self.currentStep = .completed
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Photos Library Integration
    
    private func loadRecentVideos() {
        isLoadingVideos = true
        
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard status == .authorized || status == .limited else {
                await MainActor.run {
                    isLoadingVideos = false
                }
                return
            }
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 30
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            
            let assets = PHAsset.fetchAssets(with: fetchOptions)
            var videos: [RecentVideo] = []
            let imageManager = PHCachingImageManager()
            let thumbSize = CGSize(width: 300, height: 300)
            let thumbOptions = PHImageRequestOptions()
            thumbOptions.deliveryMode = .opportunistic
            thumbOptions.isSynchronous = false
            thumbOptions.resizeMode = .fast
            
            for i in 0..<assets.count {
                let asset = assets.object(at: i)
                let thumbnail: UIImage? = await withCheckedContinuation { continuation in
                    imageManager.requestImage(
                        for: asset,
                        targetSize: thumbSize,
                        contentMode: .aspectFill,
                        options: thumbOptions
                    ) { image, info in
                        let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                        if !isDegraded {
                            continuation.resume(returning: image)
                        }
                    }
                }
                
                let video = RecentVideo(
                    id: asset.localIdentifier,
                    asset: asset,
                    thumbnail: thumbnail,
                    duration: asset.duration,
                    creationDate: asset.creationDate ?? Date()
                )
                videos.append(video)
            }
            
            await MainActor.run {
                self.recentVideos = videos
                self.isLoadingVideos = false
            }
        }
    }
    
    private func selectRecentVideo(_ video: RecentVideo) {
        isProcessingVideo = true
        
        Task {
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            let imageManager = PHImageManager.default()
            
            let url: URL? = await withCheckedContinuation { continuation in
                imageManager.requestAVAsset(forVideo: video.asset, options: options) { avAsset, _, _ in
                    if let urlAsset = avAsset as? AVURLAsset {
                        // Copy to temp so it's accessible outside Photos sandbox
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("mp4")
                        do {
                            try FileManager.default.copyItem(at: urlAsset.url, to: tempURL)
                            continuation.resume(returning: tempURL)
                        } catch {
                            continuation.resume(returning: nil)
                        }
                    } else if let composition = avAsset as? AVComposition {
                        // Slo-mo or edited video — export it
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("mp4")
                        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                            continuation.resume(returning: nil)
                            return
                        }
                        session.outputURL = tempURL
                        session.outputFileType = .mp4
                        session.exportAsynchronously {
                            if session.status == .completed {
                                continuation.resume(returning: tempURL)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            
            await MainActor.run {
                if let url = url {
                    self.videoURL = url
                    self.videoThumbnail = video.thumbnail
                    self.videoDuration = video.duration
                    self.isProcessingVideo = false
                    self.nextStep()
                } else {
                    self.isProcessingVideo = false
                    // Fallback to system picker
                    self.showingPhotoPicker = true
                }
            }
        }
    }
    
    // MARK: - AI Generation
    private func generateAIMetadata() {
        isGeneratingMetadata = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            // Mock AI processing delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                self.videoTitle = "🔥 Incredible Day in the Life | Behind the Scenes"
                self.videoDescription = "Join me as I show you exactly how my days go! Don't forget to like and subscribe if you enjoy the behind the scenes look!\n\n#vlog #dayinthelife #creator"
                self.videoTags = ["vlog", "dayinthelife", "creator", "behindthescenes"]
                self.isGeneratingMetadata = false
                HapticManager.shared.notification(type: .success)
            }
        }
    }
}


// ⚡ Supporting types + components extracted to UploadFlowComponents.swift
