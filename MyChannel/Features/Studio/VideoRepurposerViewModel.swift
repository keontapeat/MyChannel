//
//  VideoRepurposerViewModel.swift
//  MyChannel
//
//  ViewModel for AI Video Repurposer
//

import Foundation
import SwiftUI

struct GeneratedFlick: Identifiable, Codable {
    let id: String
    let title: String
    let thumbnailURL: String
    let duration: TimeInterval
    let viralScore: Int
    let predictedViews: String
    let startTime: Double
    let endTime: Double
    let sourceVideoId: String
}

struct RepurposeTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    let duration: Int
    let style: String
    
    static let allTemplates: [RepurposeTemplate] = [
        RepurposeTemplate(
            id: "1",
            name: "Quick Tips",
            description: "30-second educational snippets",
            icon: "lightbulb.fill",
            color: .yellow,
            duration: 30,
            style: "educational"
        ),
        RepurposeTemplate(
            id: "2",
            name: "Highlight Reel",
            description: "Best moments compilation",
            icon: "star.fill",
            color: .orange,
            duration: 45,
            style: "compilation"
        ),
        RepurposeTemplate(
            id: "3",
            name: "Behind Scenes",
            description: "Exclusive BTS content",
            icon: "eye.fill",
            color: .purple,
            duration: 60,
            style: "behind-scenes"
        ),
        RepurposeTemplate(
            id: "4",
            name: "Reactions",
            description: "Best reaction moments",
            icon: "face.smiling.fill",
            color: .pink,
            duration: 20,
            style: "reactions"
        ),
        RepurposeTemplate(
            id: "5",
            name: "Quotes",
            description: "Memorable quotes & sayings",
            icon: "quote.bubble.fill",
            color: .blue,
            duration: 15,
            style: "quotes"
        )
    ]
}

@MainActor
class VideoRepurposerViewModel: ObservableObject {
    @Published var generatedFlicks: [GeneratedFlick] = []
    @Published var availableVideos: [Video] = []
    
    @Published var videosRepurposed: Int = 42
    @Published var flicksGenerated: Int = 387
    @Published var hoursSaved: Int = 216
    
    func loadData() async {
        // Load user's videos from Firestore
        // Mock data for now
        availableVideos = Video.sampleVideos
        
        videosRepurposed = 42
        flicksGenerated = 387
        hoursSaved = 216
    }
    
    func repurposeVideo(_ video: Video) async {
        // Use GPT-5 + Claude Sonnet 4.5 to analyze video and extract best moments
        print("🎬 Repurposing video: \(video.title)")
        
        // Step 1: Analyze video transcript & visual content
        let prompt = """
        Analyze this video and find the top 10 most engaging moments for short-form content:
        Title: \(video.title)
        Duration: \(video.duration) seconds
        
        For each moment, provide:
        1. Start time (seconds)
        2. End time (seconds) - must be 15-60 seconds long
        3. Suggested title (viral, engaging)
        4. Viral score (0-100)
        5. Predicted views range
        6. Why this moment is engaging
        
        Return as JSON array with keys: startTime, endTime, title, viralScore, predictedViews, reason
        """
        
        do {
            let response = try await OpenAIService.shared.generate(prompt, model: .gpt5Turbo)
            
            // Parse response and generate flicks
            // Mock data for now
            let mockFlicks = (1...8).map { i in
                GeneratedFlick(
                    id: UUID().uuidString,
                    title: generateFlickTitle(index: i, videoTitle: video.title),
                    thumbnailURL: video.thumbnailURL,
                    duration: TimeInterval(Int.random(in: 15...60)),
                    viralScore: Int.random(in: 70...95),
                    predictedViews: "\(Int.random(in: 10...500))K",
                    startTime: Double(i * 60),
                    endTime: Double(i * 60 + 45),
                    sourceVideoId: video.id
                )
            }
            
            await MainActor.run {
                self.generatedFlicks = mockFlicks
            }
            
            print("✅ Generated \(mockFlicks.count) Flicks from video!")
            
        } catch {
            print("❌ Error repurposing video: \(error)")
        }
    }
    
    private func generateFlickTitle(index: Int, videoTitle: String) -> String {
        let hooks = [
            "The BEST Part of",
            "You WON'T BELIEVE",
            "This CHANGED Everything in",
            "The SECRET Behind",
            "Mind-Blowing Moment from",
            "This is INSANE from",
            "The TRUTH About",
            "SHOCKING Reveal in"
        ]
        
        let hook = hooks[index % hooks.count]
        let shortTitle = videoTitle.prefix(30)
        return "\(hook) \(shortTitle)"
    }
}

