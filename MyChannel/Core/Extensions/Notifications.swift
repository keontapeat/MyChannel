import Foundation

extension Notification.Name {
    static let stopAllPlayback = Notification.Name("StopAllPlaybackNow")

    /// Posted when a gated feature (e.g. download quality upsell) asks the app
    /// to route the user to the Premium / subscription upgrade flow.
    static let navigateToPremium = Notification.Name("navigateToPremium")
}


