import Foundation
import FirebaseAI

/// AI-powered service for generating video summaries, auto-chapters,
/// and tagging using Firebase Vertex AI (Gemini).
final class VideoAIInsightsService {
    static let shared = VideoAIInsightsService()
    
    // Initialize the Gemini 1.5 Flash model for fast text generation
    private lazy var model = FirebaseAI.firebaseAI().generativeModel(
        modelName: "gemini-1.5-flash",
        generationConfig: GenerationConfig(temperature: 0.2)
    )
    
    private init() {}
    
    /// Generates a summary for a video given its transcript or description
    func generateSummary(for transcript: String) async throws -> String {
        let prompt = """
        You are a highly intelligent video assistant similar to YouTube's AI.
        Summarize the following video transcript in a concise, engaging way.
        Keep it under 3 sentences.
        
        Transcript:
        "\(transcript)"
        """
        
        let response = try await model.generateContent(prompt)
        return response.text ?? "Summary unavailable."
    }
    
    /// Auto-generates chapters with timestamps based on a transcript
    func generateChapters(for transcript: String) async throws -> [(timestamp: String, title: String)] {
        let prompt = """
        You are an AI that creates YouTube-style video chapters.
        Extract the main topics from this transcript and assign estimated timestamps.
        Format the output exactly as a list of "MM:SS - Chapter Title" on each line.
        
        Transcript:
        "\(transcript)"
        """
        
        let response = try await model.generateContent(prompt)
        let text = response.text ?? ""
        
        // Parse the response into tuples (e.g. "01:23 - Intro")
        var chapters: [(String, String)] = []
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let components = line.components(separatedBy: " - ")
            if components.count == 2 {
                chapters.append((components[0].trimmingCharacters(in: .whitespaces), components[1].trimmingCharacters(in: .whitespaces)))
            }
        }
        
        return chapters
    }
    
    /// Auto-tags a video for the recommendation algorithm
    func generateTags(title: String, description: String) async throws -> [String] {
        let prompt = """
        Generate 10 SEO-optimized tags for a video with the following details.
        Return ONLY a comma-separated list of tags.
        
        Title: \(title)
        Description: \(description)
        """
        
        let response = try await model.generateContent(prompt)
        guard let text = response.text else { return [] }
        return text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
