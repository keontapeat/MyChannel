import CoreSpotlight
import MobileCoreServices
import Foundation

/// Indexes videos and creators into iOS Spotlight Search so users can find content from the home screen.
final class SpotlightIndexingService {
    static let shared = SpotlightIndexingService()

    private let domainIdentifier = "live.mychannel.app.videos"
    private let creatorDomain    = "live.mychannel.app.creators"

    private init() {}

    // MARK: - Index Videos

    func indexVideos(_ videos: [SpotlightVideo]) {
        let items: [CSSearchableItem] = videos.map { video in
            let attrs = CSSearchableItemAttributeSet(contentType: .audiovisualContent)
            attrs.title       = video.title
            attrs.contentDescription = video.description
            attrs.thumbnailURL = video.thumbnailURL
            attrs.keywords    = video.tags
            attrs.creator     = video.creatorName
            attrs.duration    = NSNumber(value: video.durationSeconds)

            return CSSearchableItem(
                uniqueIdentifier: "video:\(video.id)",
                domainIdentifier: domainIdentifier,
                attributeSet: attrs
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error { print("⚠️ [Spotlight] Index error: \(error.localizedDescription)") }
        }
    }

    // MARK: - Index Creators

    func indexCreators(_ creators: [SpotlightCreator]) {
        let items: [CSSearchableItem] = creators.map { creator in
            let attrs = CSSearchableItemAttributeSet(contentType: .contact)
            attrs.title              = creator.displayName
            attrs.contentDescription = creator.bio
            attrs.thumbnailURL       = creator.avatarURL
            attrs.keywords           = ["creator", "channel", creator.displayName]

            return CSSearchableItem(
                uniqueIdentifier: "creator:\(creator.id)",
                domainIdentifier: creatorDomain,
                attributeSet: attrs
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error { print("⚠️ [Spotlight] Creator index error: \(error.localizedDescription)") }
        }
    }

    // MARK: - Remove stale entries

    func deindexVideo(id: String) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["video:\(id)"]) { _ in }
    }

    func clearAll() {
        CSSearchableIndex.default().deleteAllSearchableItems { _ in }
    }

    // MARK: - Handle Spotlight tap

    static func handleActivity(_ userActivity: NSUserActivity) -> String? {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }

        if identifier.hasPrefix("video:") { return String(identifier.dropFirst(6)) }
        if identifier.hasPrefix("creator:") { return String(identifier.dropFirst(8)) }
        return nil
    }
}

// MARK: - Data Models

struct SpotlightVideo {
    let id: String
    let title: String
    let description: String
    let thumbnailURL: URL?
    let creatorName: String
    let tags: [String]
    let durationSeconds: Double
}

struct SpotlightCreator {
    let id: String
    let displayName: String
    let bio: String
    let avatarURL: URL?
}
