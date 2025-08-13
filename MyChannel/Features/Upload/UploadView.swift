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

struct UploadView: View {
    @StateObject private var uploadManager = VideoUploadManager()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @State private var uploadStep: UploadStep = .selectMedia
    @State private var creationMode: CreationMode = .video
    @State private var showingCamera = false
    @State private var showLiveSetup = false
    @State private var showPostComposer = false
    
    @State private var showingSuccessAnimation = false
    @State private var isAnimating = false
    
    // New states
    @State private var showCancelConfirm = false
    @State private var showRestorePrompt = false
    @State private var restoreDraft: UploadDraft?
    @State private var isSavingDraft = false
    @State private var showAIActions = false
    
    enum UploadStep {
        case selectMedia
        case editVideo
        case addDetails
        case uploading
        case completed
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        AppTheme.Colors.primary.opacity(0.05),
                        AppTheme.Colors.secondary.opacity(0.03),
                        AppTheme.Colors.background
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                content
            }
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    navigationTrailingButton
                }
            }
        }
        .confirmationDialog("Leave creator?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Save Draft & Close") {
                Task {
                    isSavingDraft = true
                    do {
                        let draft = try UploadDraftStorage.shared.saveDraft(from: uploadManager)
                        restoreDraft = draft
                        dismiss()
                    } catch {
                        // If no video yet, just close
                        dismiss()
                    }
                    isSavingDraft = false
                }
            }
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
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
        .onChange(of: uploadManager.selectedVideo) { _, newValue in
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
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            enhancedProgressHeader
            
            ZStack {
                switch uploadStep {
                case .selectMedia:
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
                    
                case .editVideo:
                    videoEditingView
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98).combined(with: .opacity),
                            removal: .scale(scale: 0.98).combined(with: .opacity)
                        ))
                case .addDetails:
                    videoDetailsView
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                case .uploading:
                    uploadingView
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                case .completed:
                    completedView
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98, anchor: .center).combined(with: .opacity),
                            removal: .scale(scale: 0.98, anchor: .center).combined(with: .opacity)
                        ))
                }
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
        case .editVideo:   return "Perfect Your Video"
        case .addDetails:  return "Add the Finishing Touches"
        case .uploading:   return "Publishing Your Creation"
        case .completed:   return "🎉 Success!"
        }
    }
    
    private var stepDescription: String {
        switch uploadStep {
        case .selectMedia: return "Select the perfect way to create your content"
        case .editVideo:   return "Fine-tune your video with professional editing tools"
        case .addDetails:  return "Help viewers discover your amazing content"
        case .uploading:   return "Your video is being processed and uploaded"
        case .completed:   return "Your video is live and ready to inspire!"
        }
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
                
                VStack(spacing: 20) {
                    Text("Video Info")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        infoChip("Duration", formattedDuration(uploadManager.videoDuration), "clock")
                        infoChip("Size", String(format: "%.1f MB", uploadManager.fileSizeMB), "externaldrive")
                        infoChip("Resolution", resolutionText(uploadManager.videoDimensions), "rectangle.on.rectangle")
                    }
                }
                .padding(.horizontal, 20)
                
                if creationMode == .flicks, uploadManager.videoDuration > 60 {
                    HStack {
                        Image(systemName: "scissors")
                        Text("Auto-trim to 60s for Flicks")
                        Spacer()
                        Text(formattedDuration(60))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .font(.footnote)
                    }
                    .padding()
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        Task {
                            try? await uploadManager.autoTrimToFlicksIfNeeded()
                            HapticManager.shared.impact(style: .medium)
                        }
                    }
                }
                
                VStack(spacing: 20) {
                    Text("Editing Tools")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        EditingToolCard(title: "Trim & Cut", subtitle: "Perfect timing", icon: "scissors", color: .blue) { }
                        EditingToolCard(title: "Filters", subtitle: "Visual effects", icon: "camera.filters", color: .purple) { }
                        EditingToolCard(title: "Add Music", subtitle: "Perfect soundtrack", icon: "music.note", color: .green) { }
                        EditingToolCard(title: "Text & Titles", subtitle: "Engaging captions", icon: "text.bubble", color: .orange) { }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
                
                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            uploadStep = .addDetails
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text("Continue").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                            Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 15, x: 0, y: 8);
                    }
                    .buttonStyle(.plain)
                    
                    Button("Skip Editing") {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            uploadStep = .addDetails
                        }
                    }
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Details View
    private var videoDetailsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let thumbnail = uploadManager.thumbnail {
                    VStack(spacing: 12) {
                        Text("Your Video")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .frame(maxWidth: 300)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Smart Assist")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Spacer()
                        Menu {
                            Button("Suggest Title") {
                                uploadManager.title = CreatorAssistService.suggestTitle(
                                    fromExisting: uploadManager.title,
                                    category: uploadManager.selectedCategory,
                                    duration: uploadManager.videoDuration
                                )
                                HapticManager.shared.impact(style: .light)
                            }
                            Button("Suggest Tags") {
                                let tags = CreatorAssistService.suggestTags(
                                    title: uploadManager.title,
                                    description: uploadManager.description,
                                    category: uploadManager.selectedCategory
                                )
                                uploadManager.selectedTags.formUnion(tags)
                                HapticManager.shared.impact(style: .light)
                            }
                            Button("Suggest Description") {
                                uploadManager.description = CreatorAssistService.suggestDescription(
                                    from: uploadManager.title.isEmpty ? "Your Video" : uploadManager.title,
                                    category: uploadManager.selectedCategory
                                )
                                HapticManager.shared.impact(style: .light)
                            }
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.primary, in: Capsule())
                        }
                    }
                    
                    HStack {
                        Button {
                            do {
                                let draft = try UploadDraftStorage.shared.saveDraft(from: uploadManager)
                                restoreDraft = draft
                                HapticManager.shared.notification(type: .success)
                            } catch {
                                HapticManager.shared.notification(type: .warning)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "tray.and.arrow.down")
                                Text("Save Draft")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.surface, in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.Colors.divider.opacity(0.4), lineWidth: 1))
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 20) {
                    ProfessionalInputField(title: "Title", text: $uploadManager.title, placeholder: "Give your video a catchy title...", icon: "text.cursor", isRequired: true, maxLength: 100)
                    
                    ProfessionalTextEditor(title: "Description", text: $uploadManager.description, placeholder: "Tell viewers what your video is about...", icon: "text.bubble", maxLength: 500)
                    
                    ProfessionalPicker(title: "Category", selection: $uploadManager.selectedCategory, icon: "folder", options: VideoCategory.allCases)
                    
                    ProfessionalTagInput(title: "Tags", selectedTags: $uploadManager.selectedTags, icon: "tag")
                    
                    VStack(spacing: 16) {
                        Text("Privacy & Settings")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            ProfessionalToggleRow(title: "Public Video", subtitle: "Anyone can search for and view", icon: "globe", isOn: $uploadManager.isPublic)
                            ProfessionalToggleRow(title: "Enable Comments", subtitle: "Allow viewers to comment", icon: "bubble.left.and.bubble.right", isOn: .constant(true))
                            ProfessionalToggleRow(title: "Monetization", subtitle: "Earn revenue from this video", icon: "dollarsign.circle", isOn: $uploadManager.monetizationEnabled, isPremium: true)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
                
                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.impact(style: .heavy)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            uploadStep = .uploading
                        }
                        Task {
                            await uploadManager.uploadVideo()
                            if uploadManager.uploadError == nil {
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                                    uploadStep = .completed
                                    showingSuccessAnimation = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        showingSuccessAnimation = false
                                    }
                                }
                            } else {
                                withAnimation {
                                    uploadStep = .addDetails
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "icloud.and.arrow.up").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                            Text("Upload Video").font(.system(size: 18, weight: .semibold)).foregroundColor(.white);
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: uploadManager.title.isEmpty ? [AppTheme.Colors.textTertiary, AppTheme.Colors.textTertiary] : [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: uploadManager.title.isEmpty ? .clear : AppTheme.Colors.primary.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(uploadManager.title.isEmpty)
                    
                    Text("Make sure your title is engaging to attract more viewers!")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Uploading View
    private var uploadingView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle().stroke(AppTheme.Colors.surface, lineWidth: 12).frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: uploadManager.uploadProgress)
                        .stroke(
                            LinearGradient(colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: uploadManager.uploadProgress)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(uploadManager.uploadProgress * 100))%").font(.system(size: 32, weight: .bold)).foregroundColor(AppTheme.Colors.textPrimary)
                        Text("Uploading").font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                VStack(spacing: 8) {
                    Text("Processing Your Video").font(.system(size: 24, weight: .bold)).foregroundColor(AppTheme.Colors.textPrimary)
                    Text("We're optimizing your video for the best viewing experience")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            VStack(spacing: 12) {
                uploadStageRow(title: "Analyzing video", isCompleted: uploadManager.uploadProgress > 0.2, isActive: uploadManager.uploadProgress <= 0.2)
                uploadStageRow(title: "Optimizing quality", isCompleted: uploadManager.uploadProgress > 0.5, isActive: uploadManager.uploadProgress > 0.2 && uploadManager.uploadProgress <= 0.5)
                uploadStageRow(title: "Generating thumbnail", isCompleted: uploadManager.uploadProgress > 0.8, isActive: uploadManager.uploadProgress > 0.5 && uploadManager.uploadProgress <= 0.8)
                uploadStageRow(title: "Publishing video", isCompleted: uploadManager.uploadProgress >= 1.0, isActive: uploadManager.uploadProgress > 0.8)
            }
            .padding(.horizontal, 40)
            
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
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.green.opacity(0.2), .green.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(color: .green.opacity(0.3), radius: 20, x: 0, y: 10)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundColor(.green)
                        .scaleEffect(showingSuccessAnimation ? 1.2 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showingSuccessAnimation)
                }
                
                VStack(spacing: 8) {
                    Text("Video Published!").font(.system(size: 28, weight: .bold)).foregroundColor(AppTheme.Colors.textPrimary)
                    Text("Your video is now live and ready to inspire viewers around the world!")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            VStack(spacing: 16) {
                Button {
                    HapticManager.shared.impact(style: .medium)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                        Text("Watch Your Video").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                
                Button {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        uploadStep = .selectMedia
                    }
                    uploadManager.resetForm()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle").font(.system(size: 18, weight: .semibold)).foregroundColor(AppTheme.Colors.primary)
                        Text("Create Another Video").font(.system(size: 18, weight: .semibold)).foregroundColor(AppTheme.Colors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.Colors.primary, lineWidth: 2))
                }
                .buttonStyle(.plain)
                
                Button("Share Video") {
                    HapticManager.shared.impact(style: .light)
                }
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    private func uploadStageRow(title: String, isCompleted: Bool, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? .green : (isActive ? AppTheme.Colors.primary : AppTheme.Colors.surface))
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                } else if isActive {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.5)
                }
            }
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isCompleted ? .green : (isActive ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary))
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
        .animation(.easeInOut(duration: 0.3), value: isActive)
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
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(AppTheme.Colors.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(AppTheme.Colors.textSecondary)
                Text(value).font(.subheadline).fontWeight(.semibold).foregroundColor(AppTheme.Colors.textPrimary)
            }
            Spacer()
        }
        .padding(12)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - UI Pieces (unchanged below)

struct EditingToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.1)).frame(width: 50, height: 50)
                    Image(systemName: icon).font(.system(size: 22)).foregroundColor(color)
                }
                VStack(spacing: 4) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Colors.textPrimary)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
                    .onChange(of: text) { _, newValue in
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
                        .onChange(of: text) { _, newValue in
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
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Colors.textPrimary)
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(AppTheme.Colors.textTertiary).frame(width: 20)
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option.description).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Colors.primary)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1))
        }
    }
}

struct ProfessionalTagInput: View {
    let title: String
    @Binding var selectedTags: Set<String>
    let icon: String
    
    @State private var inputText = ""
    private let suggestedTags = ["Tutorial", "Educational", "Fun", "Music", "Gaming", "Tech", "Lifestyle", "Comedy", "Trending", "Creative"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Text("\(selectedTags.count)/10").font(.system(size: 12)).foregroundColor(selectedTags.count > 10 ? .red : AppTheme.Colors.textTertiary)
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(AppTheme.Colors.textTertiary).frame(width: 20)
                TextField("Add tags to help people discover your video", text: $inputText)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .onSubmit { addTag() }
                Button("Add") { addTag() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedTags.count >= 10)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1))
            
            if !selectedTags.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                        ProfessionalTagChip(tag: tag, isSelected: true) {
                            selectedTags.remove(tag)
                            HapticManager.shared.impact(style: .light)
                        }
                    }
                }
            }
            
            if !suggestedTags.filter({ !selectedTags.contains($0) }).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Tags").font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.Colors.textSecondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(suggestedTags.filter { !selectedTags.contains($0) }.prefix(6), id: \.self) { tag in
                            ProfessionalTagChip(tag: tag, isSelected: false) {
                                if selectedTags.count < 10 {
                                    selectedTags.insert(tag)
                                    HapticManager.shared.impact(style: .light)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let tag = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !selectedTags.contains(tag) && selectedTags.count < 10 {
            selectedTags.insert(tag)
            inputText = ""
            HapticManager.shared.impact(style: .light)
        }
    }
}

struct ProfessionalTagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(tag).font(.system(size: 14, weight: .medium)).lineLimit(1)
                Image(systemName: isSelected ? "xmark" : "plus").font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? .clear : AppTheme.Colors.divider.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

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
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
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

struct UploadCreationModeBar: View {
    @Binding var selected: UploadView.CreationMode
    let onTap: (UploadView.CreationMode) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(UploadView.CreationMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selected = mode
                    }
                    onTap(mode)
                } label: {
                    ZStack {
                        if selected == mode {
                            Capsule()
                                .fill(Color.white)
                                .frame(height: 36)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                        HStack(spacing: 8) {
                            Image(systemName: mode.icon).font(.system(size: 14, weight: .semibold))
                            Text(mode.title).font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .foregroundColor(selected == mode ? .black : .white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Capsule().fill(Color.black.opacity(0.85)))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Creation mode")
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

#Preview("UploadView") {
    UploadView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}