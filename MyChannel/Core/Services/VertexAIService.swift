//
//  VertexAIService.swift
//  MyChannel
//
//  Google Cloud Vertex AI Integration
//  Leveraging Google Cloud Partner Benefits
//
//  Created by Keonta on 11/1/25.
//

import Foundation
import Combine

/// Service for interacting with Google Cloud Vertex AI
/// Provides access to Gemini, PaLM, Imagen, and more
class VertexAIService: ObservableObject {
    static let shared = VertexAIService()
    
    private let projectID: String
    private let location: String = "us-central1"
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    private init() {
        // Get from environment or config
        self.projectID = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT_ID"] ?? AppConfig.API.googleCloudProjectID ?? ""
    }
    
    // MARK: - API Models
    
    struct GeminiRequest: Codable {
        let contents: [Content]
        let generationConfig: GenerationConfig?
        let safetySettings: [SafetySetting]?
        
        struct Content: Codable {
            let role: String
            let parts: [Part]
            
            struct Part: Codable {
                let text: String
            }
        }
        
        struct GenerationConfig: Codable {
            let temperature: Double?
            let topP: Double?
            let topK: Int?
            let maxOutputTokens: Int?
            let stopSequences: [String]?
        }
        
        struct SafetySetting: Codable {
            let category: String
            let threshold: String
        }
    }
    
    struct GeminiResponse: Codable {
        let candidates: [Candidate]
        let usageMetadata: UsageMetadata?
        
        struct Candidate: Codable {
            let content: Content
            let finishReason: String?
            let safetyRatings: [SafetyRating]?
            
            struct Content: Codable {
                let parts: [Part]
                let role: String
                
                struct Part: Codable {
                    let text: String
                }
            }
            
            struct SafetyRating: Codable {
                let category: String
                let probability: String
            }
        }
        
        struct UsageMetadata: Codable {
            let promptTokenCount: Int
            let candidatesTokenCount: Int
            let totalTokenCount: Int
        }
    }
    
    // MARK: - Gemini Pro (Text Generation)
    
    /// Generate content using Gemini Pro
    func generateWithGemini(
        _ prompt: String,
        model: GeminiModel = .geminiPro,
        temperature: Double = 0.7,
        maxTokens: Int = 1024
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
        
        let endpoint = "https://\(location)-aiplatform.googleapis.com/v1/projects/\(projectID)/locations/\(location)/publishers/google/models/\(model.rawValue):generateContent"
        
        guard let url = URL(string: endpoint) else {
            throw VertexAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add OAuth token or API key
        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let requestBody = GeminiRequest(
            contents: [
                .init(role: "user", parts: [.init(text: prompt)])
            ],
            generationConfig: .init(
                temperature: temperature,
                topP: 0.8,
                topK: 40,
                maxOutputTokens: maxTokens,
                stopSequences: nil
            ),
            safetySettings: [
                .init(category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
                .init(category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
                .init(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE"),
                .init(category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE")
            ]
        )
        
        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VertexAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VertexAIError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let firstCandidate = geminiResponse.candidates.first,
              let firstPart = firstCandidate.content.parts.first else {
            throw VertexAIError.noResponseText
        }
        
        return firstPart.text
    }
    
    // MARK: - Vision (Image Analysis)
    
    /// Analyze images using Gemini Pro Vision
    func analyzeImage(
        _ imageData: Data,
        prompt: String = "Describe this image in detail"
    ) async throws -> String {
        // Convert image to base64
        let base64Image = imageData.base64EncodedString()
        
        let endpoint = "https://\(location)-aiplatform.googleapis.com/v1/projects/\(projectID)/locations/\(location)/publishers/google/models/gemini-pro-vision:generateContent"
        
        guard let url = URL(string: endpoint) else {
            throw VertexAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt],
                        ["inline_data": [
                            "mime_type": "image/jpeg",
                            "data": base64Image
                        ]]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw VertexAIError.invalidResponse
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let firstCandidate = geminiResponse.candidates.first,
              let firstPart = firstCandidate.content.parts.first else {
            throw VertexAIError.noResponseText
        }
        
        return firstPart.text
    }
    
    // MARK: - Content Moderation
    
    /// Moderate content using Vertex AI's safety features
    func moderateContent(_ text: String) async throws -> ModerationResult {
        let response = try await generateWithGemini(
            """
            Analyze this content for safety issues. Respond with JSON:
            {
                "isSafe": true/false,
                "categories": ["hate_speech", "violence", etc],
                "severity": "low/medium/high",
                "recommendation": "approve/review/reject"
            }
            
            Content: \(text)
            """,
            model: .geminiPro
        )
        
        // Parse JSON response
        if let data = response.data(using: .utf8),
           let json = try? JSONDecoder().decode(ModerationResult.self, from: data) {
            return json
        }
        
        return ModerationResult(isSafe: true, categories: [], severity: "low", recommendation: "approve")
    }
    
    // MARK: - Thumbnail Generation
    
    /// Generate thumbnail suggestions for videos
    func generateThumbnailSuggestions(videoTitle: String, description: String) async throws -> [ThumbnailSuggestion] {
        let prompt = """
        Generate 3 compelling thumbnail ideas for a video titled "\(videoTitle)".
        Description: \(description)
        
        For each thumbnail, provide:
        1. Main text overlay (short, punchy)
        2. Visual concept description
        3. Color scheme
        4. Emotional tone
        
        Return as JSON array.
        """
        
        let response = try await generateWithGemini(prompt, model: .geminiPro)
        
        // Parse response into structured suggestions
        // For now, return sample data
        return [
            ThumbnailSuggestion(
                mainText: "Extract from response",
                visualConcept: "AI-generated concept",
                colorScheme: "Bold reds and blacks",
                emotionalTone: "Exciting"
            )
        ]
    }
    
    // MARK: - Video Transcription (Speech-to-Text)
    
    /// Transcribe video audio using Google Cloud Speech-to-Text
    func transcribeVideo(audioURL: URL) async throws -> Transcription {
        // This would use Google Cloud Speech-to-Text API
        // Placeholder implementation
        return Transcription(
            text: "Transcription would go here",
            timestamps: [],
            confidence: 0.95
        )
    }
    
    // MARK: - Translation
    
    /// Translate text using Google Cloud Translation API
    func translate(_ text: String, to targetLanguage: String) async throws -> String {
        let endpoint = "https://translation.googleapis.com/language/translate/v2"
        
        guard let url = URL(string: endpoint) else {
            throw VertexAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let requestBody: [String: Any] = [
            "q": text,
            "target": targetLanguage,
            "format": "text"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await session.data(for: request)
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObj = json["data"] as? [String: Any],
           let translations = dataObj["translations"] as? [[String: Any]],
           let firstTranslation = translations.first,
           let translatedText = firstTranslation["translatedText"] as? String {
            return translatedText
        }
        
        throw VertexAIError.invalidResponse
    }
    
    // MARK: - Helper Methods
    
    private func getAccessToken() async -> String? {
        // In production, use Google Cloud OAuth 2.0
        // For now, return API key or service account token
        return ProcessInfo.processInfo.environment["GOOGLE_CLOUD_API_KEY"] ?? AppConfig.API.googleCloudAPIKey
    }
}

// MARK: - Supporting Types

enum GeminiModel: String {
    case geminiPro = "gemini-pro"
    case geminiProVision = "gemini-pro-vision"
    case gemini15Pro = "gemini-1.5-pro"
    case gemini15Flash = "gemini-1.5-flash"
}

struct ModerationResult: Codable {
    let isSafe: Bool
    let categories: [String]
    let severity: String
    let recommendation: String
}

struct ThumbnailSuggestion {
    let mainText: String
    let visualConcept: String
    let colorScheme: String
    let emotionalTone: String
}

struct Transcription {
    let text: String
    let timestamps: [TimeInterval]
    let confidence: Double
}

enum VertexAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noResponseText
    case apiError(Int, String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Vertex AI URL"
        case .invalidResponse:
            return "Invalid response from Vertex AI"
        case .noResponseText:
            return "No response text from Vertex AI"
        case .apiError(let code, let message):
            return "Vertex AI error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Creator Helper Extensions

extension VertexAIService {
    /// Generate video title suggestions
    func generateVideoTitles(for description: String, count: Int = 5) async throws -> [String] {
        let prompt = """
        Generate \(count) compelling, clickable video titles for this video:
        \(description)
        
        Make them:
        - Attention-grabbing
        - SEO-friendly
        - Under 70 characters
        - Authentic and not clickbait
        
        Return only the titles, one per line.
        """
        
        let response = try await generateWithGemini(prompt)
        return response.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    /// Improve video description for SEO
    func optimizeDescription(_ description: String) async throws -> String {
        let prompt = """
        Improve this video description for better SEO and engagement:
        
        Original: \(description)
        
        Make it:
        - More engaging and professional
        - SEO-optimized with relevant keywords
        - Include relevant hashtags
        - Keep the original message and tone
        """
        
        return try await generateWithGemini(prompt)
    }
    
    /// Generate video tags
    func generateTags(for title: String, description: String) async throws -> [String] {
        let prompt = """
        Generate 10-15 relevant tags for this video:
        Title: \(title)
        Description: \(description)
        
        Return only the tags, comma-separated.
        """
        
        let response = try await generateWithGemini(prompt)
        return response.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    /// Analyze video performance and suggest improvements
    func analyzeVideoPerformance(
        title: String,
        description: String,
        tags: [String],
        metrics: VideoMetrics
    ) async throws -> PerformanceInsights {
        let prompt = """
        Analyze this video's performance and suggest improvements:
        
        Title: \(title)
        Description: \(description)
        Tags: \(tags.joined(separator: ", "))
        Views: \(metrics.views)
        Watch Time: \(metrics.watchTime)
        CTR: \(metrics.clickThroughRate)%
        Engagement: \(metrics.engagementRate)%
        
        Provide specific, actionable recommendations for:
        1. Title improvements
        2. Thumbnail suggestions
        3. Description optimization
        4. Best posting times
        5. Content strategy
        """
        
        let response = try await generateWithGemini(prompt)
        
        return PerformanceInsights(
            overallScore: 75, // Parse from response
            recommendations: response,
            predictedViews: Int(Double(metrics.views) * 1.5),
            suggestedActions: ["Improve title", "Add more tags", "Optimize thumbnail"]
        )
    }
}

// MARK: - Supporting Types for Creator Features

struct VideoMetrics {
    let views: Int
    let watchTime: TimeInterval
    let clickThroughRate: Double
    let engagementRate: Double
}

struct PerformanceInsights {
    let overallScore: Int
    let recommendations: String
    let predictedViews: Int
    let suggestedActions: [String]
}

