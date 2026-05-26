import Foundation

/// GPT-4o agent layer — wraps the existing OpenAIService for agent-specific calls.
/// Adds moderation API, embeddings, and structured agent logging.
@MainActor
final class OpenAIAgentService: ObservableObject {
    static let shared = OpenAIAgentService()

    @Published var isAvailable = false
    @Published var lastTokensUsed: Int = 0
    @Published var totalCostEstimate: Double = 0.0

    private let baseURL = "https://api.openai.com/v1"

    private init() {
        isAvailable = !AppSecrets.openAIAPIKey.isEmpty
    }

    // MARK: - Run agent prompt via GPT-4o

    func runAgentPrompt(
        agentName: String,
        systemPrompt: String,
        userMessage: String,
        temperature: Double = 0.7,
        maxTokens: Int = 1024
    ) async throws -> String {
        guard isAvailable else { throw OpenAIAgentError.noAPIKey }
        let messages: [OpenAIService.ChatRequest.Message] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "user", content: userMessage)
        ]
        let result = try await OpenAIService.shared.chat(
            messages: messages,
            model: .gpt4o,
            temperature: temperature,
            maxTokens: maxTokens
        )
        AgentLogService.shared.agentCompleted(agentName, agentId: "openai", latencyMs: 0, output: result)
        return result
    }

    // MARK: - Content moderation via OpenAI Moderation API

    func moderateContent(_ text: String) async throws -> OpenAIModerationResult {
        guard isAvailable else {
            return OpenAIModerationResult(flagged: false, categories: [:], scores: [:])
        }
        guard let url = URL(string: "\(baseURL)/moderations") else {
            throw OpenAIAgentError.unavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppSecrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["input": text])

        let (data, _) = try await URLSession.configured.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = (json["results"] as? [[String: Any]])?.first else {
            return OpenAIModerationResult(flagged: false, categories: [:], scores: [:])
        }

        let flagged = results["flagged"] as? Bool ?? false
        let cats = results["categories"] as? [String: Bool] ?? [:]
        let scrs = results["category_scores"] as? [String: Double] ?? [:]
        return OpenAIModerationResult(flagged: flagged, categories: cats, scores: scrs)
    }

    // MARK: - Generate embeddings

    func generateEmbedding(for text: String) async throws -> [Double] {
        guard isAvailable else { return [] }
        guard let url = URL(string: "\(baseURL)/embeddings") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppSecrets.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "text-embedding-3-small",
            "input": text
        ])
        let (data, _) = try await URLSession.configured.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArr = (json["data"] as? [[String: Any]])?.first,
              let embedding = dataArr["embedding"] as? [Double] else { return [] }
        return embedding
    }

}

// MARK: - Supporting types

struct OpenAIModerationResult {
    let flagged: Bool
    let categories: [String: Bool]
    let scores: [String: Double]
    var maxScore: Double { scores.values.max() ?? 0 }
    var topCategory: String? { scores.max(by: { $0.value < $1.value })?.key }
}

enum OpenAIAgentError: Error {
    case noAPIKey
    case unavailable
    case rateLimited
}
