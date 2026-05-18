import AppIntents
import Foundation

// MARK: - Play Subscriptions Intent

struct PlaySubscriptionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Play My Subscriptions"
    static var description = IntentDescription("Start playing your subscription feed on MyChannel.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .intentPlaySubscriptions, object: nil)
        return .result()
    }
}

// MARK: - Open Live TV Intent

struct OpenLiveTVIntent: AppIntent {
    static var title: LocalizedStringResource = "Open MyChannel Live TV"
    static var description = IntentDescription("Jump straight into MyChannel Live TV.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .intentOpenLiveTV, object: nil)
        return .result()
    }
}

// MARK: - Search Videos Intent

struct SearchVideosIntent: AppIntent {
    static var title: LocalizedStringResource = "Search MyChannel"
    static var description = IntentDescription("Search for videos on MyChannel.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Search Query")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .intentSearch, object: query)
        return .result()
    }
}

// MARK: - Open Creator Studio Intent

struct OpenCreatorStudioIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Creator Studio"
    static var description = IntentDescription("Open the MyChannel Creator Studio.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .intentOpenCreatorStudio, object: nil)
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct MyChannelAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlaySubscriptionsIntent(),
            phrases: [
                "Play my subscriptions on \(.applicationName)",
                "Open \(.applicationName) feed",
                "Start \(.applicationName)"
            ],
            shortTitle: "Play Subscriptions",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: OpenLiveTVIntent(),
            phrases: [
                "Open \(.applicationName) Live TV",
                "Watch live on \(.applicationName)"
            ],
            shortTitle: "Live TV",
            systemImageName: "tv.fill"
        )
        AppShortcut(
            intent: SearchVideosIntent(),
            phrases: [
                "Search \(.applicationName)",
                "Find something on \(.applicationName)"
            ],
            shortTitle: "Search Videos",
            systemImageName: "magnifyingglass"
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let intentPlaySubscriptions = Notification.Name("intentPlaySubscriptions")
    static let intentOpenLiveTV        = Notification.Name("intentOpenLiveTV")
    static let intentSearch            = Notification.Name("intentSearch")
    static let intentOpenCreatorStudio = Notification.Name("intentOpenCreatorStudio")
}
