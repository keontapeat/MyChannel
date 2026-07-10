//
//  MiniPlayerControls.swift
//  MyChannel
//
//  Extracted from FloatingMiniPlayer — control chrome and overlays.
//

import SwiftUI

// MARK: - Formatting Helpers

extension FloatingMiniPlayer {

    func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }

    func formatViewCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Info Section

extension FloatingMiniPlayer {

    @ViewBuilder
    func miniPlayerInfoSection(video: Video) -> some View {
        HStack(spacing: 10) {
            videoMetadataSection(video: video)
            miniPlayerControlsCluster
        }
    }

    @ViewBuilder
    func videoMetadataSection(video: Video) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            videoTitleRow(video: video)
            creatorInfoRow(video: video)

            if let upNext = globalPlayer.upNextVideo {
                upNextPreview(upNext: upNext)
            }

            progressBarWithTime
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func videoTitleRow(video: Video) -> some View {
        HStack(spacing: 6) {
            Text(video.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if video.isLiveStream {
                liveBadge
            }
        }
    }

    var liveBadge: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)

            Text("LIVE")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.red)
        .cornerRadius(4)
    }

    @ViewBuilder
    func creatorInfoRow(video: Video) -> some View {
        HStack(spacing: 6) {
            Text(video.creator.displayName)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .lineLimit(1)

            if video.isLiveStream {
                liveViewerCount(viewCount: video.viewCount)
            }
        }
    }

    @ViewBuilder
    func liveViewerCount(viewCount: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "eye.fill")
                .font(.system(size: 8))
            Text("\(formatViewCount(viewCount))")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(AppTheme.Colors.textSecondary)
    }

    @ViewBuilder
    func upNextPreview(upNext: Video) -> some View {
        HStack(spacing: 6) {
            Text("Up Next:")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)

            Text(upNext.title)
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    var progressBarWithTime: some View {
        VStack(spacing: 2) {
            scrubbableProgressBar

            HStack {
                Text(formatTime(globalPlayer.currentTime))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Spacer()
                Text(formatTime(globalPlayer.duration))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Controls Cluster

extension FloatingMiniPlayer {

    var miniPlayerControlsCluster: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                volumeControl
                speedControl
                qualityControl
                expandButton
                closeButton
            }
        }
    }

    var volumeControl: some View {
        ZStack {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingVolumeSlider.toggle()
                    if showingVolumeSlider {
                        showingSpeedMenu = false
                        showingQualityMenu = false
                    }
                }
                HapticManager.shared.impact(style: .light)
            }) {
                Image(systemName: volume > 0.5 ? "speaker.wave.2.fill" : volume > 0 ? "speaker.wave.1.fill" : "speaker.slash.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showingVolumeSlider ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .padding(6)
                    .background(showingVolumeSlider ? AppTheme.Colors.primary.opacity(0.15) : AppTheme.Colors.textSecondary.opacity(0.08))
                    .clipShape(Circle())
            }

            if showingVolumeSlider {
                VStack(spacing: 8) {
                    Slider(value: $volume, in: 0...1)
                        .tint(AppTheme.Colors.primary)
                        .frame(width: 120)
                        .onChange(of: volume) { newValue in
                            globalPlayer.player?.volume = newValue
                        }

                    Text("\(Int(volume * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.cardBackground.opacity(0.98)))
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
                )
                .offset(x: -70, y: -80)
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            }
        }
    }

    var speedControl: some View {
        ZStack {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingSpeedMenu.toggle()
                    if showingSpeedMenu {
                        showingVolumeSlider = false
                        showingQualityMenu = false
                    }
                }
                HapticManager.shared.impact(style: .light)
            }) {
                speedButtonLabel
            }

            if showingSpeedMenu {
                speedMenuPopup
            }
        }
    }

    var speedButtonLabel: some View {
        Text(String(format: "%.2gx", playbackSpeed))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(showingSpeedMenu ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
            .padding(6)
            .background(showingSpeedMenu ? AppTheme.Colors.primary.opacity(0.15) : AppTheme.Colors.textSecondary.opacity(0.08))
            .clipShape(Circle())
    }

    var speedMenuPopup: some View {
        VStack(spacing: 4) {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                speedMenuItem(speed: speed)
            }
        }
        .padding(8)
        .frame(width: 140)
        .background(speedMenuBackground)
        .offset(x: -75, y: -140)
        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
    }

    func speedMenuItem(speed: Double) -> some View {
        Button(action: {
            playbackSpeed = Float(speed)
            globalPlayer.player?.rate = Float(speed)
            withAnimation {
                showingSpeedMenu = false
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack {
                Text(speed == 1.0 ? "Normal" : String(format: "%.2gx", speed))
                    .font(.system(size: 12, weight: Float(speed) == playbackSpeed ? .bold : .regular))
                    .foregroundColor(Float(speed) == playbackSpeed ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)

                Spacer()

                if Float(speed) == playbackSpeed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Float(speed) == playbackSpeed ? AppTheme.Colors.primary.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
    }

    var speedMenuBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.cardBackground.opacity(0.98)))
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    var qualityControl: some View {
        ZStack {
            qualityToggleButton
            if showingQualityMenu {
                qualityMenuPopup
            }
        }
    }

    var qualityToggleButton: some View {
        let isActive: Bool = showingQualityMenu
        let labelColor: Color = isActive ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary
        let bgColor: Color = isActive ? AppTheme.Colors.primary.opacity(0.15) : AppTheme.Colors.textSecondary.opacity(0.08)
        let label: String = selectedQuality == "Auto" ? "HD" : selectedQuality
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showingQualityMenu.toggle()
                if showingQualityMenu {
                    showingVolumeSlider = false
                    showingSpeedMenu = false
                }
            }
            HapticManager.shared.impact(style: .light)
        }) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(labelColor)
                .padding(6)
                .background(bgColor)
                .clipShape(Circle())
        }
    }

    var qualityMenuPopup: some View {
        VStack(spacing: 4) {
            ForEach(["Auto", "4K", "1080p", "720p", "480p", "360p"], id: \.self) { quality in
                qualityMenuRow(quality)
            }
        }
        .padding(8)
        .frame(width: 140)
        .background(speedMenuBackground)
        .offset(x: -75, y: -120)
        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
    }

    func qualityMenuRow(_ quality: String) -> some View {
        let isSelected: Bool = selectedQuality == quality
        let textColor: Color = isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary
        let rowBackground: Color = isSelected ? AppTheme.Colors.primary.opacity(0.1) : Color.clear
        return Button(action: {
            selectedQuality = quality
            Task { @MainActor in
                GlobalVideoPlayerManager.shared.setQuality(quality)
            }
            withAnimation {
                showingQualityMenu = false
            }
            HapticManager.shared.impact(style: .light)
        }) {
            HStack {
                Text(quality)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                    .foregroundColor(textColor)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.Colors.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(rowBackground)
            .cornerRadius(6)
        }
    }

    var expandButton: some View {
        Button(action: { expandPlayer(); HapticManager.shared.impact(style: .light) }) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(6)
                .background(AppTheme.Colors.textSecondary.opacity(0.08))
                .clipShape(Circle())
        }
    }

    var closeButton: some View {
        Button(action: closePlayer) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .padding(6)
                .background(AppTheme.Colors.textSecondary.opacity(0.08))
                .clipShape(Circle())
        }
    }

    var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 3)

                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(
                        width: geometry.size.width * CGFloat(globalPlayer.currentProgress),
                        height: 3
                    )
                    .animation(.linear(duration: 0.1), value: globalPlayer.currentProgress)
            }
        }
        .frame(height: 3)
    }

    var miniPlayerBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Colors.cardBackground.opacity(0.95))
            )
            .shadow(
                color: AppTheme.Colors.textPrimary.opacity(0.12),
                radius: 20,
                x: 0,
                y: -8
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppTheme.Colors.divider.opacity(0.2), lineWidth: 0.5)
            )
    }

    func calculateBottomPadding(geometry: GeometryProxy) -> CGFloat {
        let safeAreaBottom = geometry.safeAreaInsets.bottom
        let tabBarHeight: CGFloat = 80
        return safeAreaBottom + tabBarHeight + 24
    }
}

// MARK: - Enhanced Overlays

extension FloatingMiniPlayer {

    var scrubbableProgressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 3)

                if let video = globalPlayer.currentVideo,
                   let chapters = video.chapters,
                   !chapters.isEmpty,
                   globalPlayer.duration > 0 {
                    ForEach(chapters, id: \.id) { chapter in
                        let chapterProgress = chapter.start / globalPlayer.duration
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 1, height: 6)
                            .offset(x: geometry.size.width * CGFloat(chapterProgress))
                    }
                }

                Rectangle()
                    .fill(AppTheme.Colors.primary)
                    .frame(
                        width: geometry.size.width * CGFloat(globalPlayer.currentProgress),
                        height: 3
                    )
                    .animation(.linear(duration: 0.1), value: globalPlayer.currentProgress)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                        globalPlayer.seek(to: progress)
                    }
                    .onEnded { value in
                        let progress = min(max(0, value.location.x / geometry.size.width), 1)
                        globalPlayer.seek(to: progress)
                        HapticManager.shared.impact(style: .light)
                    }
            )
        }
        .frame(height: 3)
    }

    var seekFeedbackOverlay: some View {
        HStack {
            VStack {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("-10s")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(.black.opacity(0.6))
            .cornerRadius(8)
            .opacity(0.8)

            Spacer()

            VStack {
                Image(systemName: "goforward.10")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("+10s")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(.black.opacity(0.6))
            .cornerRadius(8)
            .opacity(0.8)
        }
        .padding(.horizontal, 8)
    }

    var advancedControlsOverlay: some View {
        VStack {
            HStack {
                Spacer()

                Menu {
                    Button("Quality") { showingQualityMenu = true }
                    Button("Speed") { showingSpeedMenu = true }
                    Button("Captions") { /* Toggle captions */ }
                    Button("Picture in Picture") {
                        // Native PiP is handled by the system
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding(8)

            Spacer()

            HStack {
                Button(action: {
                    globalPlayer.playPreviousVideo()
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(globalPlayer.hasPreviousVideo ? .white : .white.opacity(0.3))
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .disabled(!globalPlayer.hasPreviousVideo)

                Spacer()

                Button(action: {
                    globalPlayer.playNextVideo()
                }) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(globalPlayer.hasNextVideo ? .white : .white.opacity(0.3))
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .disabled(!globalPlayer.hasNextVideo)
            }
            .padding(8)
        }
    }
}
