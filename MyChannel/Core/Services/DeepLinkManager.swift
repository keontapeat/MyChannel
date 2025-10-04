import Foundation
import UIKit

enum DeepLinkRoute: Equatable {
    case video(id: String)
    case user(id: String)
    case playlist(id: String)
    case live(streamId: String)
    case unknown
}

final class DeepLinkManager {
    static let shared = DeepLinkManager()
    private init() {}

    func handle(_ url: URL) {
        let route = parse(url)
        NotificationCenter.default.post(
            name: NSNotification.Name("HandleDeepLink"),
            object: nil,
            userInfo: ["route": route]
        )
    }

    func handleUniversalLink(_ activity: NSUserActivity) -> Bool {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL else { return false }
        handle(url)
        return true
    }

    private func parse(_ url: URL) -> DeepLinkRoute {
        // Support custom scheme mychannel:// and universal links https://mychannel.app
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let first = pathComponents.first else { return .unknown }

        switch first.lowercased() {
        case "video":
            if pathComponents.count >= 2 { return .video(id: pathComponents[1]) }
        case "user":
            if pathComponents.count >= 2 { return .user(id: pathComponents[1]) }
        case "playlist":
            if pathComponents.count >= 2 { return .playlist(id: pathComponents[1]) }
        case "live":
            if pathComponents.count >= 2 { return .live(streamId: pathComponents[1]) }
        default:
            break
        }
        return .unknown
    }
}



