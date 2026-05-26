//
//  ClipsView.swift
//  MyChannel
//
//  🎬 YOUTUBE CLIPS FEATURE - 100% PARITY
//  Create shareable 5-60 second clips from any video
//
//  Created for MyChannel
//

import SwiftUI
import UIKit
import AVFoundation
import AVKit
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Clips Creation View
struct ClipsView: View {
    let video: Video
    let currentTime: TimeInterval
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ClipsViewModel
    
    @State private var clipTitle: String = ""
    @State private var startTime: TimeInterval
    @State private var endTime: TimeInterval
    @State private var isCreating = false
    @State private var showShareSheet = false
    @State private var createdClip: SharedVideoClip?
    
    private let minClipDuration: TimeInterval = 5
    private let maxClipDuration: TimeInterval = 60
    
    init(video: Video, currentTime: TimeInterval) {
        self.video = video
        self.currentTime = currentTime
        _viewModel = StateObject(wrappedValue: ClipsViewModel(video: video))
        
        // Default to 15-second clip starting at current time
        let defaultStart = max(0, currentTime - 7.5)
        let defaultEnd = min(video.duration, defaultStart + 15)
        _startTime = State(initialValue: defaultStart)
        _endTime = State(initialValue: defaultEnd)
    }
    
    var clipDuration: TimeInterval {
        endTime - startTime
    }
    
    var isValidClip: Bool {
        clipDuration >= minClipDuration && 
        clipDuration <= maxClipDuration &&
        !clipTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Video Preview
                        clipPreviewSection
                        
                        // Timeline Editor
                        timelineEditorSection
                        
                        // Clip Title
                        clipTitleSection
                        
                        // Clip Info
                        clipInfoSection
                        
                        // Create Button
                        createButtonSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Create Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let clip = createdClip {
                    ClipShareSheet(clip: clip)
                }
            }
        }
    }
    
    // MARK: - Preview Section
    private var clipPreviewSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Video thumbnail with play indicator
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Play button overlay
                Circle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    )
                
                // Clip duration badge
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(clipDuration))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(4)
                            .padding(8)
                    }
                }
            }
            
            Text("Preview of your clip")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
    
    // MARK: - Timeline Editor
    private var timelineEditorSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select clip range")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(formatDuration(clipDuration)) / 60s max")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(clipDuration > maxClipDuration ? .red : AppTheme.Colors.textSecondary)
            }
            
            // Timeline scrubber
            VStack(spacing: 8) {
                // Thumbnails strip (simplified)
                HStack(spacing: 2) {
                    ForEach(0..<10, id: \.self) { i in
                        let progress = Double(i) / 10.0
                        let isInRange = progress >= (startTime / video.duration) && 
                                       progress <= (endTime / video.duration)
                        
                        Rectangle()
                            .fill(isInRange ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                            .frame(height: 40)
                            .opacity(isInRange ? 1.0 : 0.5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Range slider
                ClipRangeSlider(
                    startTime: $startTime,
                    endTime: $endTime,
                    duration: video.duration,
                    minClipDuration: minClipDuration,
                    maxClipDuration: maxClipDuration
                )
            }
            
            // Time indicators
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text(formatDuration(startTime))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Duration")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text(formatDuration(clipDuration))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("End")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text(formatDuration(endTime))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
    }
    
    // MARK: - Title Section
    private var clipTitleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clip title")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            TextField("Add a title for your clip...", text: $clipTitle)
                .font(.system(size: 16))
                .padding(16)
                .background(AppTheme.Colors.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.divider, lineWidth: 1)
                )
            
            Text("\(clipTitle.count)/100 characters")
                .font(.system(size: 12))
                .foregroundColor(clipTitle.count > 100 ? .red : AppTheme.Colors.textTertiary)
        }
    }
    
    // MARK: - Info Section
    private var clipInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Video info
                AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.surface)
                }
                .frame(width: 60, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("From: \(video.title)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(video.creator.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(AppTheme.Colors.surface)
            .cornerRadius(12)
            
            // Clip rules
            VStack(alignment: .leading, spacing: 8) {
                clipRuleRow(icon: "clock", text: "Clips must be 5-60 seconds long")
                clipRuleRow(icon: "link", text: "Clips link back to the original video")
                clipRuleRow(icon: "square.and.arrow.up", text: "Share clips anywhere")
            }
            .padding(12)
            .background(AppTheme.Colors.surface.opacity(0.5))
            .cornerRadius(12)
        }
    }
    
    private func clipRuleRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
    
    // MARK: - Create Button
    private var createButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: createClip) {
                HStack(spacing: 8) {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "scissors")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(isCreating ? "Creating Clip..." : "Create Clip")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(isValidClip ? AppTheme.Colors.primary : AppTheme.Colors.textTertiary)
                )
            }
            .disabled(!isValidClip || isCreating)
            
            if !isValidClip {
                Text(validationMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }
    
    private var validationMessage: String {
        if clipTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Please add a title for your clip"
        } else if clipDuration < minClipDuration {
            return "Clip must be at least 5 seconds long"
        } else if clipDuration > maxClipDuration {
            return "Clip cannot exceed 60 seconds"
        }
        return ""
    }
    
    // MARK: - Actions
    private func createClip() {
        guard isValidClip else { return }
        
        isCreating = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            do {
                let clip = try await viewModel.createClip(
                    title: clipTitle,
                    startTime: startTime,
                    endTime: endTime
                )
                
                await MainActor.run {
                    isCreating = false
                    createdClip = clip
                    showShareSheet = true
                    HapticManager.shared.successPattern()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    HapticManager.shared.errorPattern()
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Clip Range Slider
struct ClipRangeSlider: View {
    @Binding var startTime: TimeInterval
    @Binding var endTime: TimeInterval
    let duration: TimeInterval
    let minClipDuration: TimeInterval
    let maxClipDuration: TimeInterval
    
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let startX = (startTime / duration) * width
            let endX = (endTime / duration) * width
            
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.Colors.surface)
                    .frame(height: 8)
                
                // Selected range
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.Colors.primary)
                    .frame(width: endX - startX, height: 8)
                    .offset(x: startX)
                
                // Start handle
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4)
                    .offset(x: startX - 12)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingStart = true
                                let newX = max(0, min(value.location.x, endX - (minClipDuration / duration) * width))
                                startTime = (newX / width) * duration
                                
                                // Enforce max duration
                                if endTime - startTime > maxClipDuration {
                                    startTime = endTime - maxClipDuration
                                }
                            }
                            .onEnded { _ in
                                isDraggingStart = false
                                HapticManager.shared.impact(style: .light)
                            }
                    )
                
                // End handle
                Circle()
                    .fill(AppTheme.Colors.primary)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 4)
                    .offset(x: endX - 12)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingEnd = true
                                let newX = max(startX + (minClipDuration / duration) * width, min(value.location.x, width))
                                endTime = (newX / width) * duration
                                
                                // Enforce max duration
                                if endTime - startTime > maxClipDuration {
                                    endTime = startTime + maxClipDuration
                                }
                            }
                            .onEnded { _ in
                                isDraggingEnd = false
                                HapticManager.shared.impact(style: .light)
                            }
                    )
            }
        }
        .frame(height: 40)
    }
}

// MARK: - Clips View Model
@MainActor
class ClipsViewModel: ObservableObject {
    let video: Video
    
    @Published var isLoading = false
    @Published var error: String?
    
    init(video: Video) {
        self.video = video
    }
    
    func createClip(title: String, startTime: TimeInterval, endTime: TimeInterval) async throws -> SharedVideoClip {
        isLoading = true
        defer { isLoading = false }
        
        // Create clip object
        let clip = SharedVideoClip(
            id: UUID().uuidString,
            title: title,
            sourceVideoId: video.id,
            sourceVideoTitle: video.title,
            creatorId: AppState.shared.currentUser?.id ?? "",
            creatorName: AppState.shared.currentUser?.displayName ?? "Unknown",
            startTime: startTime,
            endTime: endTime,
            duration: endTime - startTime,
            thumbnailURL: video.thumbnailURL,
            clipURL: "", // Generated by backend
            viewCount: 0,
            createdAt: Date()
        )
        
        // Save to Firestore
        try await ClipsFirestoreService.shared.saveClip(clip)
        
        print("✅ [Clips] Created clip: \(title) (\(Int(endTime - startTime))s)")
        
        return clip
    }
}

// MARK: - Video Clip Model (for sharing/social clips)
struct SharedVideoClip: Identifiable, Codable {
    let id: String
    let title: String
    let sourceVideoId: String
    let sourceVideoTitle: String
    let creatorId: String
    let creatorName: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let duration: TimeInterval
    let thumbnailURL: String
    var clipURL: String
    var viewCount: Int
    let createdAt: Date
    
    var shareURL: String {
        "https://mychannel.live/clip/\(id)"
    }
}

// MARK: - Clip Share Sheet
struct ClipShareSheet: View {
    let clip: SharedVideoClip
    @Environment(\.dismiss) private var dismiss
    @State private var isCopied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Success header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                    }
                    
                    Text("Clip Created!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(clip.title)
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Clip preview card
                VStack(spacing: 12) {
                    AsyncImage(url: URL(string: clip.thumbnailURL)) { image in
                        image.resizable().aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(AppTheme.Colors.surface)
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(formatDuration(clip.duration))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(4)
                                    .padding(8)
                            }
                        }
                    )
                    
                    Text("From: \(clip.sourceVideoTitle)")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .padding(16)
                .background(AppTheme.Colors.surface)
                .cornerRadius(16)
                
                // Share URL
                VStack(spacing: 12) {
                    HStack {
                        Text(clip.shareURL)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: copyLink) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16))
                                .foregroundColor(isCopied ? .green : AppTheme.Colors.primary)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.Colors.surface)
                    .cornerRadius(8)
                }
                
                // Share buttons
                HStack(spacing: 16) {
                    shareButton(icon: "square.and.arrow.up", title: "Share", color: AppTheme.Colors.primary) {
                        shareClip()
                    }
                    
                    shareButton(icon: "link", title: "Copy Link", color: .gray) {
                        copyLink()
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("Share Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func shareButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
        }
    }
    
    private func copyLink() {
        UIPasteboard.general.string = clip.shareURL
        isCopied = true
        HapticManager.shared.successPattern()
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isCopied = false
        }
    }
    
    private func shareClip() {
        let activityVC = UIActivityViewController(
            activityItems: [clip.shareURL],
            applicationActivities: nil
        )
        UIApplication.shared.presentShareSheet(activityVC)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Clips Firestore Service
class ClipsFirestoreService {
    static let shared = ClipsFirestoreService()
    
    private init() {}
    
    func saveClip(_ clip: SharedVideoClip) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try await db.collection("clips").document(clip.id).setData([
            "id": clip.id,
            "title": clip.title,
            "sourceVideoId": clip.sourceVideoId,
            "sourceVideoTitle": clip.sourceVideoTitle,
            "creatorId": clip.creatorId,
            "creatorName": clip.creatorName,
            "startTime": clip.startTime,
            "endTime": clip.endTime,
            "duration": clip.duration,
            "thumbnailURL": clip.thumbnailURL,
            "clipURL": clip.clipURL,
            "viewCount": clip.viewCount,
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
    }
    
    func getClips(for videoId: String) async throws -> [SharedVideoClip] {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let snapshot = try await db.collection("clips")
            .whereField("sourceVideoId", isEqualTo: videoId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> SharedVideoClip? in
            let data = doc.data()
            guard let id = data["id"] as? String,
                  let title = data["title"] as? String,
                  let sourceVideoId = data["sourceVideoId"] as? String,
                  let sourceVideoTitle = data["sourceVideoTitle"] as? String,
                  let creatorId = data["creatorId"] as? String,
                  let creatorName = data["creatorName"] as? String,
                  let startTime = data["startTime"] as? TimeInterval,
                  let endTime = data["endTime"] as? TimeInterval,
                  let duration = data["duration"] as? TimeInterval,
                  let thumbnailURL = data["thumbnailURL"] as? String
            else { return nil }
            
            return SharedVideoClip(
                id: id,
                title: title,
                sourceVideoId: sourceVideoId,
                sourceVideoTitle: sourceVideoTitle,
                creatorId: creatorId,
                creatorName: creatorName,
                startTime: startTime,
                endTime: endTime,
                duration: duration,
                thumbnailURL: thumbnailURL,
                clipURL: data["clipURL"] as? String ?? "",
                viewCount: data["viewCount"] as? Int ?? 0,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
        #else
        return []
        #endif
    }
}

// MARK: - Preview
#Preview {
    ClipsView(video: Video.sampleVideos[0], currentTime: 30)
}

