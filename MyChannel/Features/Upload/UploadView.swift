//
//  UploadView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import PhotosUI

struct UploadView: View {
    @State private var selectedMedia: PhotosPickerItem?
    @State private var mediaType: MediaType = .video
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var selectedCategory: VideoCategory = .entertainment
    @State private var isPublic: Bool = true
    @State private var enableComments: Bool = true
    @State private var enableLikes: Bool = true
    @State private var scheduledDate: Date?
    @State private var thumbnail: UIImage?
    @State private var isUploading: Bool = false
    @State private var uploadProgress: Double = 0.0
    @State private var showingSuccess: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Media Upload Section
                    MediaUploadSection(
                        selectedMedia: $selectedMedia,
                        mediaType: $mediaType,
                        thumbnail: $thumbnail
                    )
                    
                    // Content Details
                    ContentDetailsSection(
                        title: $title,
                        description: $description,
                        selectedCategory: $selectedCategory,
                        selectedTags: $selectedTags
                    )
                    
                    // Privacy & Settings
                    UploadPrivacySettingsSection(
                        isPublic: $isPublic,
                        enableComments: $enableComments,
                        enableLikes: $enableLikes,
                        scheduledDate: $scheduledDate
                    )
                    
                    // Upload Button
                    UploadButton(
                        isUploading: $isUploading,
                        uploadProgress: $uploadProgress,
                        canUpload: canUpload,
                        action: startUpload
                    )
                }
                .padding()
            }
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save Draft") {
                        // Save as draft
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showingSuccess) {
            UploadSuccessView()
        }
    }
    
    private var canUpload: Bool {
        selectedMedia != nil && !title.isEmpty && !description.isEmpty
    }
    
    private func startUpload() {
        isUploading = true
        uploadProgress = 0.0
        
        // Simulate upload progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            uploadProgress += 0.02
            
            if uploadProgress >= 1.0 {
                timer.invalidate()
                isUploading = false
                showingSuccess = true
                
                // Haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }
}

struct MediaUploadSection: View {
    @Binding var selectedMedia: PhotosPickerItem?
    @Binding var mediaType: MediaType
    @Binding var thumbnail: UIImage?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Upload Media")
                .font(AppTheme.Typography.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Media Type Selector
            Picker("Media Type", selection: $mediaType) {
                ForEach(MediaType.allCases, id: \.self) { type in
                    Text(type.displayName)
                        .tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // Upload Area
            PhotosPicker(selection: $selectedMedia, matching: mediaType.mediaFilter) {
                VStack(spacing: 16) {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(maxHeight: 200)
                            .cornerRadius(AppTheme.CornerRadius.lg)
                            .clipped()
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: mediaType.iconName)
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.Colors.primary)
                            
                            Text("Tap to select \(mediaType.displayName.lowercased())")
                                .font(AppTheme.Typography.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Recommended: \(mediaType.recommendations)")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                                .stroke(
                                    style: StrokeStyle(lineWidth: 2, dash: [8])
                                )
                                .foregroundColor(AppTheme.Colors.primary.opacity(0.3))
                        )
                    }
                }
            }
            .onChange(of: selectedMedia) { oldValue, newValue in
                // Handle media selection
                if let newValue = newValue {
                    // Load thumbnail/preview
                }
            }
        }
        .cardStyle()
    }
}

struct ContentDetailsSection: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var selectedCategory: VideoCategory
    @Binding var selectedTags: Set<String>
    
    @State private var availableTags: [String] = [
        "Tutorial", "Gaming", "Music", "Art", "Comedy", "Vlog", "Review",
        "Unboxing", "Cooking", "Fitness", "Travel", "Tech", "Fashion"
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Content Details")
                .font(AppTheme.Typography.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                TextField("Enter video title...", text: $title)
                    .textFieldStyle(UploadCustomTextFieldStyle())
                    .onChange(of: title) { oldValue, newValue in
                        if newValue.count > 100 {
                            title = String(newValue.prefix(100))
                        }
                    }
                
                HStack {
                    Spacer()
                    Text("\(title.count)/100")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                TextField("Tell viewers about your video...", text: $description, axis: .vertical)
                    .textFieldStyle(UploadCustomTextFieldStyle())
                    .lineLimit(4...8)
                    .onChange(of: description) { oldValue, newValue in
                        if newValue.count > 1000 {
                            description = String(newValue.prefix(1000))
                        }
                    }
                
                HStack {
                    Spacer()
                    Text("\(description.count)/1000")
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(VideoCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.iconName)
                            Text(category.displayName)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 12) {
                Text("Tags")
                    .font(AppTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(availableTags, id: \.self) { tag in
                        TagChip(
                            title: tag,
                            isSelected: selectedTags.contains(tag),
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else if selectedTags.count < 5 {
                                        selectedTags.insert(tag)
                                    }
                                }
                            }
                        )
                    }
                }
                
                Text("Select up to 5 tags (\(selectedTags.count)/5)")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
        }
        .cardStyle()
    }
}

struct UploadPrivacySettingsSection: View {
    @Binding var isPublic: Bool
    @Binding var enableComments: Bool
    @Binding var enableLikes: Bool
    @Binding var scheduledDate: Date?
    
    @State private var isScheduled: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Privacy & Settings")
                .font(AppTheme.Typography.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Visibility
            VStack(spacing: 12) {
                HStack {
                    Text("Visibility")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                }
                
                VStack(spacing: 0) {
                    UploadSettingRow(
                        icon: "globe",
                        title: "Public",
                        description: "Anyone can see your video",
                        isSelected: isPublic,
                        action: { isPublic = true }
                    )
                    
                    Divider()
                        .padding(.leading, 44)
                    
                    UploadSettingRow(
                        icon: "lock",
                        title: "Private",
                        description: "Only you can see your video",
                        isSelected: !isPublic,
                        action: { isPublic = false }
                    )
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
            
            // Interaction Settings
            VStack(spacing: 12) {
                HStack {
                    Text("Interaction")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                }
                
                VStack(spacing: 0) {
                    UploadToggleRow(
                        icon: "bubble.right",
                        title: "Allow Comments",
                        isOn: $enableComments
                    )
                    
                    Divider()
                        .padding(.leading, 44)
                    
                    UploadToggleRow(
                        icon: "heart",
                        title: "Allow Likes",
                        isOn: $enableLikes
                    )
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
            
            // Schedule
            VStack(spacing: 12) {
                HStack {
                    Text("Schedule")
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                }
                
                VStack(spacing: 0) {
                    UploadToggleRow(
                        icon: "calendar",
                        title: "Schedule for later",
                        isOn: $isScheduled
                    )
                    
                    if isScheduled {
                        Divider()
                            .padding(.leading, 44)
                        
                        DatePicker(
                            "Publish Date",
                            selection: Binding(
                                get: { scheduledDate ?? Date().addingTimeInterval(3600) },
                                set: { scheduledDate = $0 }
                            ),
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(CompactDatePickerStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .background(AppTheme.Colors.surface)
                .cornerRadius(AppTheme.CornerRadius.md)
            }
        }
        .cardStyle()
        .onChange(of: isScheduled) { oldValue, newValue in
            if !newValue {
                scheduledDate = nil
            }
        }
    }
}

struct UploadButton: View {
    @Binding var isUploading: Bool
    @Binding var uploadProgress: Double
    let canUpload: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    
                    Text("Uploading... \(Int(uploadProgress * 100))%")
                        .font(AppTheme.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "cloud.upload")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Upload Video")
                        .font(AppTheme.Typography.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                ZStack {
                    if canUpload && !isUploading {
                        AppTheme.Colors.gradient
                    } else {
                        AppTheme.Colors.textTertiary
                    }
                    
                    if isUploading {
                        // Progress background
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: geometry.size.width * uploadProgress)
                        }
                    }
                }
            )
            .cornerRadius(AppTheme.CornerRadius.lg)
            .disabled(!canUpload || isUploading)
            .scaleEffect(isUploading ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isUploading)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Views

struct UploadCustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(AppTheme.Colors.surface)
            .cornerRadius(AppTheme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(AppTheme.Colors.divider, lineWidth: 1)
            )
    }
}

struct TagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface
                )
                .foregroundColor(
                    isSelected ? .white : AppTheme.Colors.textPrimary
                )
                .cornerRadius(AppTheme.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                        .stroke(
                            isSelected ? AppTheme.Colors.primary : AppTheme.Colors.divider,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

struct UploadSettingRow: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(description)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UploadToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24)
            
            Text(title)
                .font(AppTheme.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding()
    }
}

struct UploadSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.success.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.success)
            }
            
            VStack(spacing: 16) {
                Text("Upload Successful!")
                    .font(AppTheme.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Your video has been uploaded and is now processing. You'll receive a notification when it's ready to view.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button("View Video") {
                    // Navigate to video
                    dismiss()
                }
                .primaryButtonStyle()
                
                Button("Upload Another") {
                    dismiss()
                }
                .secondaryButtonStyle()
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Supporting Types

enum MediaType: String, CaseIterable {
    case video = "video"
    case short = "short"
    case audio = "audio"
    
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .short: return "Short"
        case .audio: return "Audio"
        }
    }
    
    var iconName: String {
        switch self {
        case .video: return "video"
        case .short: return "bolt"
        case .audio: return "waveform"
        }
    }
    
    var recommendations: String {
        switch self {
        case .video: return "16:9 aspect ratio, 1080p or higher"
        case .short: return "9:16 aspect ratio, under 60 seconds"
        case .audio: return "High quality audio, MP3 or WAV"
        }
    }
    
    var mediaFilter: PHPickerFilter {
        switch self {
        case .video, .short: return .videos
        case .audio: return .any(of: [.videos]) // Audio would need custom handling
        }
    }
}

#Preview {
    UploadView()
}