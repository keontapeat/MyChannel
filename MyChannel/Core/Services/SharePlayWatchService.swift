import GroupActivities
import Combine
import Foundation

// MARK: - Codable message type for GroupSessionMessenger

struct SharePlayMessage: Codable {
    enum MessageType: String, Codable { case seek, playback }
    let type: MessageType
    let position: Double?
    let isPlaying: Bool?
}

// MARK: - Watch Together Activity

struct WatchTogetherActivity: GroupActivity {
    let videoId: String
    let videoTitle: String
    let videoURL: String

    static var activityIdentifier = "live.mychannel.app.watch-together"

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.type = .watchTogether
        meta.title = videoTitle
        meta.fallbackURL = URL(string: "mychannel://video/\(videoId)")
        return meta
    }
}

// MARK: - SharePlay Watch Service

/// Enables real-time synchronized video watching via FaceTime SharePlay.
@MainActor
final class SharePlayWatchService: ObservableObject {
    static let shared = SharePlayWatchService()

    @Published var isSharePlayActive = false
    @Published var participantCount: Int = 0
    @Published var sharedVideoId: String?

    private var groupSession: GroupSession<WatchTogetherActivity>?
    private var messenger: GroupSessionMessenger?
    private var subscriptions = Set<AnyCancellable>()
    private var tasks = Set<Task<Void, Never>>()

    private init() {}

    // MARK: - Start SharePlay

    func startWatchTogether(videoId: String, videoTitle: String, videoURL: String) async {
        let activity = WatchTogetherActivity(
            videoId: videoId,
            videoTitle: videoTitle,
            videoURL: videoURL
        )
        switch await activity.prepareForActivation() {
        case .activationPreferred:
            do {
                _ = try await activity.activate()
            } catch {
                print("⚠️ [SharePlay] Activation error: \(error)")
            }
        case .cancelled:
            break
        default:
            break
        }
    }

    // MARK: - Join incoming SharePlay session

    func configureGroupSessions() {
        let task = Task {
            for await session in WatchTogetherActivity.sessions() {
                await self.configureSession(session)
            }
        }
        tasks.insert(task)
    }

    private func configureSession(_ session: GroupSession<WatchTogetherActivity>) async {
        groupSession = session
        messenger = GroupSessionMessenger(session: session)
        sharedVideoId = session.activity.videoId
        isSharePlayActive = true

        session.$activeParticipants
            .sink { [weak self] participants in
                self?.participantCount = participants.count
            }
            .store(in: &subscriptions)

        session.$state
            .sink { [weak self] state in
                if case .invalidated = state {
                    self?.isSharePlayActive = false
                    self?.groupSession = nil
                    self?.sharedVideoId = nil
                }
            }
            .store(in: &subscriptions)

        session.join()
        listenForMessages()
    }

    // MARK: - Sync playback position

    func broadcastSeek(to seconds: Double) {
        guard let messenger else { return }
        Task {
            try? await messenger.send(SharePlayMessage(type: .seek, position: seconds, isPlaying: nil))
        }
    }

    func broadcastPlayPause(isPlaying: Bool) {
        guard let messenger else { return }
        Task {
            try? await messenger.send(SharePlayMessage(type: .playback, position: nil, isPlaying: isPlaying))
        }
    }

    private func listenForMessages() {
        guard let messenger else { return }
        let task = Task {
            for await (message, _) in messenger.messages(of: SharePlayMessage.self) {
                await handleMessage(message)
            }
        }
        tasks.insert(task)
    }

    private func handleMessage(_ message: SharePlayMessage) {
        switch message.type {
        case .seek:
            if let position = message.position {
                NotificationCenter.default.post(name: .sharePlaySeek, object: position)
            }
        case .playback:
            if let isPlaying = message.isPlaying {
                NotificationCenter.default.post(name: .sharePlayPlayback, object: isPlaying)
            }
        }
    }

    func endSession() {
        groupSession?.leave()
        groupSession = nil
        isSharePlayActive = false
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        subscriptions.removeAll()
    }
}

extension Notification.Name {
    static let sharePlaySeek     = Notification.Name("sharePlaySeek")
    static let sharePlayPlayback = Notification.Name("sharePlayPlayback")
}
