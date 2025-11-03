//
//  CompetitorAnalyzerViewModel.swift
//  MyChannel
//
//  ViewModel for AI Competitor Analyzer
//

import Foundation

struct CompetitorChannel: Identifiable, Codable {
    let id: String
    let name: String
    let avatarURL: String
    let subscribers: String
    let growth: String
    let recentVideos: Int
    let avgViews: String
    let engagementRate: String
}

struct TrendingStrategy: Codable {
    let title: String
    let description: String
    let avgGrowth: Int
    let competitorsUsing: Int
}

struct ContentGap: Codable {
    let topic: String
    let competitorsCovering: Int
    let potentialViews: String
}

struct AIInsight: Codable {
    let title: String
    let description: String
    let priority: String
    let actionItems: [String]
}

@MainActor
class CompetitorAnalyzerViewModel: ObservableObject {
    @Published var competitors: [CompetitorChannel] = []
    @Published var trendingStrategies: [TrendingStrategy] = []
    @Published var contentGaps: [ContentGap] = []
    @Published var aiInsights: [AIInsight] = []
    
    // Performance Metrics
    @Published var yourAvgViews = "45K"
    @Published var competitorAvgViews = "38K"
    @Published var yourEngagementRate = "8.2%"
    @Published var competitorEngagementRate = "6.9%"
    @Published var yourUploadFreq = "3/week"
    @Published var competitorUploadFreq = "4/week"
    @Published var yourSubGrowth = "+12%"
    @Published var competitorSubGrowth = "+15%"
    
    func loadData() async {
        // Load tracked competitors from Firestore
        competitors = [
            CompetitorChannel(
                id: "1",
                name: "Tech Guru Pro",
                avatarURL: "",
                subscribers: "2.4M",
                growth: "+18%",
                recentVideos: 5,
                avgViews: "120K",
                engagementRate: "7.5%"
            ),
            CompetitorChannel(
                id: "2",
                name: "Creator Academy",
                avatarURL: "",
                subscribers: "1.8M",
                growth: "+22%",
                recentVideos: 3,
                avgViews: "95K",
                engagementRate: "8.9%"
            )
        ]
        
        // Trending strategies
        trendingStrategies = [
            TrendingStrategy(
                title: "Podcast-Style Long-Form Content",
                description: "1-2 hour deep-dive conversations are getting 3x more watch time than typical videos",
                avgGrowth: 34,
                competitorsUsing: 8
            ),
            TrendingStrategy(
                title: "Series-Based Content",
                description: "Creating episodic series keeps viewers coming back and boosts retention by 40%",
                avgGrowth: 28,
                competitorsUsing: 12
            ),
            TrendingStrategy(
                title: "Community Challenges",
                description: "Engaging audience with weekly challenges increases comments by 250%",
                avgGrowth: 42,
                competitorsUsing: 5
            )
        ]
        
        // Content gaps
        contentGaps = [
            ContentGap(
                topic: "AI Tools for Creators",
                competitorsCovering: 15,
                potentialViews: "250K"
            ),
            ContentGap(
                topic: "Behind-the-Scenes Editing",
                competitorsCovering: 8,
                potentialViews: "180K"
            ),
            ContentGap(
                topic: "Monetization Strategies 2025",
                competitorsCovering: 12,
                potentialViews: "300K"
            )
        ]
        
        // AI insights from Claude Sonnet 4.5
        aiInsights = [
            AIInsight(
                title: "Upload More Frequently",
                description: "Your competitors average 4 videos per week while you post 3. Increasing frequency could boost growth by 15-20%.",
                priority: "high",
                actionItems: [
                    "Batch record 2-3 videos in one session",
                    "Hire an editor to speed up post-production",
                    "Repurpose long videos into shorts"
                ]
            ),
            AIInsight(
                title: "Optimize Thumbnails",
                description: "Competitors using high-contrast thumbnails with faces get 35% more clicks.",
                priority: "medium",
                actionItems: [
                    "Add close-up faces to thumbnails",
                    "Use bold, contrasting colors",
                    "Test A/B variations"
                ]
            ),
            AIInsight(
                title: "Engage in First 30 Seconds",
                description: "Top performers hook viewers in the first 15-30 seconds, keeping 75% retention.",
                priority: "high",
                actionItems: [
                    "Start with a compelling question",
                    "Show the end result upfront",
                    "Cut intros shorter"
                ]
            )
        ]
    }
}

