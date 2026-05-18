import Foundation

@MainActor
final class StoryCreatorAssistService: ObservableObject {
    static let shared = StoryCreatorAssistService()
    private init() {}

    func mentionSuggestions(query: String, userId: String?) async -> [String] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        do {
            try await AutocompleteV3Service.shared.fetch(query: query, userId: userId)
            return AutocompleteV3Service.shared.suggestions
                .map { $0.text.replacingOccurrences(of: "@", with: "") }
                .filter { !$0.isEmpty }
                .prefix(8)
                .map { $0 }
        } catch {
            return []
        }
    }

    func gifSuggestions(query: String) async -> [String] {
        let fallback = ["🔥", "✨", "😂", "💯", "😍", "🎉", "❤️", "🚀"]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return fallback.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }
}
