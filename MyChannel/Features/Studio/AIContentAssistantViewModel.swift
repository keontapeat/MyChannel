//
//  AIContentAssistantViewModel.swift
//  MyChannel
//
//  ViewModel for AI Content Assistant
//

import Foundation
import SwiftUI

struct VideoContentAnalysis: Codable {
    let viralScore: Int
    let estimatedViews: String
    let engagementRate: Int
    let watchTime: String
    let shareRate: Int
    let suggestions: [String]
    let alternativeTitles: [String]
}

struct UploadTimeSlot: Codable {
    let day: String
    let time: String
    let engagementBoost: Int
}

@MainActor
class AIContentAssistantViewModel: ObservableObject {
    @Published var currentAnalysis: VideoContentAnalysis?
    @Published var trendingTopics: [String] = []
    @Published var bestUploadTimes: [UploadTimeSlot] = []
    
    func analyzeContent(title: String, description: String, thumbnail: UIImage?) async {
        // Use GPT-5 Turbo to analyze content
        let prompt = """
        Analyze this video content for viral potential:
        Title: \(title)
        Description: \(description)
        
        Provide:
        1. Viral score (0-100)
        2. Estimated view range
        3. Expected engagement rate
        4. Average watch time prediction
        5. Share rate prediction
        6. 5 specific improvement suggestions
        7. 3 alternative title options
        
        Return as JSON with keys: viralScore, estimatedViews, engagementRate, watchTime, shareRate, suggestions (array), alternativeTitles (array)
        """
        
        do {
            let response = try await OpenAIService.shared.generate(prompt, model: .gpt5Turbo)
            // Parse JSON response
            // For now, mock the response
            currentAnalysis = VideoContentAnalysis(
                viralScore: Int.random(in: 60...95),
                estimatedViews: "50K-150K",
                engagementRate: Int.random(in: 5...12),
                watchTime: "4:30",
                shareRate: Int.random(in: 2...8),
                suggestions: [
                    "Add more emotional hooks in the first 10 seconds",
                    "Include trending keywords: '\(trendingTopics.first ?? "trending")'",
                    "Thumbnail needs more contrast and text",
                    "Description should include timestamps",
                    "Consider adding a poll or question to boost engagement"
                ],
                alternativeTitles: [
                    "How I \(title) (YOU WON'T BELIEVE THIS!)",
                    "The TRUTH About \(title)",
                    "\(title) - This Changed Everything"
                ]
            )
        } catch {
            print("❌ Error analyzing content: \(error)")
        }
    }
    
    func loadTrendingTopics() async {
        // Fetch from trending API or use AI to predict
        trendingTopics = [
            "AI Technology",
            "Productivity Hacks",
            "Side Hustles 2025",
            "Healthy Recipes",
            "Gaming Tips",
            "Travel Vlogs",
            "Tech Reviews",
            "Fitness Motivation"
        ]
        
        bestUploadTimes = [
            UploadTimeSlot(day: "Monday", time: "2:00 PM - 4:00 PM", engagementBoost: 15),
            UploadTimeSlot(day: "Wednesday", time: "12:00 PM - 2:00 PM", engagementBoost: 22),
            UploadTimeSlot(day: "Friday", time: "5:00 PM - 7:00 PM", engagementBoost: 28),
            UploadTimeSlot(day: "Saturday", time: "10:00 AM - 12:00 PM", engagementBoost: 35),
            UploadTimeSlot(day: "Sunday", time: "7:00 PM - 9:00 PM", engagementBoost: 42)
        ]
    }
}

