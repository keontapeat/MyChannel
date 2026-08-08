import SwiftUI
import AVKit
import UIKit

// MARK: - Movie Detail Playback (extracted from MovieDetailView)
extension MovieDetailView {

    // MARK: - Main Action Buttons
    var mainActionButtons: some View {
        HStack(spacing: 16) {
            primaryPlayButton

            if movie.trailerURL != nil {
                trailerButton()
            }

            shareButton
        }
    }

    // MARK: - Primary Play Button
    var primaryPlayButton: some View {
        Button(action: playAction) {
            let isDirect = MoviePlaybackResolver.directPlayableURL(for: movie) != nil
            let title: String = {
                if isDirect {
                    if resumeProgress > 0.05 {
                        return resumeSeconds > 0 ? "Resume from \(Self.formatTimecode(resumeSeconds))" : "Resume"
                    }
                    return "Play Now"
                }
                if movie.trailerURL != nil { return "Play Trailer" }
                if MoviePlaybackResolver.externalWatchURL(for: movie) != nil {
                    return "Watch on \(movie.streamingSource.displayName)"
                }
                return "Play Trailer"
            }()
            let icon = "play.fill"
            VStack(spacing: 0) {
                Label(title, systemImage: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                if resumeProgress > 0.05 && isDirect {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.15))
                            Capsule().fill(Color.black.opacity(0.55))
                                .frame(width: geo.size.width * CGFloat(min(1, resumeProgress)))
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 5)
                }
            }
            .background(
                LinearGradient(
                    colors: [.white, .white.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: .white.opacity(0.3), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(PressableScaleStyle(scale: 0.96))
        .accessibilityLabel(primaryPlayAccessibilityLabel)
    }

    private var primaryPlayAccessibilityLabel: String {
        if MoviePlaybackResolver.directPlayableURL(for: movie) != nil {
            return resumeProgress > 0.05 ? "Resume movie" : "Play movie now"
        }
        return "Play trailer"
    }

    // MARK: - Trailer Button
    func trailerButton() -> some View {
        Button {
            withAnimation(AppTheme.AnimationPresets.easeInOut) {
                showTrailerPlayer = true
            }
        } label: {
            Image(systemName: "play.rectangle")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PressableScaleStyle())
        .accessibilityLabel("Play trailer")
    }

    // MARK: - Share Button
    var shareButton: some View {
        Button(action: shareAction) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PressableScaleStyle())
        .accessibilityLabel("Share movie")
    }

    // MARK: - Helpers
    /// Formats seconds as `M:SS` (or `H:MM:SS` for feature-length resume points).
    static func formatTimecode(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Setup Methods
    func setupVideo() {
        if video == nil {
            video = MoviePlaybackResolver.videoIfDirect(from: movie, creator: User.defaultUser)
        }
    }

    func loadResumeAndList() async {
        isWatchlisted = library.isInMyList(movie.id)
        guard let userId = appState.currentUser?.id else { return }
        let videoID = MoviePlaybackResolver.stableVideoID(for: movie)
        if let wp = try? await WatchProgressService.shared.fetchProgress(userId: userId, videoId: videoID) {
            await MainActor.run {
                if wp.completionPct > 0.05 && wp.completionPct < 0.95 {
                    resumeProgress = wp.completionPct
                    resumeSeconds = wp.positionSec
                }
            }
        }
    }

    // MARK: - Action Methods
    func playAction() {
        if let directVideo = MoviePlaybackResolver.videoIfDirect(from: movie, creator: User.defaultUser) {
            video = directVideo
            let vm = VideoPlayerManager()
            vm.setupPlayer(with: directVideo)
            vm.play()
            Task {
                await GlobalVideoPlayerManager.shared.adoptExternalPlayerManager(vm, video: directVideo, showFullscreen: true)
            }
            appState.addToHistory(video: directVideo, progress: resumeProgress, position: 0)
            showPlayer = true
        } else if movie.trailerURL != nil {
            showTrailerPlayer = true
        } else if let watchURL = MoviePlaybackResolver.externalWatchURL(for: movie) {
            UIApplication.shared.open(watchURL)
        } else {
            showUnavailableAlert = true
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Persist playback position when fullscreen player closes.
    func recordProgressFromPlayer() {
        let gpm = GlobalVideoPlayerManager.shared
        guard let video, gpm.currentVideo?.id == video.id else { return }
        let position = gpm.currentTime
        let duration = gpm.duration > 0 ? gpm.duration : video.duration
        guard duration > 0, position > 1 else { return }

        let progress = min(1.0, position / duration)
        let keepResume = progress > 0.05 && progress < 0.95
        resumeProgress = keepResume ? progress : 0
        resumeSeconds = keepResume ? position : 0
        appState.updateHistoryProgress(contentId: video.id, progress: progress, position: position)

        guard let userId = appState.currentUser?.id else { return }
        Task {
            try? await WatchProgressService.shared.saveProgress(
                userId: userId,
                videoId: video.id,
                position: position,
                duration: duration
            )
        }
    }

    func shareAction() {
        let activityViewController = UIActivityViewController(
            activityItems: [
                movie.title,
                "Check out this movie: \(movie.title)",
                URL(string: movie.trailerURL ?? "https://archive.org")
            ].compactMap { $0 },
            applicationActivities: nil
        )

        UIApplication.shared.presentShareSheet(activityViewController)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
