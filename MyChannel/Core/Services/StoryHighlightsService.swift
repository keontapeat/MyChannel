import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct StoryHighlight: Identifiable, Codable, Equatable {
    let id: String
    let creatorId: String
    var title: String
    var coverImageURL: String
    var storyIds: [String]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        creatorId: String,
        title: String,
        coverImageURL: String,
        storyIds: [String],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.creatorId = creatorId
        self.title = title
        self.coverImageURL = coverImageURL
        self.storyIds = storyIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@MainActor
final class StoryHighlightsService: ObservableObject {
    static let shared = StoryHighlightsService()

    @Published private(set) var highlights: [StoryHighlight] = []

    private init() {}

    func loadHighlights(creatorId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await Firestore.firestore()
                .collection("story_highlights")
                .whereField("creatorId", isEqualTo: creatorId)
                .getDocuments()

            let decoded = snapshot.documents.compactMap { doc -> StoryHighlight? in
                let data = doc.data()
                return StoryHighlight(
                    id: doc.documentID,
                    creatorId: data["creatorId"] as? String ?? creatorId,
                    title: data["title"] as? String ?? "Highlight",
                    coverImageURL: data["coverImageURL"] as? String ?? "",
                    storyIds: data["storyIds"] as? [String] ?? [],
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            highlights = decoded.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("🚨 [StoryHighlightsService] Failed to load highlights: \(error.localizedDescription)")
        }
        #endif
    }

    func addStoryToHighlight(story: Story, title: String) async {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            let existing = try await db.collection("story_highlights")
                .whereField("creatorId", isEqualTo: story.creatorId)
                .whereField("title", isEqualTo: title)
                .getDocuments()

            if let doc = existing.documents.first {
                var storyIds = doc.data()["storyIds"] as? [String] ?? []
                if !storyIds.contains(story.id) {
                    storyIds.append(story.id)
                }
                try await doc.reference.setData([
                    "creatorId": story.creatorId,
                    "title": title,
                    "coverImageURL": doc.data()["coverImageURL"] as? String ?? story.mediaURL,
                    "storyIds": storyIds,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            } else {
                let highlight = StoryHighlight(
                    creatorId: story.creatorId,
                    title: title,
                    coverImageURL: story.mediaURL,
                    storyIds: [story.id]
                )
                try await db.collection("story_highlights").document(highlight.id).setData([
                    "creatorId": highlight.creatorId,
                    "title": highlight.title,
                    "coverImageURL": highlight.coverImageURL,
                    "storyIds": highlight.storyIds,
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            }
            await loadHighlights(creatorId: story.creatorId)
        } catch {
            print("🚨 [StoryHighlightsService] Failed to add story to highlight: \(error.localizedDescription)")
        }
        #endif
    }

    func updateHighlightCover(highlightId: String, coverImageURL: String) async {
        #if canImport(FirebaseFirestore)
        do {
            try await Firestore.firestore()
                .collection("story_highlights")
                .document(highlightId)
                .setData([
                    "coverImageURL": coverImageURL,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)

            if let index = highlights.firstIndex(where: { $0.id == highlightId }) {
                highlights[index].coverImageURL = coverImageURL
                highlights[index].updatedAt = Date()
            }
        } catch {
            print("🚨 [StoryHighlightsService] Failed to update highlight cover: \(error.localizedDescription)")
        }
        #endif
    }
}
