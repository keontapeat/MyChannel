import SwiftUI
import AVFoundation
import AVKit
import UIKit

struct LiveChannelThumbnailView: View {
    let streamURL: String
    let posterURL: String?
    let fallbackStreamURL: String?
    let allowPlaybackInPreviews: Bool

    @State private var isReady: Bool = false
    @State private var snapshot: UIImage?

    init(streamURL: String, posterURL: String? = nil, fallbackStreamURL: String? = nil, allowPlaybackInPreviews: Bool = false) {
        self.streamURL = streamURL
        self.posterURL = posterURL
        self.fallbackStreamURL = fallbackStreamURL
        self.allowPlaybackInPreviews = allowPlaybackInPreviews
    }

    var body: some View {
        ZStack {
            // Video preview sits in the back and fades in when ready
            if !AppConfig.isPreview || allowPlaybackInPreviews {
                LivePreviewPlayer(
                    urls: [streamURL] + (fallbackStreamURL != nil ? [fallbackStreamURL!] : []),
                    onReady: {
                        if !isReady {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isReady = true
                            }
                        }
                    },
                    onSnapshot: { img in
                        if snapshot == nil {
                            snapshot = img
                        }
                    }
                )
                .opacity(isReady ? 1 : 0)
                .transition(.opacity)
            }

            // Placeholder layer stays on top until video is ready (or always in previews)
            if (AppConfig.isPreview && !allowPlaybackInPreviews) || !isReady {
                if let snap = snapshot {
                    Image(uiImage: snap)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else if let poster = posterURL, let url = URL(string: poster) {
                    if poster.lowercased().hasSuffix(".svg") {
                        ZStack {
                            Color(.systemGray6)
                            VStack(spacing: 8) {
                                Image(systemName: "tv.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color(.systemGray6)
                        }
                    }
                } else {
                    Color(.systemGray6)
                }
            }
        }
        .clipped()
        .background(Color(.systemGray6))
    }
}

private struct LivePreviewPlayer: UIViewRepresentable {
    let urls: [String]
    let onReady: () -> Void
    let onSnapshot: (UIImage) -> Void

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.configure(with: urls, onReady: onReady, onSnapshot: onSnapshot)
    }
}

private final class PlayerContainerView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var urlCandidates: [String] = []
    private var currentIndex: Int = 0
    private var timeControlObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var readyTimeoutWork: DispatchWorkItem?
    private var retryWork: DispatchWorkItem?
    private var hasNotifiedReady = false

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func configure(with urls: [String], onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void) {
        urlCandidates = urls
        let defaultFallback = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        if !urlCandidates.contains(where: { $0 == defaultFallback }) {
            urlCandidates.append(defaultFallback)
        }
        currentIndex = 0
        teardown()
        startPlayer(onReady: onReady, onSnapshot: onSnapshot)
    }

    private func startPlayer(onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void) {
        guard currentIndex < urlCandidates.count, let url = URL(string: urlCandidates[currentIndex]) else { return }

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true

        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.currentItem?.preferredPeakBitRate = 1_800_000

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.needsDisplayOnBoundsChange = true
        self.layer.addSublayer(layer)

        self.player = player
        self.playerLayer = layer
        self.hasNotifiedReady = false

        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            if item.status == .readyToPlay {
                self.notifyReadyIfNeeded(onReady)
                player.play()
            } else if item.status == .failed {
                self.tryNextCandidate(onReady: onReady, onSnapshot: onSnapshot)
            }
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] p, _ in
            guard let self else { return }
            if p.timeControlStatus == .playing {
                self.notifyReadyIfNeeded(onReady)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }

        let readyWork = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.player?.timeControlStatus != .playing {
                self.generateSnapshot(from: asset) { img in
                    if let img { onSnapshot(img) }
                }
            }
        }
        self.readyTimeoutWork = readyWork
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5, execute: readyWork)

        let retry = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.player?.timeControlStatus != .playing {
                self.tryNextCandidate(onReady: onReady, onSnapshot: onSnapshot)
            }
        }
        self.retryWork = retry
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 4.0, execute: retry)

        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewsPause), name: NSNotification.Name("LivePreviewsShouldPause"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewsResume), name: NSNotification.Name("LivePreviewsShouldResume"), object: nil)

        player.play()
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func tryNextCandidate(onReady: @escaping () -> Void, onSnapshot: @escaping (UIImage) -> Void) {
        currentIndex += 1
        teardownPlayerOnly()
        if currentIndex < urlCandidates.count {
            startPlayer(onReady: onReady, onSnapshot: onSnapshot)
        }
    }

    private func notifyReadyIfNeeded(_ onReady: @escaping () -> Void) {
        if !hasNotifiedReady {
            hasNotifiedReady = true
            DispatchQueue.main.async { onReady() }
        }
    }

    private func generateSnapshot(from asset: AVAsset, completion: @escaping (UIImage?) -> Void) {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)
        let time = CMTime(seconds: 1, preferredTimescale: 600)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                DispatchQueue.main.async { completion(image) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    @objc private func handleAppBackground() { player?.pause() }
    @objc private func handleAppForeground() { player?.play() }
    @objc private func handlePreviewsPause() { player?.pause() }
    @objc private func handlePreviewsResume() { player?.play() }

    private func teardownPlayerOnly() {
        readyTimeoutWork?.cancel()
        retryWork?.cancel()
        readyTimeoutWork = nil
        retryWork = nil
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()
        statusObserver = nil
        timeControlObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    func teardown() {
        NotificationCenter.default.removeObserver(self)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        teardownPlayerOnly()
    }

    deinit { teardown() }
}

#Preview("LiveChannelThumbnailView") {
    LiveChannelThumbnailView(
        streamURL: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
        posterURL: "https://upload.wikimedia.org/wikipedia/commons/3/31/Red_dot.svg"
    )
    .frame(width: 200, height: 112)
    .background(Color(.systemGray6))
    .preferredColorScheme(.light)
}