//
//  PlayerPiPContainerView.swift
//  MyChannel
//

import SwiftUI
import AVKit

/// Invisible host view that wires the active AVPlayer into AVPictureInPictureController
/// so the system PiP bubble (shown when leaving the app) can mirror YouTube exactly.
struct PlayerPiPContainerView: UIViewRepresentable {
    let player: AVPlayer?
    @Binding var isPictureInPictureActive: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> PiPHostView {
        let view = PiPHostView()
        view.isHidden = true
        context.coordinator.attach(hostView: view)
        return view
    }
    
    func updateUIView(_ uiView: PiPHostView, context: Context) {
        context.coordinator.parent = self
        uiView.playerLayer.player = player
        context.coordinator.attach(hostView: uiView)
        context.coordinator.refreshPiPConfiguration()
    }
    
    static func dismantleUIView(_ uiView: PiPHostView, coordinator: Coordinator) {
        coordinator.detach(hostView: uiView)
    }
    
    // MARK: - Host View
    final class PiPHostView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var pipController: AVPictureInPictureController?
    }
    
    // MARK: - Coordinator / Delegate
    @MainActor
    final class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var parent: PlayerPiPContainerView
        weak var hostView: PiPHostView?
        private let globalPlayer = GlobalVideoPlayerManager.shared
        
        init(_ parent: PlayerPiPContainerView) {
            self.parent = parent
        }
        
        func attach(hostView: PiPHostView) {
            if self.hostView !== hostView {
                self.hostView = hostView
            }
            refreshPiPConfiguration()
        }
        
        @MainActor
        func detach(hostView: PiPHostView) {
            guard self.hostView === hostView else { return }
            if let controller = hostView.pipController {
                if controller.isPictureInPictureActive {
                    controller.stopPictureInPicture()
                }
                Task { @MainActor [globalPlayer] in
                    globalPlayer.clearPictureInPicture(controller: controller)
                }
            }
            self.hostView = nil
        }
        
        @MainActor
        func refreshPiPConfiguration() {
            guard let hostView, let player = parent.player else { return }
            hostView.playerLayer.player = player
            
            guard AVPictureInPictureController.isPictureInPictureSupported() else {
                print("⚠️ [PlayerPiPContainerView] PiP not supported on this device")
                return
            }
            
            if hostView.pipController == nil {
                let controller = AVPictureInPictureController(playerLayer: hostView.playerLayer)
                controller?.delegate = self
                hostView.pipController = controller
            }
            
            if let controller = hostView.pipController {
                Task { @MainActor [globalPlayer] in
                    globalPlayer.setupPictureInPicture(for: hostView.playerLayer, controller: controller)
                }
            }
        }
        
        // MARK: - AVPictureInPictureControllerDelegate
        func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            updatePiPState(true)
        }
        
        @MainActor
        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            updatePiPState(false)
            Task { @MainActor [globalPlayer] in
                globalPlayer.handlePiPDidStopFromSystem()
            }
        }
        
        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            NotificationCenter.default.post(name: NSNotification.Name("PresentVideoDetailFromMiniPlayer"), object: nil)
            completionHandler(true)
        }
        
        private func updatePiPState(_ isActive: Bool) {
            Task { @MainActor in
                self.parent.isPictureInPictureActive = isActive
                self.globalPlayer.handlePiPStateChange(isActive: isActive)
            }
        }
    }
}
