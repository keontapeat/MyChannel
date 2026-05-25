//
//  ProfessionalVideoUploadView.swift
//  MyChannel
//
//  Created by Keonta on 11/15/25.
//

import SwiftUI
import PhotosUI
import AVFoundation

// 📹 Professional Video Upload Interface
// Industry-standard video upload with enterprise backend
struct ProfessionalVideoUploadView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var uploadService = EnhancedVideoUploadService.shared
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var title = ""
    @State private var description = ""
    @State private var selectedVisibility: VideoVisibility = .privateVideo
    @State private var selectedCategory = "General"
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var showingVideoPicker = false
    @State private var showingCamera = false
    @State private var isProcessingVideo = false
    @State private var videoThumbnail: UIImage?
    @State private var videoDuration: TimeInterval = 0
    @State private var videoFileSize: Int64 = 0
    
    private let categories = [
        "General", "Music", "Gaming", "Sports", "News", "Entertainment",
        "Education", "Technology", "Lifestyle", "Comedy", "Travel", "Food"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Video Selection Section
                    videoSelectionSection
                    
                    // Video Preview Section
                    if let videoURL = videoURL {
                        videoPreviewSection(videoURL)
                    }
                    
                    // Upload Form
                    if videoURL != nil {
                        uploadFormSection
                    }
                    
                    // Upload Progress
                    if uploadService.isUploading {
                        uploadProgressSection
                    }
                }
                .padding()
            }
            .navigationTitle("Upload Video")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if videoURL != nil && !title.isEmpty {
                        Button("Upload") {
                            Task {
                                await uploadVideo()
                            }
                        }
                        .disabled(uploadService.isUploading)
                    }
                }
            }
            .photosPicker(
                isPresented: $showingVideoPicker,
                selection: $selectedVideo,
                matching: .videos
            )
            .sheet(isPresented: $showingCamera) {
                CameraVideoRecorderView { url in
                    videoURL = url
                    processSelectedVideo()
                }
            }
            .onChange(of: selectedVideo) { newValue in
                if newValue != nil {
                    loadSelectedVideo()
                }
            }
            .alert("Upload Error", isPresented: .constant(uploadService.error != nil)) {
                Button("OK") {
                    uploadService.error = nil
                }
            } message: {
                Text(uploadService.error ?? "")
            }
        }
    }
    
    // MARK: - Video Selection Section
    
    private var videoSelectionSection: some View {
        VStack(spacing: 16) {
            if videoURL == nil {
                // Upload options
                VStack(spacing: 16) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                    
                    Text("Upload Your Video")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Share your content with the world")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        // Photo Library Button
                        Button(action: {
                            showingVideoPicker = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 24))
                                
                                Text("Photo Library")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Camera Button
                        Button(action: {
                            showingCamera = true
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "camera")
                                    .font(.system(size: 24))
                                
                                Text("Record Video")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 40)
            }
        }
    }
    
    // MARK: - Video Preview Section
    
    private func videoPreviewSection(_ videoURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Video Preview")
                    .font(.system(size: 20, weight: .semibold))
                
                Spacer()
                
                Button("Change Video") {
                    self.videoURL = nil
                    self.videoThumbnail = nil
                    self.title = ""
                    self.description = ""
                    self.tags = []
                }
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
            }
            
            // Video thumbnail and info
            HStack(spacing: 16) {
                // Thumbnail
                Group {
                    if let thumbnail = videoThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 160, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    Text(formatDuration(videoDuration))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                        .padding(6),
                    alignment: .bottomTrailing
                )
                
                // Video info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Video Details")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration: \(formatDuration(videoDuration))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("Size: \(formatFileSize(videoFileSize))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("Format: MP4")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Upload Form Section
    
    private var uploadFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                TextField("Enter video title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 16))
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (optional)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                TextField("Add a description...", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 16))
                    .lineLimit(4...8)
            }
            
            // Visibility
            VStack(alignment: .leading, spacing: 8) {
                Text("Visibility")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    ForEach(VideoVisibility.allCases, id: \.self) { visibility in
                        VisibilityOption(
                            visibility: visibility,
                            isSelected: selectedVisibility == visibility
                        ) {
                            selectedVisibility = visibility
                        }
                    }
                }
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 16, weight: .medium))
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
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                // Tag input
                HStack {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addTag()
                        }
                    
                    Button("Add") {
                        addTag()
                    }
                    .disabled(newTag.isEmpty)
                }
                
                // Tags display
                if !tags.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagChip(tag: tag) {
                                tags.removeAll { $0 == tag }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Upload Progress Section
    
    private var uploadProgressSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Uploading Video")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(uploadService.uploadProgress * 100))%")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            ProgressView(value: uploadService.uploadProgress)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(y: 2)
            
            Text(uploadService.uploadStatus.displayName)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            if let currentUpload = uploadService.currentUpload {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Uploading: \(currentUpload.title)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("This may take a few minutes depending on your video size and internet connection.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
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
                    self.uploadService.error = "Failed to load video: \(error.localizedDescription)"
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
                
                // Generate thumbnail
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let time = CMTime(seconds: min(2.0, durationSeconds / 2), preferredTimescale: 600)
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                
                await MainActor.run {
                    self.videoDuration = durationSeconds
                    self.videoFileSize = fileSize
                    self.videoThumbnail = thumbnail
                    self.isProcessingVideo = false
                    
                    // Auto-generate title if empty
                    if self.title.isEmpty {
                        self.title = "My Video \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.uploadService.error = "Failed to process video: \(error.localizedDescription)"
                    self.isProcessingVideo = false
                }
            }
        }
    }
    
    private func uploadVideo() async {
        guard let videoURL = videoURL,
              !title.isEmpty else { return }
        
        do {
            let _ = try await uploadService.uploadVideo(
                videoURL: videoURL,
                title: title,
                description: description,
                visibility: selectedVisibility,
                category: selectedCategory.lowercased(),
                tags: tags
            )
            
            // Reset form on successful upload
            await MainActor.run {
                self.videoURL = nil
                self.videoThumbnail = nil
                self.title = ""
                self.description = ""
                self.tags = []
                self.selectedVisibility = .privateVideo
                self.selectedCategory = "General"
            }
            
        } catch {
            // Error is handled by the service and displayed in alert
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) && tags.count < 10 {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Views

struct VisibilityOption: View {
    let visibility: VideoVisibility
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: visibilityIcon)
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
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
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 1)
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

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
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
        .cornerRadius(12)
    }
}

struct CameraVideoRecorderView: UIViewControllerRepresentable {
    let onVideoRecorded: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.videoMaximumDuration = 600 // 10 minutes
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraVideoRecorderView
        
        init(_ parent: CameraVideoRecorderView) {
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
    ProfessionalVideoUploadView()
        .environmentObject(AppState())
}
