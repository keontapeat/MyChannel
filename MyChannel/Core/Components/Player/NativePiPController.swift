//
//  NativePiPController.swift
//  MyChannel
//
//  🔥🔥🔥 THERMONUCLEAR PERFORMANCE: Native iOS PiP
//  Target: <50ms PiP start time (YouTube-level performance)
//

import AVKit
import SwiftUI

@MainActor
class NativePiPController: NSObject, ObservableObject {
    static let shared = NativePiPController()
    
    @Published var isPiPActive = false
    private var pipController: AVPictureInPictureController?
    private var pipPossibleObservation: NSKeyValueObservation?
    private var playerLayer: AVPlayerLayer?  // 🔥 PERF: Keep reference for reuse
    private var lastPlayer: AVPlayer?  // 🔥 PERF: Track player to avoid redundant setup
    private var isPiPPossible = false  // 🔥 PERF: Cache state for instant checks
    private var retryTask: Task<Void, Never>?  // 🔥 PERF: Cancel previous retry tasks
    
    private override init() {
        super.init()
        print("🎬 [NativePiP] THERMONUCLEAR Initialized")
    }
    
    /// 🔥 THERMONUCLEAR: Setup PiP controller with instant readiness
    func setup(with player: AVPlayer) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            return  // 🔥 PERF: Silent fail for unsupported devices
        }
        
        // 🔥 PERF: Skip redundant setup if same player
        if lastPlayer === player && pipController != nil {
            print("⚡ [NativePiP] Reusing existing controller (same player)")
            return
        }
        
        // 🔥 PERF: Cancel any pending retry tasks
        retryTask?.cancel()
        
        // 🔥 PERF: Reuse player layer if possible
        if playerLayer == nil {
            playerLayer = AVPlayerLayer()
        }
        playerLayer?.player = player
        lastPlayer = player
        
        // 🔥 PERF: Setup controller immediately without async
        if let controller = AVPictureInPictureController(playerLayer: playerLayer!) {
            // 🔥 PERF: Invalidate old observer before creating new one
            pipPossibleObservation?.invalidate()
            
            controller.delegate = self
            controller.canStartPictureInPictureAutomaticallyFromInline = true
            pipController = controller
            
            // 🔥 PERF: Cache initial state
            isPiPPossible = controller.isPictureInPicturePossible
            
            // 🔥 PERF: Direct KVO with immediate state sync
            pipPossibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.new, .initial]) { [weak self] controller, _ in
                Task { @MainActor in
                    self?.isPiPPossible = controller.isPictureInPicturePossible
                }
            }
            
            print("✅ [NativePiP] Controller ready, possible: \(isPiPPossible)")
        }
    }
    
    /// 🔥 THERMONUCLEAR: Start PiP with <50ms target
    func startPiP() {
        guard let pipController = pipController else {
            return  // 🔥 PERF: Silent fail
        }
        
        // 🔥 PERF: Fast path check using cached state
        guard !pipController.isPictureInPictureActive else {
            return  // Already active
        }
        
        // 🔥 PERF: Immediate start if possible
        if isPiPPossible {
            pipController.startPictureInPicture()
            print("⚡ [NativePiP] Started PiP INSTANTLY")
            return
        }
        
        // 🔥 PERF: Aggressive retry with shorter delay (100ms instead of 500ms)
        retryTask?.cancel()
        retryTask = Task { @MainActor in
            // 🔥 PERF: Try every 100ms up to 1 second
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
                
                guard !Task.isCancelled else { return }
                
                if pipController.isPictureInPicturePossible {
                    pipController.startPictureInPicture()
                    print("✅ [NativePiP] Started PiP after retry")
                    return
                }
            }
            print("⚠️ [NativePiP] PiP not possible after retries")
        }
    }
    
    /// 🔥 THERMONUCLEAR: Stop PiP instantly
    func stopPiP() {
        retryTask?.cancel()
        
        guard let pipController = pipController,
              pipController.isPictureInPictureActive else {
            return  // 🔥 PERF: Silent fail
        }
        
        pipController.stopPictureInPicture()
    }
    
    /// 🔥 PERF: Fast check using cached state
    var isActive: Bool {
        pipController?.isPictureInPictureActive ?? false
    }
    
    /// 🔥 PERF: Check if PiP can start immediately
    var canStartImmediately: Bool {
        isPiPPossible && !(pipController?.isPictureInPictureActive ?? true)
    }
    
    /// Cleanup
    func cleanup() {
        retryTask?.cancel()
        retryTask = nil
        stopPiP()
        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil
        pipController = nil
        playerLayer = nil
        lastPlayer = nil
        isPiPPossible = false
    }
}

// MARK: - AVPictureInPictureControllerDelegate (THERMONUCLEAR OPTIMIZED)
extension NativePiPController: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isPiPActive = true
        }
    }
    
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isPiPActive = true
            print("✅ [NativePiP] PiP STARTED")
        }
    }
    
    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        // 🔥 PERF: No-op for will stop (state change happens in didStop)
    }
    
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            self?.isPiPActive = false
            print("✅ [NativePiP] PiP STOPPED")
        }
    }
    
    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isPiPActive = false
            print("❌ [NativePiP] Failed: \(error.localizedDescription)")
        }
    }
    
    nonisolated func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // 🔥 THERMONUCLEAR: Instant UI restore without delay
        Task { @MainActor [weak self] in
            self?.isPiPActive = false
            
            // 🔥 PERF: Post notification immediately
            NotificationCenter.default.post(
                name: NSNotification.Name("ExpandFromNativePiP"),
                object: nil
            )
            
            // 🔥 PERF: Complete immediately - no artificial delay
            completionHandler(true)
            print("⚡ [NativePiP] UI restored INSTANTLY")
        }
    }
}

