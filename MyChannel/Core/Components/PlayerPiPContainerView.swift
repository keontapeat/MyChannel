//
//  PlayerPiPContainerView.swift
//  MyChannel
//
//  AVPlayerLayer-backed view that enables Picture-in-Picture.
//

import SwiftUI
import AVKit

struct PlayerPiPContainerView: UIViewRepresentable {
    let player: AVPlayer
    @Binding var isPictureInPictureActive: Bool

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        if AVPictureInPictureController.isPictureInPictureSupported() {
            context.coordinator.pipController = AVPictureInPictureController(playerLayer: view.playerLayer)
            context.coordinator.pipController?.delegate = context.coordinator
        }
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
        if isPictureInPictureActive {
            context.coordinator.startPiP()
        } else {
            context.coordinator.stopPiP()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(isActive: $isPictureInPictureActive) }

    final class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var pipController: AVPictureInPictureController?
        @Binding var isActive: Bool
        init(isActive: Binding<Bool>) { _isActive = isActive }
        func startPiP() { if pipController?.isPictureInPictureActive == false { pipController?.startPictureInPicture() } }
        func stopPiP() { if pipController?.isPictureInPictureActive == true { pipController?.stopPictureInPicture() } }
        func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) { isActive = true }
        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) { isActive = false }
    }
}

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}


