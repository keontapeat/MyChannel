import SwiftUI
import AVFoundation
import AVKit

struct LiveChannelThumbnailView: View {
    let streamURL: String

    var body: some View {
        LivePreviewPlayer(urlString: streamURL)
            .clipped()
    }
}

private struct LivePreviewPlayer: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.configure(with: urlString)
    }
}

private final class PlayerContainerView: UIView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var currentURL: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.masksToBounds = true
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func configure(with urlString: String) {
        guard currentURL != urlString else { return }
        currentURL = urlString
        teardown()
        guard let url = URL(string: urlString) else { return }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = false
        player.play()
        self.player = player

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        self.playerLayer = layer

        NotificationCenter.default.addObserver(self, selector: #selector(handleAppBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewsPause), name: NSNotification.Name("LivePreviewsShouldPause"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviewsResume), name: NSNotification.Name("LivePreviewsShouldResume"), object: nil)
    }

    @objc private func handleAppBackground() {
        player?.pause()
    }

    @objc private func handleAppForeground() {
        player?.play()
    }

    func teardown() {
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    @objc private func handlePreviewsPause() {
        player?.pause()
    }
    
    @objc private func handlePreviewsResume() {
        player?.play()
    }

    deinit {
        teardown()
    }
}
