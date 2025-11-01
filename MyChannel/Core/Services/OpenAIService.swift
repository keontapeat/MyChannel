//
//  OpenAIService.swift
//  MyChannel
//
//  OpenAI GPT-4 Integration
//  The world's most popular AI API
//
//  Created by Keonta on 11/1/25.
//

import Foundation
import Combine

/// Service for interacting with OpenAI's GPT-4 and DALL-E APIs
class OpenAIService: ObservableObject {
    static let shared = OpenAIService()
    
    private let baseURL = "https://api.openai.com/v1"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    private init() {}
    
    // MARK: - API Models
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double?
        let max_tokens: Int?
        let stream: Bool?
        
        struct Message: Codable {
            let role: String
            let content: String
        }
    }
    
    struct ChatResponse: Codable {
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [Choice]
        let usage: Usage
        
        struct Choice: Codable {
            let index: Int
            let message: Message
            let finish_reason: String?
            
            struct Message: Codable {
                let role: String
                let content: String
            }
        }
        
        struct Usage: Codable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int
        }
    }
    
    struct ImageGenerationRequest: Codable {
        let prompt: String
        let n: Int?
        let size: String?
        let quality: String?
        let model: String?
    }
    
    struct ImageGenerationResponse: Codable {
        let created: Int
        let data: [ImageData]
        
        struct ImageData: Codable {
            let url: String?
            let b64_json: String?
        }
    }
    
    // MARK: - GPT-4 Chat Completion
    
    /// Generate text using GPT-4
    func chat(
        messages: [ChatRequest.Message],
        model: GPTModel = .gpt4Turbo,
        temperature: Double = 0.7,
        maxTokens: Int = 1000
    ) async throws -> String {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        let apiKey = AppSecrets.openAIAPIKey
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ChatRequest(
            model: model.rawValue,
            messages: messages,
            temperature: temperature,
            max_tokens: maxTokens,
            stream: false
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        guard let firstChoice = chatResponse.choices.first else {
            throw OpenAIError.noResponseText
        }
        
        return firstChoice.message.content
    }
    
    /// Simple text generation
    func generate(
        _ prompt: String,
        model: GPTModel = .gpt4Turbo,
        temperature: Double = 0.7,
        maxTokens: Int = 1000
    ) async throws -> String {
        let messages = [
            ChatRequest.Message(role: "user", content: prompt)
        ]
        return try await chat(messages: messages, model: model, temperature: temperature, maxTokens: maxTokens)
    }
    
    // MARK: - DALL-E Image Generation
    
    /// Generate images using DALL-E 3
    func generateImage(
        prompt: String,
        size: ImageSize = .large,
        quality: OpenAIImageQuality = .standard,
        model: ImageModel = .dalle3
    ) async throws -> String {
        let apiKey = AppSecrets.openAIAPIKey
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)/images/generations") else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = ImageGenerationRequest(
            prompt: prompt,
            n: 1,
            size: size.rawValue,
            quality: quality.rawValue,
            model: model.rawValue
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        
        let imageResponse = try JSONDecoder().decode(ImageGenerationResponse.self, from: data)
        
        guard let imageURL = imageResponse.data.first?.url else {
            throw OpenAIError.noImageGenerated
        }
        
        return imageURL
    }
}

// MARK: - Supporting Types

enum GPTModel: String {
    case gpt4 = "gpt-4"
    case gpt4Turbo = "gpt-4-turbo-preview"
    case gpt4o = "gpt-4o"
    case gpt35Turbo = "gpt-3.5-turbo"
}

enum ImageModel: String {
    case dalle3 = "dall-e-3"
    case dalle2 = "dall-e-2"
}

enum ImageSize: String {
    case small = "256x256"
    case medium = "512x512"
    case large = "1024x1024"
    case portrait = "1024x1792"
    case landscape = "1792x1024"
}

enum OpenAIImageQuality: String {
    case standard = "standard"
    case hd = "hd"
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case noResponseText
    case noImageGenerated
    case apiError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Please add your API key to the app configuration."
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .noResponseText:
            return "No response text from OpenAI"
        case .noImageGenerated:
            return "No image was generated"
        case .apiError(let code, let message):
            return "OpenAI API error (\(code)): \(message)"
        }
    }
}

// MARK: - Creator Helper Extensions

extension OpenAIService {
    /// Generate video script
    func generateVideoScript(topic: String, duration: Int) async throws -> String {
        let prompt = """
        Write a compelling \(duration)-minute video script about: \(topic)
        
        Include:
        - Hook (first 10 seconds)
        - Main content with talking points
        - Call to action at the end
        - Timestamps for each section
        
        Make it engaging and authentic for YouTube/TikTok.
        """
        
        return try await generate(prompt, model: .gpt4Turbo)
    }
    
    /// Optimize video SEO
    func optimizeForSEO(title: String, description: String) async throws -> (title: String, description: String, tags: [String]) {
        let prompt = """
        Optimize this video for SEO:
        
        Title: \(title)
        Description: \(description)
        
        Provide:
        1. Optimized title (under 70 characters)
        2. SEO-friendly description with keywords
        3. 10-15 relevant tags
        
        Format as JSON:
        {
          "title": "...",
          "description": "...",
          "tags": ["tag1", "tag2", ...]
        }
        """
        
        let response = try await generate(prompt, model: .gpt4Turbo)
        
        // Parse JSON response
        if let data = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let optimizedTitle = json["title"] as? String,
           let optimizedDescription = json["description"] as? String,
           let tags = json["tags"] as? [String] {
            return (optimizedTitle, optimizedDescription, tags)
        }
        
        // Fallback if JSON parsing fails
        return (title, description, [])
    }
    
    /// Generate thumbnail text suggestions
    func generateThumbnailText(videoTitle: String) async throws -> [String] {
        let prompt = """
        Generate 5 short, punchy text overlays for a video thumbnail.
        Video title: "\(videoTitle)"
        
        Each should be:
        - 1-4 words maximum
        - Bold and attention-grabbing
        - Readable at small sizes
        
        Return only the text options, one per line.
        """
        
        let response = try await generate(prompt, model: .gpt4Turbo, maxTokens: 200)
        return response.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    /// Brainstorm content ideas
    func brainstormContentIdeas(niche: String, count: Int = 10) async throws -> [String] {
        let prompt = """
        Generate \(count) viral video ideas for a \(niche) creator.
        
        Each idea should be:
        - Unique and creative
        - Highly engaging
        - Suitable for YouTube/TikTok
        - Specific and actionable
        
        Return only the video titles, one per line.
        """
        
        let response = try await generate(prompt, model: .gpt4Turbo)
        return response.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    /// Generate custom thumbnail using DALL-E
    func generateCustomThumbnail(concept: String) async throws -> String {
        let prompt = """
        Create a YouTube thumbnail image: \(concept)
        
        Style: Bold, eye-catching, professional
        Colors: Vibrant and contrasting
        Composition: Clear focal point, text-friendly
        Quality: High-resolution, crisp
        """
        
        return try await generateImage(prompt: prompt, size: ImageSize.landscape, quality: OpenAIImageQuality.hd)
    }
    
    /// Analyze competitor content
    func analyzeCompetitorStrategy(competitorInfo: String) async throws -> String {
        let prompt = """
        Analyze this competitor's content strategy:
        
        \(competitorInfo)
        
        Provide:
        1. Their key success factors
        2. Content patterns and themes
        3. Engagement tactics
        4. Gaps you can exploit
        5. Recommendations for differentiation
        """
        
        return try await generate(prompt, model: .gpt4Turbo, maxTokens: 1500)
    }
    
    /// Write engaging video descriptions
    func writeDescription(videoTitle: String, keyPoints: [String]) async throws -> String {
        let prompt = """
        Write an engaging YouTube video description for:
        Title: "\(videoTitle)"
        
        Key points to cover:
        \(keyPoints.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        
        Include:
        - Compelling intro paragraph
        - Timestamps for sections
        - Relevant hashtags
        - Call to action
        - SEO keywords naturally integrated
        """
        
        return try await generate(prompt, model: .gpt4Turbo)
    }
}

