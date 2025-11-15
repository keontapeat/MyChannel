//
//  MatchResultSubmissionView.swift
//  MyChannel
//
//  Video Proof Upload Interface for Gaming Matches
//  Professional YouTube-level design
//

import SwiftUI
import PhotosUI
import AVFoundation

struct MatchResultSubmissionView: View {
    let match: BracketMatch
    @StateObject private var uploadService = MatchProofUploadService.shared
    @StateObject private var verificationService = MatchVerificationService.shared
    @Environment(\.dismiss) private var dismiss
    
    // Upload state
    @State private var selectedVideoURL: URL?
    @State private var videoThumbnail: UIImage?
    @State private var selectedScreenshot: UIImage?
    @State private var showingVideoPicker = false
    @State private var showingScreenshotPicker = false
    @State private var showingImagePicker = false
    
    // Score input
    @State private var yourScore: String = ""
    @State private var opponentScore: String = ""
    
    // UI state
    @State private var uploadStep: UploadStep = .selectVideo
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAnalyzing = false
    @State private var analysisProgress: AnalysisProgress?
    
    enum UploadStep {
        case selectVideo
        case enterScores
        case uploading
        case analyzing
        case complete
    }
    
    struct AnalysisProgress {
        var videoReceived = false
        var extractingFrames = false
        var readingScoreboard = false
        var verifying = false
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Main content based on step
                        switch uploadStep {
                        case .selectVideo:
                            videoSelectionSection
                        case .enterScores:
                            scoreInputSection
                        case .uploading:
                            uploadProgressSection
                        case .analyzing:
                            analysisProgressSection
                        case .complete:
                            completionSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Submit Match Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if uploadService.isUploading {
                            uploadService.cancelUpload()
                        }
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Match info
            HStack(spacing: 12) {
                // Game icon
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.team1.name + " vs " + match.team2.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("Submit your match proof")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
            )
            
            // Instructions
            instructionsCard
        }
    }
    
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                Text("How to Submit")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                instructionRow(icon: "video.fill", text: "Record 2-5 min showing final scoreboard")
                instructionRow(icon: "checkmark.circle.fill", text: "Formats: MP4, MOV, AVI (Max 500MB)")
                instructionRow(icon: "eye.fill", text: "AI verifies scores automatically")
                instructionRow(icon: "dollarsign.circle.fill", text: "Get paid instantly if verified")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.primary.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
    
    // MARK: - Video Selection Section
    
    private var videoSelectionSection: some View {
        VStack(spacing: 16) {
            // Upload area
            if let videoURL = selectedVideoURL, let thumbnail = videoThumbnail {
                // Video preview
                videoPreviewCard(url: videoURL, thumbnail: thumbnail)
            } else {
                // Upload prompt
                videoUploadPrompt
            }
            
            // Optional screenshot
            screenshotUploadSection
            
            // Next button
            if selectedVideoURL != nil {
                Button(action: proceedToScoreEntry) {
                    HStack(spacing: 8) {
                        Text("Next: Enter Scores")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primary)
                    )
                }
            }
        }
    }
    
    private var videoUploadPrompt: some View {
        Button(action: { showingVideoPicker = true }) {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.primary.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                VStack(spacing: 6) {
                    Text("Tap to Select Video")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("or drag & drop video here")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                // Format info
                HStack(spacing: 16) {
                    formatBadge(icon: "checkmark.circle.fill", text: "MP4, MOV, AVI")
                    formatBadge(icon: "clock.fill", text: "Max 5 min")
                    formatBadge(icon: "externaldrive.fill", text: "Max 500MB")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                            )
                            .foregroundColor(AppTheme.Colors.primary.opacity(0.3))
                    )
            )
        }
        .sheet(isPresented: $showingVideoPicker) {
            VideoPicker(videoURL: $selectedVideoURL, thumbnail: $videoThumbnail)
        }
    }
    
    private func formatBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(AppTheme.Colors.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.Colors.primary.opacity(0.1))
        )
    }
    
    private func videoPreviewCard(url: URL, thumbnail: UIImage) -> some View {
        VStack(spacing: 12) {
            // Thumbnail
            Image(uiImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    // Play icon overlay
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                )
            
            // File info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    if let fileSize = getFileSize(url: url) {
                        Text(fileSize)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Change video button
                Button(action: { showingVideoPicker = true }) {
                    Text("Change")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.surface)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
        )
    }
    
    private var screenshotUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screenshot (Optional)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if let screenshot = selectedScreenshot {
                // Screenshot preview
                HStack(spacing: 12) {
                    Image(uiImage: screenshot)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screenshot attached")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("Backup proof of scoreboard")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { selectedScreenshot = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.Colors.surface)
                )
            } else {
                // Upload button
                Button(action: { showingImagePicker = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Add Screenshot")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .sheet(isPresented: $showingImagePicker) {
                    ImagePicker(image: $selectedScreenshot)
                }
            }
        }
    }
    
    // MARK: - Score Input Section
    
    private var scoreInputSection: some View {
        VStack(spacing: 20) {
            // Back button
            HStack {
                Button(action: { uploadStep = .selectVideo }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Score inputs
            VStack(spacing: 16) {
                scoreInputField(
                    label: "Your Score",
                    placeholder: "Enter your score",
                    text: $yourScore,
                    icon: "person.fill"
                )
                
                scoreInputField(
                    label: "Opponent's Score",
                    placeholder: "Enter opponent's score",
                    text: $opponentScore,
                    icon: "person.2.fill"
                )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
            )
            
            // Submit button
            Button(action: submitMatchResult) {
                HStack(spacing: 8) {
                    if uploadService.isUploading {
                        ProgressView()
                            .tint(.white)
                    }
                    
                    Text(uploadService.isUploading ? "Submitting..." : "Submit Match Result")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(canSubmit ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                )
            }
            .disabled(!canSubmit || uploadService.isUploading)
        }
    }
    
    private func scoreInputField(label: String, placeholder: String, text: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.Colors.background)
                )
        }
    }
    
    // MARK: - Upload Progress Section
    
    private var uploadProgressSection: some View {
        VStack(spacing: 24) {
            // Upload icon
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(spacing: 8) {
                Text("Uploading...")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Please wait while we upload your video")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppTheme.Colors.surface)
                            .frame(height: 12)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * uploadService.uploadProgress, height: 12)
                    }
                }
                .frame(height: 12)
                
                HStack {
                    Text("\(Int(uploadService.uploadProgress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    if let totalSize = getFileSize(url: selectedVideoURL!) {
                        Text(totalSize)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
            )
            
            // Cancel button
            Button(action: {
                uploadService.cancelUpload()
                dismiss()
            }) {
                Text("Cancel Upload")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Analysis Progress Section
    
    private var analysisProgressSection: some View {
        VStack(spacing: 24) {
            // AI icon
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "brain")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(AppTheme.Colors.primary)
            }
            
            VStack(spacing: 8) {
                Text("🤖 AI Referee Analyzing...")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("This may take 30-60 seconds")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            // Progress steps
            if let progress = analysisProgress {
                VStack(spacing: 12) {
                    analysisStep(
                        icon: "checkmark.circle.fill",
                        text: "Video received",
                        completed: progress.videoReceived
                    )
                    
                    analysisStep(
                        icon: progress.extractingFrames ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill",
                        text: "Extracting frames",
                        completed: progress.extractingFrames || progress.readingScoreboard
                    )
                    
                    analysisStep(
                        icon: progress.readingScoreboard ? "arrow.triangle.2.circlepath" : "circle",
                        text: "Reading scoreboard...",
                        completed: progress.readingScoreboard
                    )
                    
                    analysisStep(
                        icon: "circle",
                        text: "Verifying scores",
                        completed: progress.verifying
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.surface)
                )
            }
        }
        .padding(.vertical, 40)
    }
    
    private func analysisStep(icon: String, text: String, completed: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(completed ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                .symbolEffect(.pulse, isActive: icon.contains("arrow"))
            
            Text(text)
                .font(.system(size: 15, weight: completed ? .semibold : .regular))
                .foregroundColor(completed ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
            
            Spacer()
        }
    }
    
    // MARK: - Completion Section
    
    private var completionSection: some View {
        VStack(spacing: 24) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 8) {
                Text("Submitted Successfully!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Your match result has been submitted for verification")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Next steps
            VStack(spacing: 12) {
                infoRow(icon: "clock.fill", text: "Waiting for opponent's submission")
                infoRow(icon: "eye.fill", text: "AI will verify both proofs")
                infoRow(icon: "dollarsign.circle.fill", text: "Instant payout if verified")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.Colors.surface)
            )
            
            // Done button
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(AppTheme.Colors.primary)
                    )
            }
        }
        .padding(.vertical, 40)
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private var canSubmit: Bool {
        guard let _ = selectedVideoURL,
              let yourScoreInt = Int(yourScore),
              let opponentScoreInt = Int(opponentScore) else {
            return false
        }
        
        return yourScoreInt >= 0 && opponentScoreInt >= 0 && yourScoreInt != opponentScoreInt
    }
    
    private func proceedToScoreEntry() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            uploadStep = .enterScores
        }
    }
    
    private func submitMatchResult() {
        guard let videoURL = selectedVideoURL,
              let yourScoreInt = Int(yourScore),
              let opponentScoreInt = Int(opponentScore) else {
            return
        }
        
        Task {
            do {
                // Step 1: Upload video
                uploadStep = .uploading
                
                let videoDownloadURL = try await uploadService.uploadVideo(
                    videoURL,
                    matchId: match.id,
                    playerId: getCurrentUserId()
                )
                
                // Step 2: Upload screenshot if provided
                var screenshotURL: String?
                if let screenshot = selectedScreenshot {
                    screenshotURL = try await uploadService.uploadScreenshot(
                        screenshot,
                        matchId: match.id,
                        playerId: getCurrentUserId()
                    )
                }
                
                // Step 3: Start AI analysis
                uploadStep = .analyzing
                analysisProgress = AnalysisProgress(
                    videoReceived: true,
                    extractingFrames: true,
                    readingScoreboard: false,
                    verifying: false
                )
                
                // Simulate progress updates
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                analysisProgress?.readingScoreboard = true
                
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                analysisProgress?.verifying = true
                
                // Step 4: Submit to verification service
                let result = try await verificationService.submitMatchResult(
                    matchId: match.id,
                    playerId: getCurrentUserId(),
                    videoURL: videoDownloadURL,
                    screenshotURL: screenshotURL,
                    selfReportedScore: yourScoreInt,
                    opponentScore: opponentScoreInt
                )
                
                // Step 5: Complete
                try? await Task.sleep(nanoseconds: 500_000_000)
                uploadStep = .complete
                
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                uploadStep = .enterScores
            }
        }
    }
    
    private func getFileSize(url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    private func getCurrentUserId() -> String {
        // Get from AuthenticationManager
        return "user-123" // TODO: Replace with actual user ID
    }
}

// MARK: - Video Picker

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Binding var thumbnail: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.videoMaximumDuration = 300 // 5 minutes
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.videoURL = url
                
                // Generate thumbnail
                let asset = AVAsset(url: url)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                
                if let cgImage = try? imageGenerator.copyCGImage(at: .zero, actualTime: nil) {
                    parent.thumbnail = UIImage(cgImage: cgImage)
                }
            }
            parent.dismiss()
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
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
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
    }
}

