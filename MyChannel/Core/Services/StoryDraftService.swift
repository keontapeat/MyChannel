import Foundation

struct StoryDraft: Codable {
    let creatorId: String
    let caption: String
    let audience: String
    let stickers: [CreateStoryViewModel.StickerItemCodable]
    let textOverlay: CreateStoryViewModel.TextOverlayCodable?
    let backgroundColors: [String]
    let mediaURL: String?
    let mediaType: String?
}

@MainActor
final class StoryDraftService {
    static let shared = StoryDraftService()
    private let defaults = UserDefaults.standard

    private init() {}

    private func key(for creatorId: String) -> String {
        "story_draft_\(creatorId)"
    }

    func saveDraft(_ draft: StoryDraft, creatorId: String) {
        if let data = try? JSONEncoder().encode(draft) {
            defaults.set(data, forKey: key(for: creatorId))
        }
    }

    func loadDraft(creatorId: String) -> StoryDraft? {
        guard let data = defaults.data(forKey: key(for: creatorId)) else { return nil }
        return try? JSONDecoder().decode(StoryDraft.self, from: data)
    }

    func clearDraft(creatorId: String) {
        defaults.removeObject(forKey: key(for: creatorId))
    }
}
