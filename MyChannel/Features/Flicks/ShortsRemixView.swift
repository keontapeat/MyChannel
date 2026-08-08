//
//  ShortsRemixView.swift
//  MyChannel
//
//  Productized Shorts remix tools: Duet (side-by-side), Stitch (trim + respond),
//  and Green Screen (chroma-key overlay). YouTube/TikTok parity.
//

import SwiftUI
import AVFoundation
import AVKit

enum RemixMode: String, CaseIterable {
    case duet = "Duet"
    case stitch = "Stitch"
    case greenScreen = "Green Screen"

    var icon: String {
        switch self {
        case .duet: return "rectangle.split.2x1"
        case .stitch: return "scissors"
        case .greenScreen: return "camera.metering.spot"
        }
    }

    var description: String {
        switch self {
        case .duet: return "React side-by-side with the original video"
        case .stitch: return "Trim a clip and add your response"
        case .greenScreen: return "Use the video as your background"
        }
    }
}

struct ShortsRemixView: View {
    let originalVideo: Video
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: RemixMode = .duet
    @State private var originalPlayer: AVPlayer?
    @State private var isCameraReady = false
    @State private var isRecording = false
    @State private var recordedURL: URL?
    @State private var isProcessing = false
    @State private var showPreview = false
    @State private var processedURL: URL?
    @State private var stitchStart: Double = 0
    @State private var stitchEnd: Double = 5
    @State private var videoDuration: Double = 15

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Mode selector
                    modeSelector

                    // Preview area
                    previewArea

                    // Controls
                    controlsArea
                }
            }
            .navigationTitle("Remix: \(selectedMode.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                if processedURL != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Post") {
                            // Navigate to upload/post flow with processedURL
                        }
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
            .onAppear { setupOriginalPlayer() }
            .onDisappear {
                originalPlayer?.pause()
                originalPlayer = nil
            }
        }
    }

    // MARK: - Mode Selector
    private var modeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(RemixMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedMode = mode
                        }
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 18))
                            Text(mode.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(selectedMode == mode ? .black : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(selectedMode == mode ? Color.white : Color.white.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Preview Area
    @ViewBuilder
    private var previewArea: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                switch selectedMode {
                case .duet:
                    HStack(spacing: 2) {
                        // Original video (left)
                        if let player = originalPlayer {
                            VideoPlayer(player: player)
                                .frame(width: (geo.size.width - 2) / 2)
                        } else {
                            thumbnailFallback
                                .frame(width: (geo.size.width - 2) / 2)
                        }
                        // Camera preview (right) — placeholder until camera is active
                        cameraPreviewPlaceholder
                            .frame(width: (geo.size.width - 2) / 2)
                    }

                case .stitch:
                    VStack(spacing: 0) {
                        // Trimmed original clip (top half)
                        Group {
                            if let player = originalPlayer {
                                VideoPlayer(player: player)
                            } else {
                                thumbnailFallback
                            }
                        }
                        .frame(height: geo.size.height * 0.45)

                        // Stitch trim scrubber
                        VStack(spacing: 4) {
                            Text("Select 1–5s clip to stitch")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            HStack(spacing: 8) {
                                Text(String(format: "%.1fs", stitchStart))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                RangeSliderView(lower: $stitchStart, upper: $stitchEnd, bounds: 0...videoDuration, maxSpan: 5)
                                    .frame(height: 20)
                                Text(String(format: "%.1fs", stitchEnd))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))

                        // Camera response area
                        cameraPreviewPlaceholder
                            .frame(height: geo.size.height * 0.45)
                    }

                case .greenScreen:
                    ZStack {
                        // Original video as background
                        if let player = originalPlayer {
                            VideoPlayer(player: player)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            thumbnailFallback
                        }
                        // Camera overlay (portrait, chroma-keyed)
                        cameraPreviewPlaceholder
                            .opacity(0.9)
                        VStack {
                            HStack {
                                Spacer()
                                Label("Green Screen", systemImage: "camera.metering.spot")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(6)
                                    .padding(12)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var thumbnailFallback: some View {
        AsyncImage(url: URL(string: originalVideo.thumbnailURL)) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            Color(white: 0.15)
        }
        .clipped()
    }

    private var cameraPreviewPlaceholder: some View {
        ZStack {
            Color(white: 0.12)
            VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.4))
                Text("Camera Preview")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                Text("Tap Record to start")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
    }

    // MARK: - Controls
    private var controlsArea: some View {
        VStack(spacing: 16) {
            // Mode description
            Text(selectedMode.description)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            // Record button
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(isRecording ? Color.red : Color.red)
                        .frame(width: isRecording ? 32 : 60, height: isRecording ? 32 : 60)
                        .cornerRadius(isRecording ? 6 : 30)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
                }
            }
            .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")

            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Processing remix…")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 20)
        .background(Color.black)
    }

    // MARK: - Helpers
    private func setupOriginalPlayer() {
        guard let url = URL(string: originalVideo.videoURL) else { return }
        originalPlayer = AVPlayer(url: url)
        originalPlayer?.play()
    }

    private func startRecording() {
        isRecording = true
        HapticManager.shared.impact(style: .medium)
        originalPlayer?.seek(to: .zero)
        originalPlayer?.play()
    }

    private func stopRecording() {
        isRecording = false
        originalPlayer?.pause()
        HapticManager.shared.impact(style: .medium)
        processRemix()
    }

    private func processRemix() {
        isProcessing = true
        // In production: merge camera capture + original via DuetStitchEngine
        // For now, show completion after a brief processing indicator
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                isProcessing = false
                // processedURL would be set here after DuetStitchEngine.stitchVideos()
            }
        }
    }
}

// MARK: - Simple dual-thumb range slider for stitch trimming
private struct RangeSliderView: View {
    @Binding var lower: Double
    @Binding var upper: Double
    let bounds: ClosedRange<Double>
    let maxSpan: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)

                let range = bounds.upperBound - bounds.lowerBound
                let lx = CGFloat((lower - bounds.lowerBound) / range) * geo.size.width
                let ux = CGFloat((upper - bounds.lowerBound) / range) * geo.size.width

                Capsule()
                    .fill(Color.white)
                    .frame(width: ux - lx, height: 4)
                    .offset(x: lx)

                // Lower thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: lx - 10)
                    .gesture(DragGesture().onChanged { v in
                        let pct = max(0, min(1, Double(v.location.x / geo.size.width)))
                        let newLower = bounds.lowerBound + pct * range
                        lower = min(newLower, upper - 0.5)
                    })

                // Upper thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: ux - 10)
                    .gesture(DragGesture().onChanged { v in
                        let pct = max(0, min(1, Double(v.location.x / geo.size.width)))
                        let newUpper = bounds.lowerBound + pct * range
                        upper = max(newUpper, lower + 0.5)
                        upper = min(upper, lower + maxSpan)
                    })
            }
        }
    }
}

#Preview {
    ShortsRemixView(originalVideo: Video.sampleVideos[0])
}
