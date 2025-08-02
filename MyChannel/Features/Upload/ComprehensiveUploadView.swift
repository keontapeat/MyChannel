//
//  ComprehensiveUploadView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct ComprehensiveUploadView: View {
    @StateObject private var uploadManager = VideoUploadManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingMediaPicker = false
    @State private var showingCamera = false
    @State private var uploadStep: UploadStep = .selectMedia
    
    enum UploadStep {
        case selectMedia
        case editVideo
        case addDetails
        case uploading
        case completed
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    uploadProgressHeader
                    
                    // Main content based on step
                    switch uploadStep {
                    case .selectMedia:
                        mediaSelectionView
                    case .editVideo:
                        videoEditingView
                    case .addDetails:
                        videoDetailsView
                    case .uploading:
                        uploadingView
                    case .completed:
                        completedView
                    }
                }
            }
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: navigationTrailingButton
            )
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPickerView { pickerItem in
                uploadManager.selectedVideo = pickerItem
                uploadStep = .editVideo
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView { videoURL in
                uploadManager.videoURL = videoURL
                uploadStep = .editVideo
            }
        }
        .onChange(of: uploadManager.selectedVideo) { oldValue, newValue in
            if newValue != nil {
                Task {
                    await uploadManager.loadSelectedVideo()
                    if uploadManager.uploadError == nil {
                        uploadStep = .addDetails
                    }
                }
            }
        }
    }
    
    // MARK: - Progress Header
    private var uploadProgressHeader: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(0..<4) { index in
                    Rectangle()
                        .fill(index <= stepIndex ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.3), value: stepIndex)
                }
            }
            .padding(.horizontal)
            
            Text(stepTitle)
                .font(.headline)
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
        .padding(.vertical)
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
        case .selectMedia: return "Select Media"
        case .editVideo: return "Edit Video"
        case .addDetails: return "Add Details"
        case .uploading: return "Uploading..."
        case .completed: return "Upload Complete!"
        }
    }
    
    // MARK: - Media Selection View
    private var mediaSelectionView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Create Your Video")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Choose how you want to create your content")
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                // Record with camera
                Button(action: { showingCamera = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Record")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Use your camera to record")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(AppTheme.Colors.primary)
                    .cornerRadius(12)
                }
                
                // Upload from gallery
                Button(action: { showingMediaPicker = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                            .foregroundColor(AppTheme.Colors.primary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upload")
                                .font(.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Choose from your gallery")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Create Short
                Button(action: { 
                    // Handle short creation
                    showingCamera = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Short")
                                .font(.headline)
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            Text("Quick vertical videos")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Video Editing View
    private var videoEditingView: some View {
        VStack(spacing: 20) {
            // Video preview
            if let thumbnail = uploadManager.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.Colors.primary))
                    )
            }
            
            // Basic editing tools
            VStack(spacing: 16) {
                Text("Basic Editing")
                    .font(.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 16) {
                    Button("Trim") {
                        // Handle trim
                    }
                    .buttonStyle(EditingButtonStyle())
                    
                    Button("Filter") {
                        // Handle filter
                    }
                    .buttonStyle(EditingButtonStyle())
                    
                    Button("Music") {
                        // Handle music
                    }
                    .buttonStyle(EditingButtonStyle())
                    
                    Button("Text") {
                        // Handle text
                    }
                    .buttonStyle(EditingButtonStyle())
                }
            }
            .padding()
            
            Spacer()
            
            // Continue button
            Button("Continue") {
                uploadStep = .addDetails
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal)
        }
    }
    
    // MARK: - Video Details View
    private var videoDetailsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Thumbnail preview
                if let thumbnail = uploadManager.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(12)
                        .frame(maxWidth: 200)
                }
                
                VStack(spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title *")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        TextField("Enter video title", text: $uploadManager.title)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        TextField("Tell viewers about your video", text: $uploadManager.description, axis: .vertical)
                            .textFieldStyle(CustomTextFieldStyle())
                            .lineLimit(5...10)
                    }
                    
                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Picker("Category", selection: $uploadManager.selectedCategory) {
                            ForEach(VideoCategory.allCases, id: \.self) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding()
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(8)
                    }
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        TagInputView(selectedTags: $uploadManager.selectedTags)
                    }
                    
                    // Visibility
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visibility")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Toggle("Public", isOn: $uploadManager.isPublic)
                            .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                    }
                    
                    // Monetization
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monetization")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Toggle("Enable monetization", isOn: $uploadManager.monetizationEnabled)
                            .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary))
                    }
                }
                .padding(.horizontal)
                
                // Upload button
                Button("Upload Video") {
                    uploadStep = .uploading
                    Task {
                        await uploadManager.uploadVideo()
                        if uploadManager.uploadError == nil {
                            uploadStep = .completed
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(uploadManager.title.isEmpty)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Uploading View
    private var uploadingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(AppTheme.Colors.surface, lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: uploadManager.uploadProgress)
                        .stroke(AppTheme.Colors.primary, lineWidth: 8)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: uploadManager.uploadProgress)
                    
                    Text("\(Int(uploadManager.uploadProgress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                VStack(spacing: 8) {
                    Text("Uploading your video...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("This may take a few minutes depending on your file size")
                        .font(.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let error = uploadManager.uploadError {
                VStack(spacing: 16) {
                    Text("Upload Failed")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error)
                        .font(.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task {
                            await uploadManager.uploadVideo()
                            if uploadManager.uploadError == nil {
                                uploadStep = .completed
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Completed View
    private var completedView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                Text("Upload Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Your video has been uploaded successfully and is now processing.")
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                Button("View Video") {
                    // Navigate to video
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Upload Another") {
                    uploadStep = .selectMedia
                    uploadManager.selectedVideo = nil
                    uploadManager.videoData = nil
                    uploadManager.thumbnail = nil
                    uploadManager.title = ""
                    uploadManager.description = ""
                    uploadManager.selectedTags.removeAll()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Navigation Trailing Button
    private var navigationTrailingButton: some View {
        Group {
            switch uploadStep {
            case .editVideo:
                Button("Skip") {
                    uploadStep = .addDetails
                }
            case .addDetails:
                Button("Upload") {
                    uploadStep = .uploading
                    Task {
                        await uploadManager.uploadVideo()
                        if uploadManager.uploadError == nil {
                            uploadStep = .completed
                        }
                    }
                }
                .disabled(uploadManager.title.isEmpty)
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Supporting Views
struct MediaPickerView: View {
    let onSelection: (PhotosPickerItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            PhotosPicker(
                selection: $selectedItem,
                matching: .videos
            ) {
                VStack(spacing: 16) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(AppTheme.Colors.primary)
                    
                    Text("Select Video")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose a video from your library")
                        .font(.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .navigationTitle("Select Media")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            if let item = newValue {
                onSelection(item)
                dismiss()
            }
        }
    }
}

struct CameraView: View {
    let onCapture: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // Placeholder for camera implementation
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("Camera Feature")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Camera recording will be implemented here")
                    .font(.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Button("Simulate Recording") {
                    // Simulate video capture
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("recorded_video.mp4")
                    onCapture(tempURL)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Spacer()
            }
            .padding()
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct TagInputView: View {
    @Binding var selectedTags: Set<String>
    @State private var inputText = ""
    
    private let suggestedTags = ["Tutorial", "Educational", "Fun", "Music", "Gaming", "Tech", "Lifestyle", "Comedy"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tag input field
            HStack {
                TextField("Add tags", text: $inputText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        addTag()
                    }
                
                Button("Add") {
                    addTag()
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(AppTheme.Colors.surface)
            .cornerRadius(8)
            
            // Selected tags
            if !selectedTags.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(Array(selectedTags), id: \.self) { tag in
                        TagChip(tag: tag, isSelected: true) {
                            selectedTags.remove(tag)
                        }
                    }
                }
            }
            
            // Suggested tags
            Text("Suggested:")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(suggestedTags.filter { !selectedTags.contains($0) }, id: \.self) { tag in
                    TagChip(tag: tag, isSelected: false) {
                        selectedTags.insert(tag)
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let tag = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty && !selectedTags.contains(tag) {
            selectedTags.insert(tag)
            inputText = ""
        }
    }
}

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tag)
                    .font(.caption)
                    .lineLimit(1)
                
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Button Styles
struct EditingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.surface)
            .foregroundColor(AppTheme.Colors.textPrimary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.Colors.primary)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(AppTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.Colors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.Colors.primary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(AppTheme.Colors.surface)
            .cornerRadius(8)
    }
}

#Preview {
    ComprehensiveUploadView()
}