//
//  PostUploadEditorView.swift
//  MyChannel
//
//  Edit video metadata after upload (YouTube-style)
//  Created for MyChannel by AI Assistant
//

import SwiftUI
import PhotosUI
import Combine

struct PostUploadEditorView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PostUploadEditorViewModel
    
    @State private var showProEditor = false
    @State private var showDeleteConfirmation = false
    @State private var isSaving = false
    
    init(video: Video) {
        self.video = video
        _viewModel = StateObject(wrappedValue: PostUploadEditorViewModel(video: video))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Video Preview
                        videoPreviewSection
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Metadata Editor
                        metadataSection
                        
                        // Privacy & Settings
                        privacySection
                        
                        // Danger Zone
                        dangerZoneSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Edit Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            isSaving = true
                            await viewModel.saveChanges()
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    .disabled(isSaving || !viewModel.hasChanges)
                }
            }
        }
        .fullScreenCover(isPresented: $showProEditor) {
            if let videoURL = URL(string: video.videoURL) {
                ProEditorView(videoURL: videoURL, existingVideo: video)
            }
        }
        .alert("Delete Video?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteVideo()
                    dismiss()
                }
            }
        } message: {
            Text("This action cannot be undone. Your video will be permanently deleted.")
        }
    }
    
    // MARK: - Video Preview Section
    private var videoPreviewSection: some View {
        VStack(spacing: 16) {
            if let thumbnail = viewModel.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 10)
            } else {
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.Colors.surface)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            ProgressView()
                        )
                }
                .shadow(color: .black.opacity(0.1), radius: 10)
            }
            
            HStack(spacing: 12) {
                infoChip(icon: "eye.fill", value: "\(video.viewCount.abbreviated)")
                infoChip(icon: "hand.thumbsup.fill", value: "\(video.likeCount.abbreviated)")
                infoChip(icon: "bubble.left.fill", value: "\(video.commentCount.abbreviated)")
                infoChip(icon: "clock.fill", value: formatDuration(video.duration))
            }
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                PostUploadQuickActionButton(
                    title: "Pro Editor",
                    subtitle: "Advanced editing",
                    icon: "wand.and.stars",
                    color: .purple
                ) {
                    showProEditor = true
                }
                
                PostUploadQuickActionButton(
                    title: "Analytics",
                    subtitle: "View stats",
                    icon: "chart.bar.fill",
                    color: .blue
                ) {
                    // Navigate to analytics
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowVideoAnalytics"),
                        object: video.id
                    )
                    dismiss()
                }
            }
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Share",
                    subtitle: "Send to friends",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    // Share video
                    shareVideo()
                }
                
                QuickActionButton(
                    title: "Download",
                    subtitle: "Save locally",
                    icon: "arrow.down.circle.fill",
                    color: .orange
                ) {
                    // Download video
                    downloadVideo()
                }
            }
        }
    }
    
    // MARK: - Metadata Section
    private var metadataSection: some View {
        VStack(spacing: 20) {
            Text("Video Details")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 🔥 YOUTUBE PARITY: Title field with @channel autocomplete
            ChannelMentionTextField(
                title: "Title",
                text: $viewModel.title,
                placeholder: "Enter video title (use @ to tag channels)",
                icon: "text.cursor",
                isRequired: true,
                maxLength: 100
            )
            
            ProfessionalTextEditor(
                title: "Description",
                text: $viewModel.description,
                placeholder: "Describe your video",
                icon: "text.bubble",
                maxLength: 5000
            )
            
            ProfessionalPicker(
                title: "Category",
                selection: $viewModel.category,
                icon: "folder",
                options: VideoCategory.allCases
            )
            
            ProfessionalTagInput(
                title: "Tags",
                selectedTags: $viewModel.tags,
                icon: "tag"
            )
        }
    }
    
    // MARK: - Privacy Section
    private var privacySection: some View {
        VStack(spacing: 16) {
            Text("Privacy & Visibility")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ProfessionalToggleRow(
                title: "Public",
                subtitle: "Anyone can search for and view",
                icon: "globe",
                isOn: $viewModel.isPublic
            )
            
            ProfessionalToggleRow(
                title: "Enable Comments",
                subtitle: "Allow viewers to comment",
                icon: "bubble.left.and.bubble.right",
                isOn: $viewModel.commentsEnabled
            )
            
            ProfessionalToggleRow(
                title: "Age-restricted",
                subtitle: "Only viewers 18+ can watch",
                icon: "18.circle",
                isOn: $viewModel.ageRestricted
            )
        }
    }
    
    // MARK: - Danger Zone
    private var dangerZoneSection: some View {
        VStack(spacing: 16) {
            Text("Danger Zone")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Delete Video")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Helpers
    private func infoChip(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.surface)
        .clipShape(Capsule())
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
    
    private func shareVideo() {
        // Implement share functionality
        print("📤 Sharing video...")
    }
    
    private func downloadVideo() {
        // Implement download functionality
        print("⬇️ Downloading video...")
    }
}

// MARK: - Quick Action Button
struct PostUploadQuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model
@MainActor
class PostUploadEditorViewModel: ObservableObject {
    let video: Video
    
    @Published var title: String
    @Published var description: String
    @Published var category: VideoCategory
    @Published var tags: Set<String>
    @Published var isPublic: Bool
    @Published var commentsEnabled: Bool
    @Published var ageRestricted: Bool
    @Published var thumbnail: UIImage?
    
    @Published var hasChanges = false
    @Published var errorMessage: String?
    
    init(video: Video) {
        self.video = video
        self.title = video.title
        self.description = video.description
        self.category = video.category
        self.tags = [] // Set(video.tags) if available
        self.isPublic = true // Default to public
        self.commentsEnabled = true // Fetch from video settings
        self.ageRestricted = false // Fetch from video settings
        
        // Monitor changes
        setupChangeMonitoring()
    }
    
    private func setupChangeMonitoring() {
        // Monitor all @Published properties for changes
        Task {
            for await _ in Combine.Publishers.CombineLatest4(
                $title,
                $description,
                Combine.Publishers.CombineLatest($category, $isPublic),
                Combine.Publishers.CombineLatest($commentsEnabled, $ageRestricted)
            ).values {
                self.hasChanges = true
            }
        }
    }
    
    func saveChanges() async {
        print("💾 Saving changes to video...")
        
        // 🛡️ CPS GUARDIAN: Check content compliance BEFORE publishing
        print("🛡️ [CPS Guardian] Analyzing content for compliance...")
        
        do {
            let metadata = VertexVideoMetadata(
                title: title,
                description: description,
                category: category.rawValue,
                duration: video.duration
            )
            
            let triageResult = try await VertexAIAgentService.shared.triageContent(
                videoID: video.id,
                metadata: metadata,
                transcript: nil,
                audioFingerprint: nil
            )
            
            print("🛡️ [CPS Guardian] Decision: \(triageResult.decision), Confidence: \(triageResult.confidence)")
            
            // Handle CPS Guardian decision
            switch triageResult.decision {
            case .reject:
                // BLOCK: Content violates policies
                print("🚨 [CPS Guardian] Content REJECTED: \(triageResult.reasoning)")
                await MainActor.run {
                    errorMessage = "Content blocked: \(triageResult.reasoning)"
                }
                HapticManager.shared.notification(type: .error)
                return
                
            case .holdForReview:
                // FLAG for manual review (but allow save for now)
                print("⚠️ [CPS Guardian] Content FLAGGED for review: \(triageResult.reasoning)")
                // TODO: Send alert to admin dashboard for manual review
                
            case .allowWithWarning:
                // ALLOW with warning
                print("⚠️ [CPS Guardian] Content APPROVED with warnings: \(triageResult.reasoning)")
                // TODO: Show warning to user about potential issues
                
            case .allow:
                // APPROVE: Content is clean
                print("✅ [CPS Guardian] Content APPROVED")
            }
            
        } catch {
            print("⚠️ [CPS Guardian] Agent unavailable, proceeding anyway: \(error)")
            // Graceful degradation - don't block if CPS agent fails
        }
        
        // Proceed with saving metadata
        do {
            try await VideoFirestoreService.shared.updateVideoMetadata(
                videoId: video.id,
                title: title != video.title ? title : nil,
                description: description != video.description ? description : nil,
                category: category != video.category ? category : nil,
                tags: Array(tags) != video.tags ? Array(tags) : nil
            )
            
            print("✅ Video metadata updated successfully!")
            HapticManager.shared.notification(type: .success)
        } catch {
            print("❌ Failed to update video: \(error)")
            HapticManager.shared.notification(type: .error)
        }
    }
    
    func deleteVideo() async {
        print("🗑️ Deleting video...")
        
        do {
            try await VideoFirestoreService.shared.deleteVideo(videoId: video.id)
            
            // Delete from storage
            if !video.videoURL.isEmpty {
                try await VideoStorageService.shared.deleteVideo(from: video.videoURL)
            }
            if !video.thumbnailURL.isEmpty {
                try await UserMediaStorageService.shared.deleteImage(from: video.thumbnailURL)
            }
            
            print("✅ Video deleted successfully!")
            HapticManager.shared.notification(type: .success)
        } catch {
            print("❌ Failed to delete video: \(error)")
            HapticManager.shared.notification(type: .error)
        }
    }
}

// Int.abbreviated extension is defined in FlicksChallengesViewModel.swift

#Preview {
    PostUploadEditorView(video: Video.sampleVideos[0])
}

