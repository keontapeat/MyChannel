#if canImport(OpenAI)
import OpenAI
#endif
import Foundation

/// GPT-4o inference layer for AGI agents — fallback/primary alongside Gemini.
/// Wires directly into AGIAgentManager.callAgent() as a second model provider.
@MainActor
final class OpenAIAgentService: ObservableObject {
    static let shared = OpenAIAgentService()

    @Published var isAvailable = false
    @Published var lastTokensUsed: Int = 0
    @Published var totalCostEstimate: Double = 0.0

    private var apiKey: String {
        AppSecrets.openAIAPIKey
    }

    private init() {
        isAvailable = !apiKey.isEmpty
    }

    // MARK: - Run agent prompt via GPT-4o

    func runAgentPrompt(
        agentName: String,
        systemPrompt: String,
        userMessage: String,
        temperature: Double = 0.7,
        maxTokens: Int = 1024
    ) async throws -> String {
        guard isAvailable else {
            throw OpenAIAgentError.noAPIKey
        }

        #if canImport(OpenAI)
        let client = OpenAI(apiToken: apiKey)
        let query = ChatQuery(
            messages: [
                .init(role: .system, content: systemPrompt)!,
                .init(role: .user, content: userMessage)!
            ],
            model: .gpt4_o,
            maxTokens: maxTokens,
            temperature: temperature
        )
        let result = try await client.chats(query: query)
        let output = result.choices.first?.message.content?.string ?? ""
        let tokens = result.usage?.totalTokens ?? 0
        lastTokensUsed = tokens
        totalCostEstimate += Double(tokens) * 0.000015  // ~$15/1M tokens
        AgentLogService.shared.agentCompleted(agentName, agentId: "openai", latencyMs: 0, output: output)
        return output
        #else
        throw OpenAIAgentError.unavailable
        #endif
    }

    // MARK: - Content moderation via OpenAI Moderation API

    func moderateContent(_ text: String) async throws -> ModerationResult {
        guard isAvailable else { return ModerationResult(flagged: false, categories: [:], scores: [:]) }
        #if canImport(OpenAI)
        let client = OpenAI(apiToken: apiKey)
        let query = ModerationsQuery(input: .string(text))
        let result = try await client.moderations(query: query)
        let flagged = result.results.first?.flagged ?? false
        var categories: [String: Bool] = [:]
        var scores: [String: Double] = [:]
        if let cats = result.results.first?.categories {
            categories = [
                "hate": cats.hate,
                "harassment": cats.harassment,
                "violence": cats.violence,
                "sexual": cats.sexual
            ]
        }
        if let s = result.results.first?.categoryScores {
            scores = [
                "hate": s.hate,
                "harassment": s.harassment,
                "violence": s.violence,
                "sexual": s.sexual
            ]
        }
        return ModerationResult(flagged: flagged, categories: categories, scores: scores)
        #else
        return ModerationResult(flagged: false, categories: [:], scores: [:])
        #endif
    }

    // MARK: - Generate embeddings for semantic search

    func generateEmbedding(for text: String) async throws -> [Double] {
        guard isAvailable else { return [] }
        #if canImport(OpenAI)
        let client = OpenAI(apiToken: apiKey)
        let query = EmbeddingsQuery(model: .textEmbeddingAda002, input: text)
        let result = try await client.embeddings(query: query)
        return result.data.first?.embedding ?? []
        #else
        return []
        #endif
    }

    // MARK: - Streaming agent response

    func streamAgentResponse(
        systemPrompt: String,
        userMessage: String,
        onToken: @escaping (String) -> Void
    ) async throws {
        guard isAvailable else { throw OpenAIAgentError.noAPIKey }
        #if canImport(OpenAI)
        let client = OpenAI(apiToken: apiKey)
        let query = ChatQuery(
            messages: [
                .init(role: .system, content: systemPrompt)!,
                .init(role: .user, content: userMessage)!
            ],
            model: .gpt4_o,
            stream: true
        )
        for try await result in client.chatsStream(query: query) {
            if let token = result.choices.first?.delta.content {
                await MainActor.run { onToken(token) }
            }
        }
        #endif
    }
}

// MARK: - Supporting types

struct ModerationResult {
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
