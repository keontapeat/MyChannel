//
//  AnthropicService.swift
//  MyChannel
//
//  Created by Keonta on 11/1/25.
//

import Foundation
import Combine

/// Service for interacting with Anthropic's Claude API
class AnthropicService: ObservableObject {
    static let shared = AnthropicService()
    
    private let baseURL = "https://api.anthropic.com/v1"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    private init() {}
    
    // MARK: - API Models
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct ChatRequest: Codable {
        let model: String
        let max_tokens: Int
        let messages: [Message]
        let system: String?
        
        init(model: String = "claude-sonnet-4-20250514", maxTokens: Int = 1024, messages: [Message], system: String? = nil) {
            self.model = model
            self.max_tokens = maxTokens
            self.messages = messages
            self.system = system
        }
    }
    
    struct ChatResponse: Codable {
        let id: String
        let type: String
        let role: String
        let content: [ContentBlock]
        let model: String
        let stop_reason: String?
        let usage: Usage
        
        struct ContentBlock: Codable {
            let type: String
            let text: String
        }
        
        struct Usage: Codable {
            let input_tokens: Int
            let output_tokens: Int
        }
    }
    
    // MARK: - Public Methods
    
    /// Send a chat message to Claude
    func sendMessage(
        _ message: String,
        system: String? = nil,
        model: String = "claude-sonnet-4-20250514",
        maxTokens: Int = 1024
    ) async throws -> String {
        let apiKey = AppSecrets.anthropicAPIKey
        guard !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }
        
        let messages = [Message(role: "user", content: message)]
        let request = ChatRequest(
            model: model,
            maxTokens: maxTokens,
            messages: messages,
            system: system
        )
        
        return try await performChatRequest(request, apiKey: apiKey)
    }
    
    /// Send a conversation to Claude
    func sendConversation(
        _ messages: [Message],
        system: String? = nil,
        model: String = "claude-sonnet-4-20250514",
        maxTokens: Int = 1024
    ) async throws -> String {
        let apiKey = AppSecrets.anthropicAPIKey
        guard !apiKey.isEmpty else {
            throw AnthropicError.missingAPIKey
        }
        
        let request = ChatRequest(
            model: model,
            maxTokens: maxTokens,
            messages: messages,
            system: system
        )
        
        return try await performChatRequest(request, apiKey: apiKey)
    }
    
    // MARK: - Private Methods
    
    private func performChatRequest(_ request: ChatRequest, apiKey: String) async throws -> String {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AnthropicError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AnthropicError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AnthropicError.apiError(httpResponse.statusCode, errorMessage)
            }
            
            let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
            
            // Extract text from content blocks
            let responseText = chatResponse.content
                .compactMap { $0.type == "text" ? $0.text : nil }
                .joined(separator: "\n")
            
            return responseText
            
        } catch let error as AnthropicError {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            throw error
        } catch {
            let anthropicError = AnthropicError.networkError(error)
            await MainActor.run {
                lastError = anthropicError.localizedDescription
            }
            throw anthropicError
        }
    }
}

// MARK: - Error Types

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(Int, String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key is missing. Please add your API key to the app configuration."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from Anthropic API"
        case .apiError(let code, let message):
            return "Anthropic API error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Convenience Extensions

extension AnthropicService {
    /// Generate content ideas for creators
    func generateContentIdeas(for topic: String, style: String = "engaging") async throws -> String {
        let system = """
        You are a creative assistant helping content creators generate engaging video ideas. 
        Provide practical, actionable suggestions that would work well for social media platforms.
        """
        
        let message = """
        Generate 5 creative video content ideas for the topic: "\(topic)"
        Style preference: \(style)
        
        For each idea, include:
        - A catchy title
        - Brief description (1-2 sentences)
        - Key elements that would make it engaging
        
        Format as a numbered list.
        """
        
        return try await sendMessage(message, system: system)
    }
    
    /// Improve video descriptions
    func improveVideoDescription(_ description: String) async throws -> String {
        let system = """
        You are a social media expert helping creators optimize their video descriptions for better engagement and discoverability.
        """
        
        let message = """
        Please improve this video description to make it more engaging and SEO-friendly:
        
        "\(description)"
        
        Make it:
        - More compelling and engaging
        - Better for search discovery
        - Include relevant hashtags
        - Maintain the original tone and message
        """
        
        return try await sendMessage(message, system: system)
    }
    
    /// Generate video titles
    func generateVideoTitles(for description: String, count: Int = 5) async throws -> String {
        let system = """
        You are a content strategist specializing in creating compelling video titles that drive clicks and engagement.
        """
        
        let message = """
        Based on this video description, generate \(count) compelling titles:
        
        "\(description)"
        
        Make the titles:
        - Attention-grabbing and clickable
        - Clear about the video content
        - Optimized for social media algorithms
        - Varied in style and approach
        
        Format as a numbered list.
        """
        
        return try await sendMessage(message, system: system)
    }
}
