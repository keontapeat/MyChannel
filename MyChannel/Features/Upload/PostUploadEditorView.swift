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
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

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
                        
                        // 💰 Monetization Section (YouTube-style ads)
                        monetizationSection
                        
                        // 🔥 NEW: MyChannel University Section
                        universitySection
                        
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
    @ViewBuilder
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
            
            // ✅ YOUTUBE-STYLE: All neutral colors
            HStack(spacing: 12) {
                PostUploadQuickActionButton(
                    title: "Pro Editor",
                    subtitle: "Advanced editing",
                    icon: "cpu",
                    color: AppTheme.Colors.textSecondary
                ) {
                    showProEditor = true
                }
                
                PostUploadQuickActionButton(
                    title: "Analytics",
                    subtitle: "View stats",
                    icon: "chart.bar.fill",
                    color: AppTheme.Colors.textSecondary
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
                PostUploadQuickActionButton(
                    title: "Share",
                    subtitle: "Send to friends",
                    icon: "square.and.arrow.up",
                    color: AppTheme.Colors.textSecondary
                ) {
                    // Share video
                    shareVideo()
                }
                
                PostUploadQuickActionButton(
                    title: "Download",
                    subtitle: "Save locally",
                    icon: "arrow.down.circle.fill",
                    color: AppTheme.Colors.textSecondary
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

            // 🔥 YouTube parity: full Public / Unlisted / Private picker
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.visibility.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                        .frame(width: 24)
                    Text("Visibility")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Spacer()
                }

                Picker("Visibility", selection: $viewModel.visibility) {
                    ForEach(Video.VisibilityStatus.allCases, id: \.self) { v in
                        Text(v.displayName).tag(v)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.visibility) { newValue in
                    viewModel.isPublic = (newValue == .public)
                }

                Text(visibilityDescription)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                    )
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

            // 🔥 COPPA compliance: Made for kids
            ProfessionalToggleRow(
                title: "Made for kids",
                subtitle: "Required by law (COPPA). Limits data collection, personalized ads, and comments.",
                icon: "figure.and.child.holdinghands",
                isOn: $viewModel.madeForKids
            )
        }
    }

    private var visibilityDescription: String {
        switch viewModel.visibility {
        case .public: return "Anyone can search for and view this video."
        case .unlisted: return "Anyone with the link can view. Won't appear in search or your channel."
        case .private: return "Only you can view this video."
        }
    }
    
    // MARK: - 💰 Monetization Section (YouTube-style ads)
    private var monetizationSection: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monetization")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Earn money from video ads")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Main Monetization Toggle
            ProfessionalToggleRow(
                title: "Enable Monetization",
                subtitle: "Show ads on this video and earn revenue",
                icon: "play.rectangle.fill",
                isOn: $viewModel.isMonetized
            )
            
            // Monetization Details (show when enabled)
            if viewModel.isMonetized {
                VStack(spacing: 16) {
                    // Ad Placement Options
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ad Placement")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Choose where ads appear in your video")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        VStack(spacing: 8) {
                            AdPlacementToggle(
                                title: "Pre-roll ads",
                                subtitle: "Ads before your video",
                                icon: "play.circle",
                                isOn: $viewModel.enablePreRollAds
                            )
                            
                            if video.duration >= 480 { // Only show for videos 8+ minutes
                                AdPlacementToggle(
                                    title: "Mid-roll ads",
                                    subtitle: "Ads during your video (8+ min)",
                                    icon: "forward.circle",
                                    isOn: $viewModel.enableMidRollAds
                                )
                            }
                            
                            AdPlacementToggle(
                                title: "Post-roll ads",
                                subtitle: "Ads after your video",
                                icon: "stop.circle",
                                isOn: $viewModel.enablePostRollAds
                            )
                        }
                    }
                    
                    // Revenue Estimate Card
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Estimated Revenue")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("$\(estimatedRevenue, specifier: "%.2f") - $\(estimatedRevenueHigh, specifier: "%.2f") per 1K views")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.green)
                            
                            Text("Based on your category and settings")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textTertiary)
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.2), lineWidth: 1.5)
                            )
                    )
                    
                    // Monetization Requirements Info
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How it works")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Viewers see skippable video ads. You earn 90% of ad revenue. Payments processed monthly via Stripe.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // Revenue estimates based on category
    private var estimatedRevenue: Double {
        switch video.category {
        case .gaming: return 1.50
        case .music: return 2.00
        case .movies, .tvShows: return 3.00
        case .anime: return 1.75
        case .sports: return 2.50
        case .news: return 1.80
        case .education: return 2.20
        default: return 1.20
        }
    }
    
    private var estimatedRevenueHigh: Double {
        return estimatedRevenue * 2.5
    }
    
    // MARK: - 🔥 NEW: MyChannel University Section
    private var universitySection: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(UniversityTheme.Colors.iosDevelopment)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("MyChannel University")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Help students earn certificates by tagging educational content")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // University Content Toggle
            ProfessionalToggleRow(
                title: "University Content",
                subtitle: "Tag this video for certificate-eligible learning",
                icon: "checkmark.seal.fill",
                isOn: Binding(
                    get: { viewModel.isUniversityContent },
                    set: { viewModel.isUniversityContent = $0 }
                )
            )
            
            // Show career path selection if enabled
            if viewModel.isUniversityContent {
                VStack(spacing: 16) {
                    // Career Paths Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Career Paths")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Which career fields does this video teach?")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        // Career Path Pills
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                            ForEach(CareerPath.allCareerPaths, id: \.id) { careerPath in
                                CareerPathPillButton(
                                    careerPath: careerPath,
                                    isSelected: viewModel.selectedCareerPaths.contains(careerPath.id)
                                ) {
                                    viewModel.toggleCareerPath(careerPath.id)
                                }
                            }
                        }
                    }
                    
                    // Difficulty Level Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Difficulty Level")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        HStack(spacing: 10) {
                            ForEach([UniversityVideo.DifficultyLevel.beginner, .intermediate, .advanced, .expert], id: \.self) { level in
                                DifficultyLevelButton(
                                    level: level,
                                    isSelected: viewModel.difficultyLevel == level
                                ) {
                                    viewModel.difficultyLevel = level
                                }
                            }
                        }
                    }
                    
                    // Skill Tags
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Skill Tags (Optional)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Add specific skills covered in this video")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        // Skill tags input
                        HStack(spacing: 8) {
                            TextField("e.g. SwiftUI, Async/Await", text: $viewModel.newSkillTag)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppTheme.Colors.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(AppTheme.Colors.divider, lineWidth: 1)
                                        )
                                )
                                .onSubmit {
                                    viewModel.addSkillTag()
                                }
                            
                            Button(action: { viewModel.addSkillTag() }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(UniversityTheme.Colors.iosDevelopment)
                            }
                        }
                        
                        // Display added tags
                        if !viewModel.universitySkillTags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(Array(viewModel.universitySkillTags).sorted(), id: \.self) { tag in
                                    HStack(spacing: 6) {
                                        Text(tag)
                                            .font(.system(size: 13, weight: .medium))
                                        
                                        Button(action: { viewModel.removeSkillTag(tag) }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                    .foregroundColor(UniversityTheme.Colors.iosDevelopment)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(UniversityTheme.Colors.iosDevelopment.opacity(0.1))
                                    )
                                }
                            }
                        }
                    }
                    
                    // Benefits Info Card
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(UniversityTheme.Colors.certificateGold)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Certificate-Eligible Content")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Students watching this video can earn progress toward career certificates.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(UniversityTheme.Colors.certificateGold.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(UniversityTheme.Colors.certificateGold.opacity(0.2), lineWidth: 1.5)
                            )
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
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
    @Published var visibility: Video.VisibilityStatus
    @Published var commentsEnabled: Bool
    @Published var ageRestricted: Bool
    @Published var madeForKids: Bool
    @Published var thumbnail: UIImage?
    
    // University content
    @Published var isUniversityContent: Bool = false
    @Published var selectedCareerPaths: Set<String> = []
    @Published var difficultyLevel: UniversityVideo.DifficultyLevel = .beginner
    @Published var universitySkillTags: Set<String> = []
    @Published var newSkillTag: String = ""
    
    // 💰 Monetization settings (YouTube-style ads)
    @Published var isMonetized: Bool = false
    @Published var enablePreRollAds: Bool = true
    @Published var enableMidRollAds: Bool = true
    @Published var enablePostRollAds: Bool = false
    
    @Published var hasChanges = false
    @Published var errorMessage: String?
    
    init(video: Video) {
        self.video = video
        self.title = video.title
        self.description = video.description
        self.category = video.category
        self.tags = Set(video.tags)
        self.visibility = video.visibility
        self.isPublic = video.visibility == .public
        self.commentsEnabled = video.allowComments ?? true
        self.ageRestricted = video.ageRestricted ?? false
        self.madeForKids = video.madeForKids ?? false
        
        // 💰 Load existing monetization settings
        if let monetization = video.monetization {
            self.isMonetized = monetization.isMonetized
            if let adBreaks = monetization.adBreaks {
                self.enablePreRollAds = adBreaks.preRoll
                self.enableMidRollAds = adBreaks.midRoll
                self.enablePostRollAds = adBreaks.postRoll
            }
        }
        
        // Monitor changes
        setupChangeMonitoring()
    }
    
    private func setupChangeMonitoring() {
        // Monitor all @Published properties for changes
        Task {
            for await _ in Combine.Publishers.CombineLatest4(
                $title,
                $description,
                Combine.Publishers.CombineLatest3($category, $isPublic, $visibility),
                Combine.Publishers.CombineLatest4($commentsEnabled, $ageRestricted, $madeForKids, $tags)
            ).values {
                self.hasChanges = true
            }
        }
    }
    
    func toggleCareerPath(_ careerPathId: String) {
        if selectedCareerPaths.contains(careerPathId) {
            selectedCareerPaths.remove(careerPathId)
        } else {
            selectedCareerPaths.insert(careerPathId)
        }
        hasChanges = true
    }
    
    func addSkillTag() {
        let trimmedTag = newSkillTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return }
        
        universitySkillTags.insert(trimmedTag)
        newSkillTag = ""
        hasChanges = true
    }
    
    func removeSkillTag(_ tag: String) {
        universitySkillTags.remove(tag)
        hasChanges = true
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
                // Treat the client prefilter as a review request, never as a
                // privileged moderation decision. Stop publication until reviewed.
                print("⚠️ [CPS Guardian] Content FLAGGED for review: \(triageResult.reasoning)")
                guard let uid = AuthenticationManager.shared.currentUser?.id else {
                    await MainActor.run { errorMessage = "Sign in before requesting content review." }
                    return
                }
                do {
                    _ = try await ContentReportService.submit(
                        type: .video,
                        contentId: video.id,
                        contentCreatorId: uid,
                        reporterId: uid,
                        reason: String(triageResult.reasoning.prefix(200)),
                        reasonTitle: "Automated prefilter review"
                    )
                    await MainActor.run {
                        errorMessage = "This video is held for Trust & Safety review and was not published."
                    }
                    HapticManager.shared.notification(type: .warning)
                } catch {
                    await MainActor.run {
                        errorMessage = "Unable to queue this video for review: \(error.localizedDescription)"
                    }
                    HapticManager.shared.notification(type: .error)
                }
                return
                
            case .allowWithWarning:
                // ALLOW with warning — surface a banner to the creator
                print("⚠️ [CPS Guardian] Content APPROVED with warnings: \(triageResult.reasoning)")
                await MainActor.run {
                    // Post notification for the UI to show a non-blocking warning banner
                    NotificationCenter.default.post(
                        name: Notification.Name("ContentModerationWarning"),
                        object: triageResult.reasoning
                    )
                }
                
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
            // Resolve current visibility from the toggle (isPublic) unless the
            // dedicated visibility picker changed it to unlisted/private.
            let resolvedVisibility: Video.VisibilityStatus = {
                if visibility != video.visibility { return visibility }
                return isPublic ? .public : (video.visibility == .public ? .private : video.visibility)
            }()

            try await VideoFirestoreService.shared.updateVideoMetadata(
                videoId: video.id,
                title: title != video.title ? title : nil,
                description: description != video.description ? description : nil,
                category: category != video.category ? category : nil,
                tags: Array(tags) != video.tags ? Array(tags) : nil,
                visibility: resolvedVisibility != video.visibility ? resolvedVisibility : nil,
                madeForKids: madeForKids != (video.madeForKids ?? false) ? madeForKids : nil,
                ageRestricted: ageRestricted != (video.ageRestricted ?? false) ? ageRestricted : nil,
                allowComments: commentsEnabled != (video.allowComments ?? true) ? commentsEnabled : nil
            )
            
            // 💰 Save monetization settings if changed
            let existingMonetized = video.monetization?.isMonetized ?? false
            if isMonetized != existingMonetized || isMonetized {
                let adBreaks = Video.AdBreaks(
                    preRoll: enablePreRollAds,
                    midRoll: enableMidRollAds,
                    postRoll: enablePostRollAds,
                    midRollInterval: 480 // Every 8 minutes
                )
                
                let monetizationSettings = Video.MonetizationSettings(
                    isMonetized: isMonetized,
                    adBreaks: adBreaks,
                    sponsorSegments: video.monetization?.sponsorSegments,
                    merchandise: video.monetization?.merchandise,
                    donationEnabled: video.monetization?.donationEnabled ?? false,
                    subscriptionTier: video.monetization?.subscriptionTier,
                    totalRevenue: video.monetization?.totalRevenue ?? 0
                )
                
                try await VideoFirestoreService.shared.updateMonetization(
                    videoId: video.id,
                    monetization: monetizationSettings
                )
                
                print("💰 Monetization settings saved: isMonetized=\(isMonetized), preRoll=\(enablePreRollAds), midRoll=\(enableMidRollAds), postRoll=\(enablePostRollAds)")
            }
            
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

// MARK: - Career Path Pill Button
struct CareerPathPillButton: View {
    let careerPath: CareerPath
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(careerPath.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Difficulty Level Button
struct DifficultyLevelButton: View {
    let level: UniversityVideo.DifficultyLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(levelIcon)
                    .font(.system(size: 20))
                Text(level.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? levelColor : AppTheme.Colors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var levelIcon: String {
        switch level {
        case .beginner: return "🌱"
        case .intermediate: return "🔥"
        case .advanced: return "⚡"
        case .expert: return "👑"
        }
    }
    
    private var levelColor: Color {
        // ✅ YOUTUBE-STYLE: Neutral grays for levels
        switch level {
        case .beginner: return AppTheme.Colors.textTertiary
        case .intermediate: return AppTheme.Colors.textSecondary
        case .advanced: return AppTheme.Colors.textPrimary
        case .expert: return AppTheme.Colors.textPrimary
        }
    }
}

// MARK: - Ad Placement Toggle
struct AdPlacementToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isOn ? .green : AppTheme.Colors.textSecondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.green)
                .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isOn ? Color.green.opacity(0.3) : AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    PostUploadEditorView(video: Video.sampleVideos[0])
}

