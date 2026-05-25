import ActivityKit
import Foundation

// MARK: - Live Activity Attributes (shared with Widget Extension)

struct LiveStreamActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var viewerCount: Int
        var title: String
        var isLive: Bool
        var durationSeconds: Int
    }

    var streamId: String
    var creatorName: String
    var creatorAvatarURL: String
}

// MARK: - Live Activity Service

/// Manages Dynamic Island + Lock Screen Live Activities for active live streams.
@MainActor
final class LiveActivityService: ObservableObject {
    static let shared = LiveActivityService()

    @Published var isActivityActive = false

    @available(iOS 16.1, *)
    private var currentActivity: Activity<LiveStreamActivityAttributes>? { _currentActivityStorage as? Activity<LiveStreamActivityAttributes> }
    private var _currentActivityStorage: AnyObject?

    private init() {}

    // MARK: - Start Live Activity

    func startLiveActivity(streamId: String,
                           creatorName: String,
                           creatorAvatarURL: String,
                           title: String,
                           viewerCount: Int) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = LiveStreamActivityAttributes(
            streamId: streamId,
            creatorName: creatorName,
            creatorAvatarURL: creatorAvatarURL
        )
        let initialState = LiveStreamActivityAttributes.ContentState(
            viewerCount: viewerCount,
            title: title,
            isLive: true,
            durationSeconds: 0
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            _currentActivityStorage = activity
            isActivityActive = true
        } catch {
            print("⚠️ [LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    // MARK: - Update viewer count & duration

    func updateLiveActivity(viewerCount: Int, durationSeconds: Int, title: String) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = _currentActivityStorage as? Activity<LiveStreamActivityAttributes> else { return }
        let newState = LiveStreamActivityAttributes.ContentState(
            viewerCount: viewerCount,
            title: title,
            isLive: true,
            durationSeconds: durationSeconds
        )
        Task {
            await activity.update(.init(state: newState, staleDate: nil))
        }
    }

    // MARK: - End Live Activity

    func endLiveActivity(finalViewerCount: Int) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = _currentActivityStorage as? Activity<LiveStreamActivityAttributes> else { return }
        let finalState = LiveStreamActivityAttributes.ContentState(
            viewerCount: finalViewerCount,
            title: "Stream ended",
            isLive: false,
            durationSeconds: 0
        )
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(30)))
            await MainActor.run { self.isActivityActive = false }
        }
        _currentActivityStorage = nil
    }
}
