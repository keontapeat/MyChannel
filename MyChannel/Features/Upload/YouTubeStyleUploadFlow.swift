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
    @State private var selectedVisibility: VideoVisibility = .privateVideo
    @State private var selectedCategory = "Entertainment"
    @State private var videoTags: [String] = []
    @State private var newTag = ""
    @State private var thumbnailTime: Double = 0
    @State private var customThumbnail: UIImage?
    @State private var selectedThumbnailIndex = 0
    @State private var generatedThumbnails: [UIImage] = []
    
    // Photos library recent videos
    @State private var recentVideos: [RecentVideo] = []
    @State private var isLoadingVideos = true
    
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Action Bar
                bottomActionBar
            }
            .background(Color(.systemBackground).ignoresSafeArea())
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
        .onChange(of: selectedVideo) { _ in
            if selectedVideo != nil {
                loadSelectedVideo()
            }
        }
    }
    
    // MARK: - Professional Header
    
    private var professionalHeader: some View {
        HStack {
            // Cancel/Back Button
            Button(action: handleBackAction) {
                HStack(spacing: 6) {
                    Image(systemName: currentStep == .contentSelection ? "xmark" : "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    
                    if currentStep != .contentSelection {
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(.red)
            }
            
            Spacer()
            
            // Title
            VStack(spacing: 2) {
                Text(currentStep.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                if currentStep != .contentSelection && currentStep != .completed {
                    Text(currentStep.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Skip/Next Button
            if currentStep.canSkip {
                Button("Skip") {
                    nextStep()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.red)
            } else {
                Color.clear.frame(width: 50)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 0) {
            ForEach(Array(UploadStep.allCases.enumerated()), id: \.offset) { index, step in
                Rectangle()
                    .frame(height: 3)
                    .foregroundColor(
                        index <= currentStep.rawValue ? .red : .gray.opacity(0.3)
                    )
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - Content Selection View
    
    private var contentSelectionView: some View {
        VStack(spacing: 0) {
            // Sleek action row — compact pills like YouTube
            HStack(spacing: 8) {
                Button(action: { showingPhotoPicker = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 13, weight: .medium))
                        Text("Browse")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .clipShape(Capsule())
                }
                
                Button(action: { showingCamera = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Record")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                if !recentVideos.isEmpty {
                    Text("\(recentVideos.count) videos")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            // Video grid fills remaining space
            if isLoadingVideos {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading videos...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 100)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 100)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 1.5),
                        GridItem(.flexible(), spacing: 1.5),
                        GridItem(.flexible(), spacing: 1.5)
                    ], spacing: 1.5) {
                        ForEach(recentVideos) { video in
                            RecentVideoCell(video: video)
                                .onTapGesture {
                                    selectRecentVideo(video)
                                }
                        }
                    }
                }
            }
        }
        .onAppear { loadRecentVideos() }
    }
    
    // MARK: - Video Preview View
    
    private var videoPreviewView: some View {
        VStack(spacing: 24) {
            // Large Thumbnail Preview (like your second image)
            VStack(spacing: 16) {
                Text("Preview")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Big Thumbnail Container
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    if let thumbnail = videoThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // Play overlay
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        )
                }
                .onTapGesture {
                    // Play preview
                }
            }
            
            // Thumbnail Time Scrubber
            VStack(spacing: 12) {
                HStack {
                    Text("Thumbnail Time")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatTime(thumbnailTime))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $thumbnailTime, in: 0...videoDuration) { _ in
                    generateThumbnailAtTime(thumbnailTime)
                }
                .accentColor(.red)
            }
            
            // Video Info Card
            HStack(spacing: 12) {
                if let thumbnail = videoThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDuration(videoDuration))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Ready to edit")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            // Quality and Preview Buttons
            HStack(spacing: 12) {
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 18))
                        
                        Text("Preview")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.system(size: 18))
                        
                        Text("1080p")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Video Details View
    
    private var videoDetailsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField("Add a title that describes your video", text: $videoTitle)
                        .font(.system(size: 16))
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Description Input
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
                
                // Visibility Selection
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
                
                // Category Selection
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
                
                // Tags Input
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Thumbnail Selection View
    
    private var thumbnailSelectionView: some View {
        VStack(spacing: 24) {
            Text("Choose Thumbnail")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
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
            
            // Custom Thumbnail Upload
            Button(action: {
                // Upload custom thumbnail
            }) {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    
                    Text("Upload Custom Thumbnail")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Color.red.opacity(0.1))
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
                // Cancel upload
            }
            .font(.system(size: 16))
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .onAppear {
            startUpload()
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
                    // Navigate to video
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
    
    // MARK: - Bottom Action Bar
    
    @ViewBuilder
    private var bottomActionBar: some View {
        if currentStep != .contentSelection && currentStep != .completed && currentStep != .publishing {
            VStack(spacing: 0) {
                Divider()
                
                HStack {
                    Spacer()
                    
                    Button(action: nextStep) {
                        HStack(spacing: 8) {
                            Text(currentStep.nextButtonTitle)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(canProceed ? Color.red : Color.gray.opacity(0.4))
                        )
                    }
                    .disabled(!canProceed)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
            }
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
            var thumbnails: [UIImage] = []
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            // Generate 6 thumbnails at different times
            let times = [0.1, 0.25, 0.4, 0.55, 0.7, 0.85]
            
            for timeRatio in times {
                do {
                    let time = CMTime(seconds: videoDuration * timeRatio, preferredTimescale: 600)
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                    let thumbnail = UIImage(cgImage: cgImage)
                    thumbnails.append(thumbnail)
                } catch {
                    print("Failed to generate thumbnail at \(timeRatio): \(error)")
                }
            }
            
            await MainActor.run {
                self.generatedThumbnails = thumbnails
                if let firstThumbnail = thumbnails.first {
                    self.videoThumbnail = firstThumbnail
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
            } else if uploadManager.uploadError != nil {
                print("🚨 Upload failed: \(uploadManager.uploadError ?? "Unknown error")")
                self.currentStep = .contentSelection
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
}

// MARK: - Supporting Types and Views

enum UploadStep: Int, CaseIterable {
    case contentSelection = 0
    case videoPreview = 1
    case videoDetails = 2
    case thumbnailSelection = 3
    case publishing = 4
    case completed = 5
    
    var title: String {
        switch self {
        case .contentSelection: return "Create"
        case .videoPreview: return "Edit Your Video"
        case .videoDetails: return "Video Details"
        case .thumbnailSelection: return "Choose Thumbnail"
        case .publishing: return "Publishing"
        case .completed: return "Success!"
        }
    }
    
    var subtitle: String {
        switch self {
        case .contentSelection: return ""
        case .videoPreview: return "Preview and adjust your video"
        case .videoDetails: return "Add title, description, and settings"
        case .thumbnailSelection: return "Pick the perfect thumbnail"
        case .publishing: return "Your video is being processed"
        case .completed: return ""
        }
    }
    
    var canSkip: Bool {
        switch self {
        case .videoDetails, .thumbnailSelection: return true
        default: return false
        }
    }
    
    var nextButtonTitle: String {
        switch self {
        case .videoPreview: return "Continue"
        case .videoDetails: return "Next"
        case .thumbnailSelection: return "Publish"
        default: return "Next"
        }
    }
}

struct VisibilityOptionCard: View {
    let visibility: VideoVisibility
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: visibilityIcon)
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(visibilityTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(visibilityDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.red.opacity(0.05) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var visibilityIcon: String {
        switch visibility {
        case .publicVideo: return "globe"
        case .unlisted: return "link"
        case .privateVideo: return "lock"
        }
    }
    
    private var visibilityTitle: String {
        switch visibility {
        case .publicVideo: return "Public"
        case .unlisted: return "Unlisted"
        case .privateVideo: return "Private"
        }
    }
    
    private var visibilityDescription: String {
        switch visibility {
        case .publicVideo: return "Anyone can search for and view"
        case .unlisted: return "Anyone with the link can view"
        case .privateVideo: return "Only you can view"
        }
    }
}

struct TabIndicator: View {
    let icon: String
    let title: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .red : .gray)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .red : .gray)
        }
    }
}

struct UploadFlowTagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
    }
}

// MARK: - Recent Video Model

struct RecentVideo: Identifiable {
    let id: String
    let asset: PHAsset
    let thumbnail: UIImage?
    let duration: TimeInterval
    let creationDate: Date
    
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: creationDate, relativeTo: Date())
    }
}

// MARK: - Recent Video Cell

struct RecentVideoCell: View {
    let video: RecentVideo
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Thumbnail
            if let thumbnail = video.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .aspectRatio(9/16, contentMode: .fill)
                    .overlay(
                        Image(systemName: "video.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
            }
            
            // Duration badge
            Text(video.formattedDuration)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(6)
        }
        .contentShape(Rectangle())
    }
}

struct CameraRecorderView: UIViewControllerRepresentable {
    let onVideoRecorded: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.videoMaximumDuration = 600
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraRecorderView
        
        init(_ parent: CameraRecorderView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.onVideoRecorded(videoURL)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    YouTubeStyleUploadFlow()
        .environmentObject(AppState())
}
