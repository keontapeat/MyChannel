//
//  UploadView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation
import AVKit
import UIKit
import UniformTypeIdentifiers

struct UploadView: View {
    @StateObject private var uploadManager = VideoUploadManager()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @StateObject private var globalPlayer = GlobalVideoPlayerManager.shared // 🔥 FIX: Access global player to hide mini player
    
    @State private var uploadStep: UploadStep = .selectMedia
    @State private var creationMode: CreationMode = .video
    @State private var showingCamera = false
    @State private var showLiveSetup = false
    @State private var showPostComposer = false
    
    @State private var showingSuccessAnimation = false
    @State private var isAnimating = false
    
    // Enhanced states
    @State private var showCancelConfirm = false
    @State private var showRestorePrompt = false
    @State private var restoreDraft: UploadDraft?
    @State private var isSavingDraft = false
    @State private var showAIActions = false
    
    // New enhancement states
    @State private var showUploadTips = false
    @State private var selectedEditingTool: EditingTool?
    @State private var showPreview = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var showQualitySettings = false
    @State private var uploadQuality: VideoQuality = .high
    // Captions/Dubs import UI state
    @State private var showCaptionLangDialog = false
    @State private var showDubLangDialog = false
    @State private var selectedLang: String = "en"
    @State private var showCaptionImporter = false
    @State private var showDubImporter = false
    private let supportedLangs = ["en","es","fr","de","pt","hi","ja","zh","ar","ru"]
    
    // Pro Editor
    @State private var showProEditor = false
    @State private var proEditorVideoURL: URL?
    
    enum UploadStep {
        case selectMedia
        case editVideo
        case addDetails
        case uploading
        case completed
    }
    
    // Clean, minimal background - no gradients
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.Colors.background,
                AppTheme.Colors.background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum CreationMode: String, CaseIterable, Identifiable {
        case video, flicks, live, post
        var id: String { rawValue }
        var title: String {
            switch self {
            case .video:  return "Video"
            case .flicks: return "Flicks"
            case .live:   return "Live"
            case .post:   return "Post"
            }
        }
        var icon: String {
            switch self {
            case .video:  return "video.fill"
            case .flicks: return "bolt.fill"
            case .live:   return "dot.radiowaves.left.and.right"
            case .post:   return "square.and.pencil"
            }
        }
    }
    
    enum EditingTool: String, CaseIterable, Identifiable {
        case trim, filters, music, text, effects, speed
        var id: String { rawValue }
        var title: String {
            switch self {
            case .trim: return "Trim & Cut"
            case .filters: return "Filters"
            case .music: return "Add Music"
            case .text: return "Text & Titles"
            case .effects: return "Effects"
            case .speed: return "Speed Control"
            }
        }
        var subtitle: String {
            switch self {
            case .trim: return "Perfect timing"
            case .filters: return "Visual effects"
            case .music: return "Perfect soundtrack"
            case .text: return "Engaging captions"
            case .effects: return "Special effects"
            case .speed: return "Slow/fast motion"
            }
        }
        var icon: String {
            switch self {
            case .trim: return "scissors"
            case .filters: return "camera.filters"
            case .music: return "music.note"
            case .text: return "text.bubble"
            case .effects: return "cpu"
            case .speed: return "speedometer"
            }
        }
        var color: Color {
            // ✅ YOUTUBE-STYLE: All neutral grays - no bright colors
            return AppTheme.Colors.textSecondary
        }
    }
    
    enum VideoQuality: String, CaseIterable, Identifiable {
        case low = "480p", medium = "720p", high = "1080p", ultra = "4K"
        var id: String { rawValue }
        var title: String { rawValue }
        var description: String {
            switch self {
            case .low: return "Faster upload, smaller file"
            case .medium: return "Good balance of quality and size"
            case .high: return "Great quality, recommended"
            case .ultra: return "Best quality, larger file"
            }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()
            
            content
        }
        .navigationTitle("Create")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { uploadToolbar }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
    
    @ViewBuilder
    private var cancelConfirmationButtons: some View {
        Button("Save Draft & Close") {
            Task {
                isSavingDraft = true
                do {
                    let draft = try UploadDraftStorage.shared.saveDraft(from: uploadManager)
                    restoreDraft = draft
                    dismiss()
                } catch {
                    dismiss()
                }
                isSavingDraft = false
            }
        }
        Button("Discard Changes", role: .destructive) {
            dismiss()
        }
        Button("Cancel", role: .cancel) { }
    }
    
    var body: some View {
        NavigationStack {
            mainContent
        }
        .confirmationDialog("Leave creator?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            cancelConfirmationButtons
        } message: {
            Text("You can save your progress as a draft and continue later.")
        }
        .task {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                if let draft = UploadDraftStorage.shared.latest(),
                   uploadManager.videoURL == nil {
                    restoreDraft = draft
                    showRestorePrompt = true
                }
            }
        }
        .alert("Restore draft?", isPresented: $showRestorePrompt, presenting: restoreDraft) { draft in
            Button("Restore") {
                Task {
                    await UploadDraftStorage.shared.hydrateManager(uploadManager, with: draft)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        uploadStep = .editVideo
                    }
                }
            }
            Button("Delete Draft", role: .destructive) {
                if let draft = restoreDraft {
                    UploadDraftStorage.shared.delete(draft)
                    restoreDraft = nil
                }
            }
            Button("Not Now", role: .cancel) { }
        } message: { draft in
            Text("Draft from \(draft.createdAt.formatted(date: .abbreviated, time: .shortened)).")
        }
        // Caption/Dub pickers
        .confirmationDialog("Select caption language", isPresented: $showCaptionLangDialog, titleVisibility: .visible) {
            ForEach(supportedLangs, id: \.self) { lang in
                Button(lang.uppercased()) {
                    selectedLang = lang
                    showCaptionImporter = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Select dub language", isPresented: $showDubLangDialog, titleVisibility: .visible) {
            ForEach(supportedLangs, id: \.self) { lang in
                Button(lang.uppercased()) {
                    selectedLang = lang
                    showDubImporter = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fileImporter(isPresented: $showCaptionImporter, allowedContentTypes: [UTType(filenameExtension: "vtt") ?? .text]) { res in
            switch res {
            case .success(let url):
                let accessed = url.startAccessingSecurityScopedResource()
                uploadManager.addCaption(url: url, lang: selectedLang)
                if accessed { url.stopAccessingSecurityScopedResource() }
            case .failure:
                break
            }
        }
        .fileImporter(isPresented: $showDubImporter, allowedContentTypes: [UTType(filenameExtension: "m4a") ?? .audio]) { res in
            switch res {
            case .success(let url):
                let accessed = url.startAccessingSecurityScopedResource()
                uploadManager.addDub(url: url, lang: selectedLang)
                if accessed { url.stopAccessingSecurityScopedResource() }
            case .failure:
                break
            }
        }
        .safeAreaInset(edge: .bottom) {
            UploadCreationModeBar(
                selected: $creationMode,
                onTap: { mode in
                    HapticManager.shared.impact(style: .medium)
                    switch mode {
                    case .video:
                        uploadStep = .selectMedia
                    case .flicks:
                        showingCamera = true
                    case .live:
                        showLiveSetup = true
                    case .post:
                        showPostComposer = true
                    }
                }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .background(.clear)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ProfessionalCameraView { videoURL in
                Task {
                    await uploadManager.prepareVideo(from: videoURL)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        uploadStep = .editVideo
                    }
                }
                HapticManager.shared.impact(style: .medium)
            }
        }
        .sheet(isPresented: $showPreview) {
            if let url = uploadManager.videoURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showQualitySettings) {
            UploadQualitySettingsView(selected: $uploadQuality)
        }
        .fullScreenCover(isPresented: $showLiveSetup) {
            GoLiveSetupView {
                showLiveSetup = false
            } onStart: { _ in
                showLiveSetup = false
                HapticManager.shared.impact(style: .heavy)
            }
        }
        .fullScreenCover(isPresented: $showPostComposer) {
            NavigationStack {
                CreateCommunityPostView(
                    creator: appState.currentUser ?? User.defaultUser,
                    communityService: MockCommunityService()
                )
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button("Close") { showPostComposer = false }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showProEditor) {
            if let videoURL = proEditorVideoURL {
                ProEditorView(videoURL: videoURL, existingVideo: nil)
            }
        }
        .onChange(of: uploadManager.selectedVideo) { newValue in
            if newValue != nil {
                Task {
                    await uploadManager.loadSelectedVideo()
                    if uploadManager.uploadError == nil {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            uploadStep = .addDetails
                        }
                    }
                }
            }
        }
        // Enter edit flow when launched from options sheet
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StartUploadEditorWithExistingVideo"))) { note in
            if let v = note.object as? Video, let url = URL(string: v.videoURL) {
                Task {
                    await uploadManager.prepareVideo(from: url)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        uploadStep = .editVideo
                    }
                }
            }
        }
        // Launch Pro Editor notification
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LaunchProEditor"))) { note in
            if let url = note.object as? URL {
                proEditorVideoURL = url
                showProEditor = true
            }
        }
        .onAppear {
            // Native PiP handles visibility automatically
            print("🎥 [UploadView] Upload page appeared")
        }
        .onDisappear {
            // Native PiP persists automatically
            print("🎥 [UploadView] Upload page disappeared")
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var uploadToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                HapticManager.shared.impact(style: .light)
                showCancelConfirm = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundStyle(AppTheme.Colors.primary)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            navigationTrailingButton
        }
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            enhancedProgressHeader
            
            ZStack {
                currentStepView
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: uploadStep)
        }
    }
    
    private var enhancedProgressHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    ZStack {
                        Circle()
                            .fill(index <= stepIndex ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                            .frame(width: 12, height: 12)
                            .scaleEffect(index == stepIndex ? 1.2 : 1.0)
                        
                        if index < stepIndex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stepIndex)
                    
                    if index < 3 {
                        Rectangle()
                            .fill(index < stepIndex ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.4), value: stepIndex)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            HStack {
                Text(stepTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .animation(.easeInOut(duration: 0.3), value: stepTitle)
                
                if uploadStep == .uploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                        .scaleEffect(0.8)
                }
            }
            
            Text(stepDescription)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: stepDescription)
        }
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 0))
    }
    
    private var stepIndex: Int {
        switch uploadStep {
        case .selectMedia: return 0
        case .editVideo:   return 1
        case .addDetails:  return 2
        case .uploading, .completed: return 3
        }
    }
    
    private var stepTitle: String {
        switch uploadStep {
        case .selectMedia: return "Choose Your Content"
        case .editVideo:   return "Edit Your Video"
        case .addDetails:  return "Add Details"
        case .uploading:   return "Publishing"
        case .completed:   return "Success!"
        }
    }
    
    private var stepDescription: String {
        switch uploadStep {
        case .selectMedia: return "Select the perfect way to create your content"
        case .editVideo:   return "Professional editing tools to enhance your video"
        case .addDetails:  return "Help viewers discover your content"
        case .uploading:   return "Your video is being processed and uploaded"
        case .completed:   return "Your video is live and ready to watch"
        }
    }
    
    // MARK: - Type-erased current step (fixes type-checker blowup)
    private var currentStepView: AnyView {
        switch uploadStep {
        case .selectMedia:
            return AnyView(selectMediaView)
        case .editVideo:
            return AnyView(
                videoEditingView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.98).combined(with: .opacity),
                        removal: .scale(scale: 0.98).combined(with: .opacity)
                    ))
            )
        case .addDetails:
            return AnyView(
                videoDetailsView
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            )
        case .uploading:
            return AnyView(
                uploadingView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            )
        case .completed:
            return AnyView(
                completedView
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.98, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.98, anchor: .center).combined(with: .opacity)
                    ))
            )
        }
    }
    
    private var selectMediaView: some View {
        MediaGridPickerView(
            mode: creationMode == .flicks ? .flicks : .video,
            title: "Upload video",
            onClose: { dismiss() },
            onPick: { url in
                Task {
                    await uploadManager.prepareVideo(from: url)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        uploadStep = .editVideo
                    }
                }
            }
        )
        .transition(.identity)
    }
    
    // MARK: - Edit View
    private var videoEditingView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Preview")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ZStack {
                        if let thumbnail = uploadManager.thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.Colors.surface)
                                .aspectRatio(16/9, contentMode: .fit)
                                .overlay(
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                                            .scaleEffect(1.2)
                                        Text("Loading preview...")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                )
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        }
                    }
                    
                    if uploadManager.videoDuration > 0 {
                        VStack(spacing: 10) {
                            HStack {
                                Text("Thumbnail Time")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                Spacer()
                                Text(formattedTime(uploadManager.thumbnailTime))
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textTertiary)
                            }
                            
                            Slider(value: Binding(
                                get: { uploadManager.thumbnailTime },
                                set: { newValue in
                                    Task { await uploadManager.updateThumbnail(at: newValue) }
                                }
                            ), in: 0...(max(1, uploadManager.videoDuration - 0.1)), step: 0.1)
                            .tint(AppTheme.Colors.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                videoInfoSummary
                    .padding(.horizontal, 20)
                
                if uploadManager.videoURL != nil {
                    HStack(spacing: 12) {
                        minimalSecondaryButton(icon: "play.circle", title: "Preview") {
                            showPreview = true
                            HapticManager.shared.impact(style: .light)
                        }
                        minimalSecondaryButton(icon: "gear", title: uploadQuality.title) {
                            showQualitySettings = true
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 140)
        }
        .safeAreaInset(edge: .bottom) {
            editingActionBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .background(.thinMaterial)
        }
    }
    
    // MARK: - Extracted Button Views
    @ViewBuilder
    private var editingActionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                previewButton
                qualityButton
            }
            
            continueButton
            
            skipEditingButton
        }
    }

    private var editingActionBar: some View {
        VStack(spacing: 12) {
            editingActionButtons
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var previewButton: some View {
        Button {
            showPreview = true
            HapticManager.shared.impact(style: .light)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.circle")
                Text("Preview")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(AppTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.primary, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
    
    private var qualityButton: some View {
        Button {
            showQualitySettings = true
            HapticManager.shared.impact(style: .light)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gear")
                Text(uploadQuality.title)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(AppTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    private var continueButton: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                uploadStep = .addDetails
            }
        } label: {
            continueButtonLabel
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isAnimating = true }
                .onEnded { _ in isAnimating = false }
        )
    }
    
    private var continueButtonLabel: some View {
        HStack(spacing: 12) {
            Text("Continue").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
            Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.Colors.primary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
        .scaleEffect(isAnimating ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isAnimating)
    }
    
    private var skipEditingButton: some View {
        Button("Skip Editing") {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                uploadStep = .addDetails
            }
        }
        .font(.system(size: 16))
        .foregroundColor(AppTheme.Colors.textSecondary)
    }
    
    // MARK: - Details View
    private var videoDetailsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let thumbnail = uploadManager.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                
                detailCard(title: "Details") {
                    ChannelMentionTextField(
                        title: "Title",
                        text: $uploadManager.title,
                        placeholder: "Give your video a title",
                        icon: "text.cursor",
                        isRequired: true,
                        maxLength: 100
                    )
                    
                    ProfessionalTextEditor(
                        title: "Description",
                        text: $uploadManager.description,
                        placeholder: "Describe your video",
                        icon: "text.bubble",
                        maxLength: 500
                    )
                }
                
                detailCard(title: "Category & Tags") {
                    ProfessionalPicker(
                        title: "Category",
                        selection: $uploadManager.selectedCategory,
                        icon: "folder",
                        options: VideoCategory.allCases
                    )
                    
                    ProfessionalTagInput(
                        title: "Tags",
                        selectedTags: $uploadManager.selectedTags,
                        icon: "tag"
                    )
                }
                
                detailCard(title: "Visibility & Audience") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Visibility")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Picker("Visibility", selection: $uploadManager.isPublic) {
                            Text("Public").tag(true)
                            Text("Private").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Toggle(isOn: $uploadManager.madeForKids) {
                        Text("Made for kids")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                    
                    Toggle(isOn: $uploadManager.ageRestricted) {
                        Text("Age-restricted (18+)")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                    
                    Toggle(isOn: .constant(true)) {
                        Text("Allow comments")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                }
                
                detailCard(title: "Location & Thumbnail") {
                    ProfessionalInputField(
                        title: "Location",
                        text: $uploadManager.filmingLocation,
                        placeholder: "Where was this filmed?",
                        icon: "location",
                        maxLength: 100
                    )
                    
                    ThumbnailSelectionView(
                        autoThumbnail: uploadManager.thumbnail,
                        customThumbnails: $uploadManager.customThumbnails,
                        selectedIndex: $uploadManager.selectedThumbnailIndex
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .padding(.bottom, 160)
        }
        .safeAreaInset(edge: .bottom) {
            uploadActionBar
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .background(.thinMaterial)
        }
    }

    // MARK: - Missing Helpers

    private var videoInfoSummary: some View {
        HStack(spacing: 16) {
            if let thumbnail = uploadManager.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 80, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 80, height: 48)
                    .overlay(Image(systemName: "play.rectangle").foregroundColor(AppTheme.Colors.textTertiary))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(uploadManager.videoDuration > 0 ? formattedTime(uploadManager.videoDuration) : "No video")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Text("Ready to edit")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func minimalSecondaryButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(AppTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.Colors.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func detailCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)

            content()
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1))
    }

    private var uploadActionBar: some View {
        VStack(spacing: 12) {
            Button {
                HapticManager.shared.impact(style: .heavy)
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    uploadStep = .uploading
                }
                uploadManager.isFlicksMode = (creationMode == .flicks)
                Task {
                    await uploadManager.uploadVideo()
                    if uploadManager.uploadError == nil {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                            uploadStep = .completed
                        }
                    } else {
                        withAnimation {
                            uploadStep = .addDetails
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Upload Video")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(uploadManager.title.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: uploadManager.title.isEmpty ? .clear : AppTheme.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(uploadManager.title.isEmpty)
            
            Text("Make sure your title is engaging to attract more viewers!")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppTheme.Colors.divider.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Uploading View
    private var uploadingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color(.systemGray6), lineWidth: 10)
                        .frame(width: 180, height: 180)
                    
                    // Gradient progress circle - Beautiful green!
                    Circle()
                        .trim(from: 0, to: uploadManager.uploadProgress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.9, blue: 0.6),  // Bright mint green
                                    Color(red: 0.1, green: 0.7, blue: 0.4)   // Rich emerald green
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: uploadManager.uploadProgress)
                    
                    VStack(spacing: 6) {
                        Text("\(Int(uploadManager.uploadProgress * 100))%")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text("Uploading")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                VStack(spacing: 6) {
                    Text("Processing Your Video")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text("Optimizing for best quality")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            VStack(spacing: 14) {
                uploadStageRow(title: "Analyzing video", isCompleted: uploadManager.uploadProgress > 0.2, isActive: uploadManager.uploadProgress <= 0.2)
                uploadStageRow(title: "Optimizing quality", isCompleted: uploadManager.uploadProgress > 0.5, isActive: uploadManager.uploadProgress > 0.2 && uploadManager.uploadProgress <= 0.5)
                uploadStageRow(title: "Generating thumbnail", isCompleted: uploadManager.uploadProgress > 0.8, isActive: uploadManager.uploadProgress > 0.5 && uploadManager.uploadProgress <= 0.8)
                uploadStageRow(title: "Publishing video", isCompleted: uploadManager.uploadProgress >= 1.0, isActive: uploadManager.uploadProgress > 0.8)
            }
            .padding(.horizontal, 32)
            
            // 🔥 NUCLEAR FIX #1: Cancel button
            if !uploadManager.isCancelling {
                Button(action: {
                    uploadManager.cancelUpload()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Cancel Upload")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.top, 20)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        .scaleEffect(0.8)
                    Text("Cancelling...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(.top, 20)
            }
            
            if let error = uploadManager.uploadError {
                VStack(spacing: 16) {
                    Text("Upload Failed").font(.system(size: 20, weight: .semibold)).foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button("Try Again") {
                        HapticManager.shared.impact(style: .medium)
                        Task {
                            await uploadManager.uploadVideo()
                            if uploadManager.uploadError == nil {
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                                    uploadStep = .completed
                                }
                            }
                        }
                    }
                    .buttonStyle(ProfessionalButtonStyle(style: .primary))
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Completed View
    private var completedView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.95, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Success Animation
                VStack(spacing: 28) {
                    ZStack {
                        // Outer pulse ring
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.1))
                            .frame(width: 160, height: 160)
                            .scaleEffect(showingSuccessAnimation ? 1.2 : 1.0)
                            .opacity(showingSuccessAnimation ? 0 : 1)
                        
                        // Middle ring
                        Circle()
                            .fill(AppTheme.Colors.primary.opacity(0.15))
                            .frame(width: 140, height: 140)
                        
                        // Inner circle with checkmark
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 110, height: 110)
                                .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(showingSuccessAnimation ? 1.0 : 0.5)
                        }
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showingSuccessAnimation)
                    
                    VStack(spacing: 12) {
                        Text("Video Published!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Your video is now live")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.bottom, 48)
                
                // Action buttons
                VStack(spacing: 14) {
                    if let uploadedVideo = uploadManager.uploadedVideo {
                        // Watch Video (Primary)
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            NotificationCenter.default.post(
                                name: NSNotification.Name("NavigateToVideo"),
                                object: uploadedVideo
                            )
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Watch Your Video")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: AppTheme.Colors.primary.opacity(0.35), radius: 15, x: 0, y: 8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Go to Profile
                    Button {
                        HapticManager.shared.impact(style: .light)
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToProfileTab"), object: nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Go to Your Channel")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.Colors.divider, lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    
                    // Create Another Video
                    Button {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            uploadStep = .selectMedia
                        }
                        uploadManager.resetForm()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Create Another Video")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(AppTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.Colors.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    
                    // Share Video
                    Button {
                        HapticManager.shared.impact(style: .light)
                        // TODO: Implement share sheet
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                            Text("Share Video")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                Spacer()
            }
        }
    }
    
    private func uploadStageRow(title: String, isCompleted: Bool, isActive: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : (isActive ? AppTheme.Colors.primary : Color(.systemGray5)))
                    .frame(width: 24, height: 24)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else if isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.55)
                }
            }
            
            Text(title)
                .font(.system(size: 16, weight: isActive ? .semibold : .medium))
                .foregroundColor(
                    isCompleted ? Color.green : (isActive ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                )
            
            Spacer()
        }
        .animation(.easeOut(duration: 0.25), value: isCompleted)
        .animation(.easeOut(duration: 0.25), value: isActive)
    }
    
    private var navigationTrailingButton: some View {
        Group {
            switch uploadStep {
            case .editVideo:
                Button("Skip") {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        uploadStep = .addDetails
                    }
                }
                .foregroundColor(AppTheme.Colors.primary)
            case .addDetails:
                Button("Upload") {
                    HapticManager.shared.impact(style: .heavy)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        uploadStep = .uploading
                    }
                    // 🔥 Set Flicks mode before upload
                    uploadManager.isFlicksMode = (creationMode == .flicks)
                    Task {
                        await uploadManager.uploadVideo()
                        if uploadManager.uploadError == nil {
                            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                                uploadStep = .completed
                            }
                        } else {
                            withAnimation {
                                uploadStep = .addDetails
                            }
                        }
                    }
                }
                .foregroundColor(uploadManager.title.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
                .disabled(uploadManager.title.isEmpty)
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Helpers
    private var videoInfoColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 120), spacing: 12)
        ]
    }
    
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
    
    private func formattedTime(_ seconds: TimeInterval) -> String {
        formattedDuration(seconds)
    }
    
    private func resolutionText(_ size: CGSize) -> String {
        guard size.width > 0 && size.height > 0 else { return "—" }
        return "\(Int(size.width))×\(Int(size.height))"
    }
    
    private func infoChip(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.surface.opacity(0.8))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .tracking(0.2)
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

struct EditingToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isPressed ? color.opacity(0.15) : AppTheme.Colors.cardBackground)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(isPressed ? color.opacity(0.4) : AppTheme.Colors.divider.opacity(0.2), lineWidth: 1.5)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(isPressed ? color : AppTheme.Colors.textSecondary)
                        .scaleEffect(isPressed ? 1.05 : 1.0)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isPressed)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160, alignment: .top)
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isPressed ? AppTheme.Colors.cardBackground.opacity(0.8) : AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.Colors.divider.opacity(isPressed ? 0.4 : 0.2), lineWidth: 1)
                    )
            )
            .shadow(
                color: .black.opacity(isPressed ? 0.1 : 0.04),
                radius: isPressed ? 10 : 6,
                x: 0,
                y: isPressed ? 6 : 3
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        HapticManager.shared.impact(style: .light)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// 🔥 NUCLEAR CREATION MODE BAR
struct UploadCreationModeBar: View {
    @Binding var selected: UploadView.CreationMode
    let onTap: (UploadView.CreationMode) -> Void
    
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.sizeCategory) private var sizeCategory
    @Namespace private var ns
    @State private var isExpanded = false
    
    private var isPad: Bool { hSizeClass == .regular }
    private var isCompactWidth: Bool {
        UIScreen.main.bounds.width < 360
    }
    private var showLabels: Bool {
        return isPad || (!isCompactWidth && sizeCategory <= .large) || isExpanded
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 🔥 QUICK ACTIONS (when expanded)
            if isExpanded {
                quickActionsBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 🔥 MAIN MODE BAR
            HStack(spacing: 8) {
                ForEach(UploadView.CreationMode.allCases) { mode in
                    NuclearModeButton(
                        ns: ns,
                        mode: mode,
                        isSelected: selected == mode,
                        showLabels: showLabels,
                        isExpanded: isExpanded,
                        onTap: {
                            HapticManager.shared.impact(style: .medium)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selected = mode
                            }
                            onTap(mode)
                        }
                    )
                }
                
                // 🔥 EXPAND/COLLAPSE BUTTON
                Button {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.15),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Glassmorphism effect
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                    
                    // ✅ YOUTUBE-STYLE: Clean subtle border
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selected)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isExpanded)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Creation mode")
    }
    
    // ✅ YOUTUBE-STYLE QUICK ACTIONS BAR
    private var quickActionsBar: some View {
        HStack(spacing: 16) {
            quickActionButton(icon: "camera.fill", title: "Camera") {
                // Open camera
            }
            
            quickActionButton(icon: "photo.on.rectangle", title: "Gallery") {
                // Open gallery
            }
            
            quickActionButton(icon: "mic.fill", title: "Audio") {
                // Record audio
            }
            
            quickActionButton(icon: "text.bubble.fill", title: "Post") {
                // Create post
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Colors.surface.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.bottom, 8)
    }
    
    private func quickActionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
                            )
                    )
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// 🔥 NUCLEAR MODE BUTTON
private struct NuclearModeButton: View {
    let ns: Namespace.ID
    let mode: UploadView.CreationMode
    let isSelected: Bool
    let showLabels: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // ✅ YOUTUBE-STYLE CLEAN BACKGROUND (No purple!)
                if isSelected {
                    Capsule()
                        .fill(AppTheme.Colors.textPrimary)
                        .matchedGeometryEffect(id: "selector", in: ns)
                        .frame(height: 44)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
                
                // 🔥 CONTENT
                VStack(spacing: 4) {
                    Image(systemName: mode.icon)
                        .font(.system(size: isExpanded ? 18 : 16, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                    
                    if showLabels {
                        Text(mode.title)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .padding(.horizontal, showLabels ? 14 : 12)
                .frame(height: 44)
                .frame(minWidth: showLabels ? 0 : 44)
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .scaleEffect(isPressed ? 0.92 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isExpanded)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct UploadQualitySettingsView: View {
    @Binding var selected: UploadView.VideoQuality
    var body: some View {
        NavigationStack {
            List {
                ForEach(UploadView.VideoQuality.allCases) { quality in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quality.title).font(.headline)
                            Text(quality.description).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if selected == quality {
                            Image(systemName: "checkmark").foregroundColor(AppTheme.Colors.primary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selected = quality }
                }
            }
            .navigationTitle("Upload Quality")
        }
    }
}

struct ProfessionalInputField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let isRequired: Bool
    let maxLength: Int
    
    @FocusState private var isFocused: Bool
    
    init(title: String, text: Binding<String>, placeholder: String, icon: String, isRequired: Bool = false, maxLength: Int = 1000) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isRequired = isRequired
        self.maxLength = maxLength
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Colors.textPrimary)
                if isRequired { Text("*").font(.system(size: 16, weight: .semibold)).foregroundColor(.red) }
                Spacer()
                Text("\(text.count)/\(maxLength)").font(.system(size: 12)).foregroundColor(text.count > maxLength ? .red : AppTheme.Colors.textTertiary)
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary).frame(width: 20)
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .focused($isFocused)
                    .onChange(of: text) { newValue in
                        if newValue.count > maxLength { text = String(newValue.prefix(maxLength)) }
                    }
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isFocused ? 2 : 1))
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct ProfessionalTextEditor: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let maxLength: Int
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Text("\(text.count)/\(maxLength)").font(.system(size: 12)).foregroundColor(text.count > maxLength ? .red : AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: icon).font(.system(size: 16)).foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary).frame(width: 20)
                    Text("Description").font(.system(size: 16, weight: .medium)).foregroundColor(AppTheme.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .onChange(of: text) { newValue in
                            if newValue.count > maxLength { text = String(newValue.prefix(maxLength)) }
                        }
                    
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 100)
            }
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.2), lineWidth: isFocused ? 2 : 1))
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

struct ProfessionalPicker<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String, T: CustomStringConvertible {
    let title: String
    @Binding var selection: T
    let icon: String
    let options: [T]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        HStack {
                            Text(option.description)
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            if option == selection {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppTheme.Colors.surface.opacity(0.7))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected category")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        Text(selection.description)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                )
            }
            .contentShape(Rectangle())
        }
    }
}

// 🔥 YOUTUBE PARITY: Professional tag input with sleek, modern design
struct ProfessionalTagInput: View {
    let title: String
    @Binding var selectedTags: Set<String>
    let icon: String
    
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    private let suggestedTags = ["Tutorial", "Educational", "Fun", "Music", "Gaming", "Tech", "Lifestyle", "Comedy", "Trending", "Creative"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with count
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                // Count badge (YouTube-style)
                Text("\(selectedTags.count)/10")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(selectedTags.count >= 10 ? .red : AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(selectedTags.count >= 10 ? Color.red.opacity(0.1) : AppTheme.Colors.surface)
                    )
            }
            
            // Input field (YouTube-style clean design)
            HStack(spacing: 12) {
                TextField("Add tags", text: $inputText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .focused($isInputFocused)
                    .onSubmit { addTag() }
                    .submitLabel(.done)
                
                if !inputText.isEmpty {
                    Button(action: { inputText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                    }
                }
                
                Button(action: addTag) {
                    Text("Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(canAddTag ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                }
                .disabled(!canAddTag)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isInputFocused ? AppTheme.Colors.surface : AppTheme.Colors.surface.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isInputFocused ? AppTheme.Colors.primary.opacity(0.5) : AppTheme.Colors.divider.opacity(0.2), lineWidth: isInputFocused ? 1.5 : 1)
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isInputFocused)
            
            // Selected tags (YouTube-style horizontal scroll)
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                            YouTubeStyleTagChip(tag: tag, isSelected: true) {
                                _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTags.remove(tag)
                                }
                                HapticManager.shared.impact(style: .light)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            // Suggested tags (YouTube-style clean layout)
            if !availableSuggestedTags.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Suggested")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .padding(.leading, 4)
                    
                    // Flow layout for suggested tags
                    FlowLayout(spacing: 8) {
                        ForEach(availableSuggestedTags.prefix(8), id: \.self) { tag in
                            YouTubeStyleTagChip(tag: tag, isSelected: false) {
                                if selectedTags.count < 10 {
                                    _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedTags.insert(tag)
                                    }
                                    HapticManager.shared.impact(style: .light)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var canAddTag: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !selectedTags.contains(trimmed) && selectedTags.count < 10
    }
    
    private var availableSuggestedTags: [String] {
        suggestedTags.filter { !selectedTags.contains($0) }
    }
    
    private func addTag() {
        let tag = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !selectedTags.contains(tag) && selectedTags.count < 10 {
            _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTags.insert(tag)
            }
            inputText = ""
            HapticManager.shared.impact(style: .light)
        }
    }
}

// 🔥 YOUTUBE PARITY: Sleek tag chip design
struct YouTubeStyleTagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(tag)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                Image(systemName: isSelected ? "xmark" : "plus")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
            )
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// FlowLayout is now in Core/Components/FlowLayout.swift (shared component)

// Old ProfessionalTagChip replaced by YouTubeStyleTagChip above

struct ProfessionalToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    let isPremium: Bool
    
    init(title: String, subtitle: String, icon: String, isOn: Binding<Bool>, isPremium: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isOn = isOn
        self.isPremium = isPremium
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(isOn ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundColor(isOn ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Colors.textPrimary)
                    if isPremium {
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.Colors.primary)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle).font(.system(size: 14)).foregroundColor(AppTheme.Colors.textSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn).toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1))
    }
}

struct ProfessionalButtonStyle: ButtonStyle {
    enum Style { case primary, secondary }
    let style: Style
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - New YouTube Parity Components

// MARK: - Visibility Picker (Disabled - using simple toggle instead)
/*
struct ProfessionalVisibilityPicker: View {
    let title: String
    @Binding var selection: VideoUploadManager.VideoVisibility
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.Colors.primary)
                    .font(.system(size: 16, weight: .medium))
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            VStack(spacing: 8) {
                ForEach(VideoUploadManager.VideoVisibility.allCases) { visibility in
                    Button {
                        selection = visibility
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: visibility.icon)
                                .foregroundColor(selection == visibility ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                                .font(.system(size: 16))
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(visibility.rawValue)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                
                                Text(visibility.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if selection == visibility {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .font(.system(size: 18))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selection == visibility ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selection == visibility ? AppTheme.Colors.primary : AppTheme.Colors.divider, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
*/

struct ProfessionalDatePicker: View {
    let title: String
    @Binding var date: Date
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(AppTheme.Colors.primary)
                    .font(.system(size: 16, weight: .medium))
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            DatePicker("", selection: $date, in: Date()...)
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
        }
    }
}

struct ThumbnailSelectionView: View {
    let autoThumbnail: UIImage?
    @Binding var customThumbnails: [UIImage]
    @Binding var selectedIndex: Int
    @State private var showingImagePicker = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Auto-generated thumbnail
                if let autoThumbnail = autoThumbnail {
                    ThumbnailOption(
                        image: autoThumbnail,
                        isSelected: selectedIndex == 0,
                        label: "Auto"
                    ) {
                        selectedIndex = 0
                    }
                }
                
                // Custom thumbnails
                ForEach(customThumbnails.indices, id: \.self) { index in
                    ThumbnailOption(
                        image: customThumbnails[index],
                        isSelected: selectedIndex == index + 1,
                        label: nil
                    ) {
                        selectedIndex = index + 1
                    }
                }
                
                // Add custom thumbnail button
                Button {
                    showingImagePicker = true
                } label: {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.cardBackground)
                            .frame(width: 120, height: 68)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.primary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.Colors.divider, style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        
                        Text("Custom")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerWrapper { image in
                if let image = image {
                    customThumbnails.append(image)
                    selectedIndex = customThumbnails.count // Select the newly added thumbnail
                }
            }
        }
    }
}

// MARK: - ImagePicker Wrapper
struct ImagePickerWrapper: UIViewControllerRepresentable {
    let onImageSelected: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerWrapper
        
        init(_ parent: ImagePickerWrapper) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            } else {
                parent.onImageSelected(nil)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImageSelected(nil)
            parent.dismiss()
        }
    }
}

struct ThumbnailOption: View {
    let image: UIImage
    let isSelected: Bool
    let label: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.divider, lineWidth: isSelected ? 3 : 1)
                    )
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.Colors.primary)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .font(.system(size: 20))
                            }
                        },
                        alignment: .topTrailing
                    )
                
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("UploadView") {
    UploadView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}