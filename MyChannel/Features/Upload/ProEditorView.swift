//
//  ProEditorView.swift
//  MyChannel
//
//  Professional Premiere Pro-style Video Editor
//  Created for MyChannel by AI Assistant
//

import SwiftUI
import AVFoundation
import AVKit

struct ProEditorView: View {
    let videoURL: URL
    let existingVideo: Video? // For post-upload editing
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editor = ProVideoEditor()
    
    @State private var showExportOptions = false
    @State private var showSaveConfirmation = false
    @State private var isSaving = false
    
    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Toolbar
                topToolbar
                
                // Video Preview
                videoPreviewSection
                
                // Timeline
                timelineSection
                
                // Tools Panel
                toolsPanel
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .onAppear {
            editor.loadVideo(url: videoURL, existing: existingVideo)
        }
        .sheet(isPresented: $showExportOptions) {
            ExportOptionsSheet(editor: editor, onExport: { quality in
                Task {
                    isSaving = true
                    await editor.exportVideo(quality: quality)
                    isSaving = false
                    showSaveConfirmation = true
                }
            })
        }
        .alert("Video Saved!", isPresented: $showSaveConfirmation) {
            Button("Done") {
                dismiss()
            }
            Button("Continue Editing", role: .cancel) { }
        } message: {
            Text("Your edited video has been saved successfully.")
        }
    }
    
    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
            }
            
            Spacer()
            
            Text(existingVideo != nil ? "Edit Video" : "Pro Editor")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                showExportOptions = true
            } label: {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Export")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.Colors.primary)
                    .clipShape(Capsule())
                }
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.black)
    }
    
    // MARK: - Video Preview
    private var videoPreviewSection: some View {
        ZStack {
            Color.black
            
            if let player = editor.player {
                VideoPlayer(player: player)
                    .disabled(true)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
            }
            
            // Playback Controls Overlay
            VStack {
                Spacer()
                playbackControls
            }
        }
        .frame(height: 400)
    }
    
    private var playbackControls: some View {
        HStack(spacing: 24) {
            // Skip backward
            Button {
                editor.skipBackward()
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "gobackward.5")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Play/Pause
            Button {
                editor.togglePlayback()
                HapticManager.shared.impact(style: .medium)
            } label: {
                Image(systemName: editor.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10)
            }
            
            // Skip forward
            Button {
                editor.skipForward()
                HapticManager.shared.impact(style: .light)
            } label: {
                Image(systemName: "goforward.5")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Timeline
    private var timelineSection: some View {
        VStack(spacing: 12) {
            // Timecode Display
            HStack {
                Text(formatTimecode(editor.currentTime))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(formatTimecode(editor.duration))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 20)
            
            // Timeline Scrubber
            VideoTimelineView(
                currentTime: $editor.currentTime,
                duration: editor.duration,
                trimStart: $editor.trimStart,
                trimEnd: $editor.trimEnd,
                onSeek: { time in
                    editor.seek(to: time)
                }
            )
            .frame(height: 80)
            .padding(.horizontal, 20)
            
            // Zoom Controls
            HStack(spacing: 12) {
                Button {
                    editor.zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Slider(value: $editor.timelineZoom, in: 0.1...1.0)
                    .tint(AppTheme.Colors.primary)
                    .frame(maxWidth: 200)
                
                Button {
                    editor.zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(AppTheme.Colors.surface)
    }
    
    // MARK: - Tools Panel
    private var toolsPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ProEditorTool(
                    title: "Trim",
                    icon: "scissors",
                    isSelected: editor.selectedTool == .trim
                ) {
                    editor.selectedTool = .trim
                    HapticManager.shared.impact(style: .light)
                }
                
                ProEditorTool(
                    title: "Split",
                    icon: "line.3.horizontal.decrease",
                    isSelected: editor.selectedTool == .split
                ) {
                    editor.selectedTool = .split
                    editor.splitAtCurrentTime()
                    HapticManager.shared.impact(style: .medium)
                }
                
                ProEditorTool(
                    title: "Speed",
                    icon: "speedometer",
                    isSelected: editor.selectedTool == .speed
                ) {
                    editor.selectedTool = .speed
                    HapticManager.shared.impact(style: .light)
                }
                
                ProEditorTool(
                    title: "Filters",
                    icon: "camera.filters",
                    isSelected: editor.selectedTool == .filters
                ) {
                    editor.selectedTool = .filters
                    HapticManager.shared.impact(style: .light)
                }
                
                ProEditorTool(
                    title: "Audio",
                    icon: "waveform",
                    isSelected: editor.selectedTool == .audio
                ) {
                    editor.selectedTool = .audio
                    HapticManager.shared.impact(style: .light)
                }
                
                ProEditorTool(
                    title: "Text",
                    icon: "textformat",
                    isSelected: editor.selectedTool == .text
                ) {
                    editor.selectedTool = .text
                    HapticManager.shared.impact(style: .light)
                }
                
                ProEditorTool(
                    title: "Transitions",
                    icon: "arrow.left.and.right",
                    isSelected: editor.selectedTool == .transitions
                ) {
                    editor.selectedTool = .transitions
                    HapticManager.shared.impact(style: .light)
                }
                
                ProEditorTool(
                    title: "Effects",
                    icon: "cpu",
                    isSelected: editor.selectedTool == .effects
                ) {
                    editor.selectedTool = .effects
                    HapticManager.shared.impact(style: .light)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(AppTheme.Colors.cardBackground)
    }
    
    private func formatTimecode(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let frames = Int((time.truncatingRemainder(dividingBy: 1)) * 30)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
        }
        return String(format: "%02d:%02d:%02d", minutes, seconds, frames)
    }
}

// MARK: - Timeline View
struct VideoTimelineView: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    @Binding var trimStart: TimeInterval
    @Binding var trimEnd: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                
                // Trim area highlight
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.primary.opacity(0.2))
                    .frame(width: trimWidth(in: geometry.size.width))
                    .offset(x: trimStartPosition(in: geometry.size.width))
                
                // Playhead
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .offset(x: playheadPosition(in: geometry.size.width))
                
                // Trim handles
                trimHandles(in: geometry.size.width)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let position = value.location.x
                        let time = (position / geometry.size.width) * duration
                        currentTime = max(0, min(duration, time))
                        onSeek(currentTime)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
    
    private func playheadPosition(in width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return (currentTime / duration) * width
    }
    
    private func trimStartPosition(in width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return (trimStart / duration) * width
    }
    
    private func trimWidth(in width: CGFloat) -> CGFloat {
        guard duration > 0 else { return width }
        return ((trimEnd - trimStart) / duration) * width
    }
    
    private func trimHandles(in width: CGFloat) -> some View {
        Group {
            // Start handle
            TrimHandle(isStart: true)
                .offset(x: trimStartPosition(in: width) - 10)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let position = value.location.x
                            let time = (position / width) * duration
                            trimStart = max(0, min(trimEnd - 0.1, time))
                        }
                )
            
            // End handle
            TrimHandle(isStart: false)
                .offset(x: trimStartPosition(in: width) + trimWidth(in: width))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let position = value.location.x
                            let time = (position / width) * duration
                            trimEnd = max(trimStart + 0.1, min(duration, time))
                        }
                )
        }
    }
}

struct TrimHandle: View {
    let isStart: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white)
            .frame(width: 20, height: 60)
            .overlay(
                VStack(spacing: 2) {
                    ForEach(0..<3) { _ in
                        Capsule()
                            .fill(Color.gray)
                            .frame(width: 2, height: 12)
                    }
                }
            )
            .shadow(color: .black.opacity(0.5), radius: 4)
    }
}

// MARK: - Pro Editor Tool Button
struct ProEditorTool: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.textSecondary)
                    .frame(width: 50, height: 50)
                    .background(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.surface)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Export Options Sheet
struct ExportOptionsSheet: View {
    @ObservedObject var editor: ProVideoEditor
    let onExport: (ExportQuality) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedQuality: ExportQuality = .high
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choose export quality")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .padding(.top, 24)
                
                VStack(spacing: 12) {
                    ForEach(ExportQuality.allCases) { quality in
                        QualityOption(
                            quality: quality,
                            isSelected: selectedQuality == quality
                        ) {
                            selectedQuality = quality
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button {
                    onExport(selectedQuality)
                    dismiss()
                } label: {
                    Text("Export Video")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QualityOption: View {
    let quality: ExportQuality
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: quality.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(quality.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text(quality.description)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(16)
            .background(isSelected ? AppTheme.Colors.primary.opacity(0.1) : AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.divider.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

enum ExportQuality: String, CaseIterable, Identifiable {
    case low = "480p"
    case medium = "720p"
    case high = "1080p"
    case ultra = "4K"
    
    var id: String { rawValue }
    var title: String { rawValue }
    var description: String {
        switch self {
        case .low: return "Fastest export, smaller file"
        case .medium: return "Good balance"
        case .high: return "Great quality (recommended)"
        case .ultra: return "Best quality, larger file"
        }
    }
    var icon: String {
        switch self {
        case .low: return "gauge.low"
        case .medium: return "gauge.medium"
        case .high: return "gauge.high"
        case .ultra: return "gauge.high"
        }
    }
}

#Preview {
    ProEditorView(videoURL: URL(string: "https://example.com/video.mp4")!, existingVideo: nil)
}

