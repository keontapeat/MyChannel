//
//  UploadView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Professional Upload View with Cutting-Edge Design
struct UploadView: View {
    @StateObject private var uploadManager = VideoUploadManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingMediaPicker = false
    @State private var showingCamera = false
    @State private var uploadStep: UploadStep = .selectMedia
    @State private var showingSuccessAnimation = false
    @State private var dragOffset = CGSize.zero
    @State private var isAnimating = false
    
    enum UploadStep {
        case selectMedia
        case editVideo
        case addDetails
        case uploading
        case completed
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic gradient background
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
                
                VStack(spacing: 0) {
                    // Enhanced progress header with animations
                    enhancedProgressHeader
                    
                    // Main content with smooth transitions
                    ZStack {
                        switch uploadStep {
                        case .selectMedia:
                            mediaSelectionView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        case .editVideo:
                            videoEditingView
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
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
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                        }
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: uploadStep)
                }
                
                // Success celebration overlay
                if showingSuccessAnimation {
                    successCelebrationOverlay
                        .zIndex(1000)
                }
            }
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        dismiss()
                    }) {
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
        }
        .sheet(isPresented: $showingMediaPicker) {
            EnhancedMediaPickerView { pickerItem in
                uploadManager.selectedVideo = pickerItem
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    uploadStep = .editVideo
                }
                HapticManager.shared.impact(style: .medium)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            ProfessionalCameraView { videoURL in
                uploadManager.videoURL = videoURL
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    uploadStep = .editVideo
                }
                HapticManager.shared.impact(style: .medium)
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
    
    // MARK: - Enhanced Progress Header
    private var enhancedProgressHeader: some View {
        VStack(spacing: 16) {
            // Progress dots with smooth animations
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
            
            // Step title with typewriter effect
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
            
            // Step description
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
        case .editVideo: return 1
        case .addDetails: return 2
        case .uploading, .completed: return 3
        }
    }
    
    private var stepTitle: String {
        switch uploadStep {
        case .selectMedia: return "Choose Your Content"
        case .editVideo: return "Perfect Your Video"
        case .addDetails: return "Add the Finishing Touches"
        case .uploading: return "Publishing Your Creation"
        case .completed: return "🎉 Success!"
        }
    }
    
    private var stepDescription: String {
        switch uploadStep {
        case .selectMedia: return "Select the perfect way to create your content"
        case .editVideo: return "Fine-tune your video with professional editing tools"
        case .addDetails: return "Help viewers discover your amazing content"
        case .uploading: return "Your video is being processed and uploaded"
        case .completed: return "Your video is live and ready to inspire!"
        }
    }
    
    // MARK: - Enhanced Media Selection View
    private var mediaSelectionView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero section with animated icon
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary.opacity(0.2), AppTheme.Colors.secondary.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(AppTheme.Colors.primary)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Create Something Amazing")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Share your story with the world")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                
                // Creation options with enhanced design
                VStack(spacing: 16) {
                    // Record with camera - Primary action
                    EnhancedCreationButton(
                        title: "Record Video",
                        subtitle: "Capture moments in real-time",
                        icon: "camera.fill",
                        gradient: LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        foregroundColor: .white,
                        isPrimary: true
                    ) {
                        HapticManager.shared.impact(style: .medium)
                        showingCamera = true
                    }
                    
                    // Upload from gallery
                    EnhancedCreationButton(
                        title: "Upload from Gallery",
                        subtitle: "Choose from your saved videos",
                        icon: "photo.on.rectangle.angled",
                        gradient: LinearGradient(
                            colors: [AppTheme.Colors.surface, AppTheme.Colors.surface],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        foregroundColor: AppTheme.Colors.textPrimary,
                        isPrimary: false
                    ) {
                        HapticManager.shared.impact(style: .light)
                        showingMediaPicker = true
                    }
                    
                    // Create Short - Special highlight
                    EnhancedCreationButton(
                        title: "Create Short",
                        subtitle: "Quick vertical videos up to 60s",
                        icon: "bolt.fill",
                        gradient: LinearGradient(
                            colors: [.orange.opacity(0.1), .orange.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        foregroundColor: .orange,
                        isPrimary: false,
                        specialBadge: "HOT"
                    ) {
                        HapticManager.shared.impact(style: .light)
                        showingCamera = true
                    }
                    
                    // Go Live - Premium feature
                    EnhancedCreationButton(
                        title: "Go Live",
                        subtitle: "Stream live to your audience",
                        icon: "dot.radiowaves.left.and.right",
                        gradient: LinearGradient(
                            colors: [.red.opacity(0.1), .red.opacity(0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        foregroundColor: .red,
                        isPrimary: false,
                        specialBadge: "LIVE"
                    ) {
                        HapticManager.shared.impact(style: .light)
                        // Handle live streaming
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    // MARK: - Enhanced Video Editing View
    private var videoEditingView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Video preview with professional styling
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
                        
                        // Play button overlay
                        Button(action: {
                            // Handle play preview
                            HapticManager.shared.impact(style: .light)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.black.opacity(0.6))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: uploadManager.thumbnail)
                    }
                }
                .padding(.horizontal, 20)
                
                // Professional editing tools
                VStack(spacing: 20) {
                    Text("Editing Tools")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        EditingToolCard(
                            title: "Trim & Cut",
                            subtitle: "Perfect timing",
                            icon: "scissors",
                            color: .blue
                        ) {
                            HapticManager.shared.impact(style: .light)
                            // Handle trim
                        }
                        
                        EditingToolCard(
                            title: "Filters",
                            subtitle: "Visual effects",
                            icon: "camera.filters",
                            color: .purple
                        ) {
                            HapticManager.shared.impact(style: .light)
                            // Handle filters
                        }
                        
                        EditingToolCard(
                            title: "Add Music",
                            subtitle: "Perfect soundtrack",
                            icon: "music.note",
                            color: .green
                        ) {
                            HapticManager.shared.impact(style: .light)
                            // Handle music
                        }
                        
                        EditingToolCard(
                            title: "Text & Titles",
                            subtitle: "Engaging captions",
                            icon: "text.bubble",
                            color: .orange
                        ) {
                            HapticManager.shared.impact(style: .light)
                            // Handle text
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
                
                // Enhanced continue button
                VStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            uploadStep = .addDetails
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
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
    
    // MARK: - Enhanced Video Details View
    private var videoDetailsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Thumbnail preview
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
                
                VStack(spacing: 20) {
                    // Enhanced title input
                    ProfessionalInputField(
                        title: "Title",
                        text: $uploadManager.title,
                        placeholder: "Give your video a catchy title...",
                        icon: "text.cursor",
                        isRequired: true,
                        maxLength: 100
                    )
                    
                    // Enhanced description input
                    ProfessionalTextEditor(
                        title: "Description",
                        text: $uploadManager.description,
                        placeholder: "Tell viewers what your video is about...",
                        icon: "text.bubble",
                        maxLength: 500
                    )
                    
                    // Category selector with enhanced UI
                    ProfessionalPicker(
                        title: "Category",
                        selection: $uploadManager.selectedCategory,
                        icon: "folder",
                        options: VideoCategory.allCases
                    )
                    
                    // Enhanced tags input
                    ProfessionalTagInput(
                        title: "Tags",
                        selectedTags: $uploadManager.selectedTags,
                        icon: "tag"
                    )
                    
                    // Visibility settings with enhanced toggles
                    VStack(spacing: 16) {
                        Text("Privacy & Settings")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 12) {
                            ProfessionalToggleRow(
                                title: "Public Video",
                                subtitle: "Anyone can search for and view",
                                icon: "globe",
                                isOn: $uploadManager.isPublic
                            )
                            
                            ProfessionalToggleRow(
                                title: "Enable Comments",
                                subtitle: "Allow viewers to comment",
                                icon: "bubble.left.and.bubble.right",
                                isOn: .constant(true)
                            )
                            
                            ProfessionalToggleRow(
                                title: "Monetization",
                                subtitle: "Earn revenue from this video",
                                icon: "dollarsign.circle",
                                isOn: $uploadManager.monetizationEnabled,
                                isPremium: true
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
                
                // Enhanced upload button
                VStack(spacing: 12) {
                    Button(action: {
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
                                
                                // Hide success animation after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        showingSuccessAnimation = false
                                    }
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "icloud.and.arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Upload Video")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: uploadManager.title.isEmpty ? 
                                    [AppTheme.Colors.textTertiary, AppTheme.Colors.textTertiary] :
                                    [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(
                            color: uploadManager.title.isEmpty ? .clear : AppTheme.Colors.primary.opacity(0.4),
                            radius: 15,
                            x: 0,
                            y: 8
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Enhanced Uploading View
    private var uploadingView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Enhanced progress circle
            VStack(spacing: 24) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(AppTheme.Colors.surface, lineWidth: 12)
                        .frame(width: 160, height: 160)
                    
                    // Progress circle with gradient
                    Circle()
                        .trim(from: 0, to: uploadManager.uploadProgress)
                        .stroke(
                            LinearGradient(
                                colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: uploadManager.uploadProgress)
                    
                    // Progress text
                    VStack(spacing: 4) {
                        Text("\(Int(uploadManager.uploadProgress * 100))%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Uploading")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                VStack(spacing: 8) {
                    Text("Processing Your Video")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("We're optimizing your video for the best viewing experience")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            // Upload stages
            VStack(spacing: 12) {
                uploadStageRow(title: "Analyzing video", isCompleted: uploadManager.uploadProgress > 0.2, isActive: uploadManager.uploadProgress <= 0.2)
                uploadStageRow(title: "Optimizing quality", isCompleted: uploadManager.uploadProgress > 0.5, isActive: uploadManager.uploadProgress > 0.2 && uploadManager.uploadProgress <= 0.5)
                uploadStageRow(title: "Generating thumbnail", isCompleted: uploadManager.uploadProgress > 0.8, isActive: uploadManager.uploadProgress > 0.5 && uploadManager.uploadProgress <= 0.8)
                uploadStageRow(title: "Publishing video", isCompleted: uploadManager.uploadProgress >= 1.0, isActive: uploadManager.uploadProgress > 0.8)
            }
            .padding(.horizontal, 40)
            
            if let error = uploadManager.uploadError {
                VStack(spacing: 16) {
                    Text("Upload Failed")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.red)
                    
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
    
    // MARK: - Enhanced Completed View
    private var completedView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.2), .green.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: .green.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64, weight: .medium))
                        .foregroundColor(.green)
                        .scaleEffect(showingSuccessAnimation ? 1.2 : 1.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showingSuccessAnimation)
                }
                
                VStack(spacing: 8) {
                    Text("Video Published!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Your video is now live and ready to inspire viewers around the world!")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            // Action buttons
            VStack(spacing: 16) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    // Navigate to video
                    dismiss()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Watch Your Video")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    // Reset for new upload
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        uploadStep = .selectMedia
                    }
                    uploadManager.selectedVideo = nil
                    uploadManager.videoData = nil
                    uploadManager.thumbnail = nil
                    uploadManager.title = ""
                    uploadManager.description = ""
                    uploadManager.selectedTags.removeAll()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        Text("Create Another Video")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.Colors.primary, lineWidth: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button("Share Video") {
                    HapticManager.shared.impact(style: .light)
                    // Handle sharing
                }
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Success Celebration Overlay
    private var successCelebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 80))
                    .scaleEffect(showingSuccessAnimation ? 1.2 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: showingSuccessAnimation)
                
                Text("Success!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(showingSuccessAnimation ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.5).delay(0.2), value: showingSuccessAnimation)
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Views
    private func uploadStageRow(title: String, isCompleted: Bool, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? .green : (isActive ? AppTheme.Colors.primary : AppTheme.Colors.surface))
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else if isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.5)
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
    
    // MARK: - Navigation Trailing Button
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
}

// MARK: - Enhanced Creation Button
struct EnhancedCreationButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    let foregroundColor: Color
    let isPrimary: Bool
    let specialBadge: String?
    let action: () -> Void
    
    init(title: String, subtitle: String, icon: String, gradient: LinearGradient, foregroundColor: Color, isPrimary: Bool, specialBadge: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.gradient = gradient
        self.foregroundColor = foregroundColor
        self.isPrimary = isPrimary
        self.specialBadge = specialBadge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon with background
                ZStack {
                    Circle()
                        .fill(isPrimary ? .white.opacity(0.2) : foregroundColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(foregroundColor)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(foregroundColor)
                        
                        if let badge = specialBadge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(foregroundColor)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(foregroundColor.opacity(0.8))
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foregroundColor.opacity(0.6))
            }
            .padding(20)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(foregroundColor.opacity(isPrimary ? 0.0 : 0.3), lineWidth: isPrimary ? 0 : 1)
            )
            .shadow(
                color: isPrimary ? foregroundColor.opacity(0.3) : .clear,
                radius: isPrimary ? 15 : 0,
                x: 0,
                y: isPrimary ? 8 : 0
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Additional Professional Components
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
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
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
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                if isRequired {
                    Text("*")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                Text("\(text.count)/\(maxLength)")
                    .font(.system(size: 12))
                    .foregroundColor(text.count > maxLength ? .red : AppTheme.Colors.textTertiary)
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                    .frame(width: 20)
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        if newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isFocused ? 2 : 1)
            )
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
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(text.count)/\(maxLength)")
                    .font(.system(size: 12))
                    .foregroundColor(text.count > maxLength ? .red : AppTheme.Colors.textTertiary)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                        .frame(width: 20)
                    
                    Text("Description")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
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
                            if newValue.count > maxLength {
                                text = String(newValue.prefix(maxLength))
                            }
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
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isFocused ? 2 : 1)
            )
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
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .frame(width: 20)
                
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option.description).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .tint(AppTheme.Colors.primary)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
            )
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
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(selectedTags.count)/10")
                    .font(.system(size: 12))
                    .foregroundColor(selectedTags.count > 10 ? .red : AppTheme.Colors.textTertiary)
            }
            
            // Tag input field
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textTertiary)
                    .frame(width: 20)
                
                TextField("Add tags to help people discover your video", text: $inputText)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .onSubmit {
                        addTag()
                    }
                
                Button("Add") {
                    addTag()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.Colors.primary)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedTags.count >= 10)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
            )
            
            // Selected tags
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
            
            // Suggested tags
            if !suggestedTags.filter({ !selectedTags.contains($0) }).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Tags")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
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
                Text(tag)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? .clear : AppTheme.Colors.divider.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
            // Icon
            ZStack {
                Circle()
                    .fill(isOn ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface)
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isOn ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    if isPremium {
                        Text("PRO")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ProfessionalButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary
    }
    
    let style: Style
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Enhanced Media Picker and Camera Views
struct EnhancedMediaPickerView: View {
    let onSelection: (PhotosPickerItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Select Your Video")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Choose a video from your library to upload")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Browse Gallery")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.Colors.primary.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.vertical, 40)
            .navigationTitle("Select Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            if let item = newValue {
                onSelection(item)
                dismiss()
            }
        }
    }
}

struct ProfessionalCameraView: View {
    let onCapture: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                        
                        Text("Camera Ready")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Camera functionality will be implemented here with AVFoundation")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Button(action: {
                        // Simulate video capture
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("recorded_video.mp4")
                        onCapture(tempURL)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "record.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Simulate Recording")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    UploadView()
}