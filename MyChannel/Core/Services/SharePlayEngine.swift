import Foundation
import GroupActivities
import AVFoundation
import Combine

/// The activity that represents watching a video together.
struct WatchVideoActivity: GroupActivity {
    var videoId: String
    
    // Metadata for the SharePlay UI
    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Watching MyChannel"
        meta.type = .watchTogether
        return meta
    }
}

/// Phase 90: Collaborative Group FaceTime (SharePlay)
/// Integrates GroupActivities framework to watch videos perfectly synced during a FaceTime call.
@MainActor
final class SharePlayEngine: ObservableObject {
    static let shared = SharePlayEngine()
    
    @Published var groupSession: GroupSession<WatchVideoActivity>?
    @Published var isEligibleForSharePlay: Bool = false
    
    private var tasks = Set<Task<Void, Never>>()
    private var cancellables = Set<AnyCancellable>()
    private let groupStateObserver = GroupStateObserver()
    private weak var player: AVPlayer?
    
    private init() {
        // Monitor eligibility
        groupStateObserver.$isEligibleForGroupSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] eligibility in
                self?.isEligibleForSharePlay = eligibility
            }
            .store(in: &cancellables)
        
        // Listen for incoming SharePlay sessions
        Task {
            for await session in WatchVideoActivity.sessions() {
                self.configureGroupSession(session)
            }
        }
    }
    
    func attach(player: AVPlayer) {
        self.player = player
    }
    
    /// Starts a new SharePlay session for the given video
    func startSharePlay(videoId: String) {
        let activity = WatchVideoActivity(videoId: videoId)
        Task {
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                do {
                    _ = try await activity.activate()
                    print("👥 [SharePlay] Activated SharePlay for video \(videoId)")
                } catch {
                    print("⚠️ [SharePlay] Failed to activate: \(error)")
                }
            case .activationDisabled:
                print("⚠️ [SharePlay] Activation disabled by user or system.")
            case .cancelled:
                print("⚠️ [SharePlay] Activation cancelled.")
            @unknown default:
                break
            }
        }
    }
    
    private func configureGroupSession(_ session: GroupSession<WatchVideoActivity>) {
        self.groupSession = session
        
        // When the session state changes
        let stateTask = Task {
            for await state in session.$state.values {
                if case .invalidated = state {
                    self.groupSession = nil
                    // Stop coordinating playback by omitting or passing typed nil
                }
            }
        }
        tasks.insert(stateTask)
        
        session.join()
        
        // Coordinate the AVPlayer with the GroupSession
        if let player = self.player {
            player.playbackCoordinator.coordinateWithSession(session)
            print("👥 [SharePlay] Coordinated AVPlayer with SharePlay session.")
        }
    }
}
