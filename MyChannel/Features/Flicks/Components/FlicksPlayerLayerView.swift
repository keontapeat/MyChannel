import SwiftUI
import AVKit
import AVFoundation

struct FlicksPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    
    func makeUIView(context: Context) -> PlayerContainerView {
        let v = PlayerContainerView()
        v.backgroundColor = .black
        v.playerLayer.videoGravity = videoGravity
        v.playerLayer.player = player
        return v
    }
    
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity
    }
    
    final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

#Preview {
    let url = URL(string: Video.sampleVideos.first!.videoURL)!
    let player = AVPlayer(url: url)
    return FlicksPlayerLayerView(player: player, videoGravity: .resizeAspectFill)
        .frame(height: 300)
        .background(.black)
        .onAppear { player.play() }
        .preferredColorScheme(.dark)
}