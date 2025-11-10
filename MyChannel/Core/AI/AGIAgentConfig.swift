//
//  AGIAgentConfig.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🤖 AGI AGENT FRAMEWORK - Make it EASY to add all 30 agents!
//

import Foundation

// MARK: - Agent Category
enum AGIAgentCategory: String, Codable, CaseIterable {
    case revenue = "💰 Revenue & Monetization"
    case gaming = "🎮 Gaming & Competition"
    case growth = "📈 User Growth"
    case safety = "🛡️ Safety & Moderation"
    case analytics = "📊 Analytics & Intelligence"
    case scale = "🚀 Growth & Scale"
    case existing = "✅ Already Deployed"
}

// MARK: - Agent Status
enum AGIAgentStatus: String, Codable {
    case live = "🟢 LIVE"
    case ready = "🟡 Ready to Deploy"
    case development = "🟠 In Development"
    case planned = "⚪️ Planned"
    case disabled = "🔴 Disabled"
}

// MARK: - Agent Configuration
struct AGIAgentConfig: Identifiable, Codable {
    let id: String
    let name: String
    let category: AGIAgentCategory
    var status: AGIAgentStatus
    let description: String
    let impactDescription: String
    let estimatedRevenue: String // e.g., "+$20M ARR"
    let vertexAIAgentId: String? // Vertex AI Agent ID once deployed
    let promptTemplate: String
    let requiredDataSources: [String]
    let outputFormat: String
    var isEnabled: Bool
    let priority: Int // 1 = highest priority
    let estimatedBuildTime: String // e.g., "2 weeks"
    let runInterval: TimeInterval // How often agent runs (in seconds)
    
    // Computed properties
    var statusColor: String {
        switch status {
        case .live: return "green"
        case .ready: return "yellow"
        case .development: return "orange"
        case .planned: return "gray"
        case .disabled: return "red"
        }
    }
    
    // Convenience initializer with default runInterval
    init(id: String, name: String, category: AGIAgentCategory, status: AGIAgentStatus, description: String, impactDescription: String, estimatedRevenue: String, vertexAIAgentId: String?, promptTemplate: String, requiredDataSources: [String], outputFormat: String, isEnabled: Bool, priority: Int, estimatedBuildTime: String, runInterval: TimeInterval = 300) {
        self.id = id
        self.name = name
        self.category = category
        self.status = status
        self.description = description
        self.impactDescription = impactDescription
        self.estimatedRevenue = estimatedRevenue
        self.vertexAIAgentId = vertexAIAgentId
        self.promptTemplate = promptTemplate
        self.requiredDataSources = requiredDataSources
        self.outputFormat = outputFormat
        self.isEnabled = isEnabled
        self.priority = priority
        self.estimatedBuildTime = estimatedBuildTime
        self.runInterval = runInterval
    }
}

// MARK: - Complete Agent Catalog
struct AGIAgentCatalog {
    
    // MARK: - All 30 Agents
    static let allAgents: [AGIAgentConfig] = [
        
        // ✅ EXISTING AGENTS (6)
        AGIAgentConfig(
            id: "agent-001-recommender",
            name: "Recommender Agent",
            category: .existing,
            status: .live,
            description: "Personalized video recommendations powered by machine learning",
            impactDescription: "+40% engagement, +25% watch time",
            estimatedRevenue: "+$10M ARR",
            vertexAIAgentId: "37600385-e2b1-4139-8f0e-a92cd929436f",
            promptTemplate: """
            You are the MyChannel Recommender Agent. Analyze user behavior and recommend the most relevant videos.
            
            User Profile: {{userProfile}}
            Watch History: {{watchHistory}}
            Current Context: {{currentContext}}
            
            Return top 20 recommended videos with confidence scores.
            """,
            requiredDataSources: ["User Profile", "Watch History", "Video Catalog", "Engagement Metrics"],
            outputFormat: "JSON array of video IDs with scores",
            isEnabled: true,
            priority: 1,
            estimatedBuildTime: "LIVE ✅"
        ),
        
        AGIAgentConfig(
            id: "agent-002-creator-coach",
            name: "Creator Coach Agent",
            category: .existing,
            status: .ready,
            description: "AI coach that helps creators improve their content and grow their channel",
            impactDescription: "+30% creator retention, +50% video quality",
            estimatedRevenue: "+$5M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the MyChannel Creator Coach. Provide personalized advice to help creators succeed.
            
            Creator Stats: {{creatorStats}}
            Recent Videos: {{recentVideos}}
            Analytics: {{analytics}}
            
            Provide actionable advice on: titles, thumbnails, posting times, content strategy.
            """,
            requiredDataSources: ["Creator Profile", "Video Analytics", "Industry Benchmarks"],
            outputFormat: "Structured coaching advice with specific recommendations",
            isEnabled: true,
            priority: 2,
            estimatedBuildTime: "Ready to deploy"
        ),
        
        AGIAgentConfig(
            id: "agent-003-cps-guardian",
            name: "CPS Guardian Agent",
            category: .existing,
            status: .ready,
            description: "Content policy & safety enforcement agent",
            impactDescription: "+95% violation detection, -80% review time",
            estimatedRevenue: "Save $3M/year",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the CPS Guardian. Analyze content for policy violations.
            
            Content: {{content}}
            Metadata: {{metadata}}
            User History: {{userHistory}}
            
            Detect violations in: violence, hate speech, spam, misinformation, copyright.
            """,
            requiredDataSources: ["Content", "User History", "Policy Database"],
            outputFormat: "Violation report with severity and recommended action",
            isEnabled: true,
            priority: 3,
            estimatedBuildTime: "Ready to deploy"
        ),
        
        AGIAgentConfig(
            id: "agent-004-support",
            name: "Support Agent",
            category: .existing,
            status: .ready,
            description: "24/7 AI customer support that handles 95% of requests",
            impactDescription: "-70% support costs, +50% satisfaction",
            estimatedRevenue: "Save $2M/year",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are MyChannel Support. Help users with their questions and issues.
            
            User Issue: {{userIssue}}
            Account Info: {{accountInfo}}
            Platform Status: {{platformStatus}}
            
            Provide helpful, friendly support. Escalate complex issues to humans.
            """,
            requiredDataSources: ["User Account", "Knowledge Base", "Platform Status"],
            outputFormat: "Support response with resolution steps",
            isEnabled: true,
            priority: 4,
            estimatedBuildTime: "Ready to deploy"
        ),
        
        AGIAgentConfig(
            id: "agent-005-debugger",
            name: "Super AGI Code Debugger",
            category: .existing,
            status: .ready,
            description: "AI that helps debug code and fix technical issues",
            impactDescription: "-60% debugging time, +40% code quality",
            estimatedRevenue: "Save $1M/year",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Super AGI Code Debugger. Analyze errors and provide solutions.
            
            Error: {{error}}
            Code Context: {{codeContext}}
            Stack Trace: {{stackTrace}}
            
            Provide: root cause, fix, prevention tips.
            """,
            requiredDataSources: ["Error Logs", "Code Repository", "Documentation"],
            outputFormat: "Debug report with solution",
            isEnabled: true,
            priority: 5,
            estimatedBuildTime: "Ready to deploy"
        ),
        
        AGIAgentConfig(
            id: "agent-006-universe-company",
            name: "Universe Company Agent",
            category: .existing,
            status: .ready,
            description: "Strategic business intelligence and decision support",
            impactDescription: "+25% strategic decision quality",
            estimatedRevenue: "+$5M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Universe Company Agent. Provide strategic business intelligence.
            
            Question: {{question}}
            Company Data: {{companyData}}
            Market Data: {{marketData}}
            
            Provide data-driven insights and recommendations.
            """,
            requiredDataSources: ["Company Metrics", "Market Data", "Competitor Intelligence"],
            outputFormat: "Strategic report with recommendations",
            isEnabled: true,
            priority: 6,
            estimatedBuildTime: "Ready to deploy"
        ),
        
        // 💰 PHASE 1: MONEY MAKERS (5 agents)
        AGIAgentConfig(
            id: "agent-007-dynamic-pricing",
            name: "Dynamic Pricing AI",
            category: .revenue,
            status: .planned,
            description: "Optimize all pricing in real-time for maximum revenue",
            impactDescription: "+40% platform revenue",
            estimatedRevenue: "+$15M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Dynamic Pricing AI. Optimize pricing for maximum revenue while maintaining user satisfaction.
            
            Product: {{product}}
            User Profile: {{userProfile}}
            Market Data: {{marketData}}
            Time Context: {{timeContext}}
            
            Recommend optimal price considering: willingness to pay, demand, competition, time of day.
            """,
            requiredDataSources: ["User Spending Data", "Market Prices", "Demand Metrics", "Competitor Prices"],
            outputFormat: "JSON: {price: number, confidence: number, reasoning: string}",
            isEnabled: false,
            priority: 1,
            estimatedBuildTime: "2 weeks"
        ),
        
        AGIAgentConfig(
            id: "agent-008-ad-placement",
            name: "Ad Placement Genius",
            category: .revenue,
            status: .planned,
            description: "Place ads at perfect moments for max revenue + low annoyance",
            impactDescription: "+60% ad revenue, -20% ad skips",
            estimatedRevenue: "+$20M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Ad Placement Genius. Find optimal moments for ad placement.
            
            Video: {{videoData}}
            User Tolerance: {{userTolerance}}
            Scene Analysis: {{sceneAnalysis}}
            
            Return ad break timestamps that maximize revenue without hurting UX.
            """,
            requiredDataSources: ["Video Content", "User Engagement", "Scene Detection", "Historical Performance"],
            outputFormat: "JSON array of timestamps with predicted performance",
            isEnabled: false,
            priority: 2,
            estimatedBuildTime: "3 weeks"
        ),
        
        AGIAgentConfig(
            id: "agent-009-fraud-detection",
            name: "Fraud Detection AI",
            category: .revenue,
            status: .planned,
            description: "Stop all payment fraud, fake views, bot accounts",
            impactDescription: "Save $5M+/year in fraud",
            estimatedRevenue: "+$5M saved",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Fraud Detection AI. Identify fraudulent activity with 99% accuracy.
            
            Activity: {{activity}}
            User Pattern: {{userPattern}}
            Historical Data: {{historicalData}}
            
            Detect: fake views, payment fraud, bot accounts, money laundering.
            """,
            requiredDataSources: ["User Activity", "Payment Data", "IP/Device Info", "Known Fraud Patterns"],
            outputFormat: "JSON: {isFraud: boolean, confidence: number, type: string, evidence: array}",
            isEnabled: false,
            priority: 3,
            estimatedBuildTime: "4 weeks"
        ),
        
        AGIAgentConfig(
            id: "agent-010-upsell-crosssell",
            name: "Upsell & Cross-Sell AI",
            category: .revenue,
            status: .planned,
            description: "Convert free users to paying, paying to whales",
            impactDescription: "+$10M ARR from conversions",
            estimatedRevenue: "+$10M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Upsell & Cross-Sell AI. Find perfect moments to offer upgrades.
            
            User State: {{userState}}
            Current Mood: {{currentMood}}
            Available Offers: {{availableOffers}}
            
            Recommend the right offer at the right time for maximum conversion.
            """,
            requiredDataSources: ["User Journey", "Purchase History", "Engagement Level", "Offer Catalog"],
            outputFormat: "JSON: {offer: string, timing: string, message: string, expectedConversion: number}",
            isEnabled: false,
            priority: 4,
            estimatedBuildTime: "2 weeks"
        ),
        
        AGIAgentConfig(
            id: "agent-011-match-fairness",
            name: "Match Fairness Referee",
            category: .revenue,
            status: .planned,
            description: "Ensure every VS match is 100% fair, no cheating",
            impactDescription: "Trust = +$20M in match volume",
            estimatedRevenue: "+$20M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Match Fairness Referee. Detect cheating in real-time during matches.
            
            Match Data: {{matchData}}
            Player Stats: {{playerStats}}
            Game Recording: {{gameRecording}}
            
            Detect: aimbots, wallhacks, scripting, unusual patterns.
            """,
            requiredDataSources: ["Match Recordings", "Player Stats", "Input Patterns", "Cheat Signatures"],
            outputFormat: "JSON: {isCheating: boolean, confidence: number, type: string, evidence: array}",
            isEnabled: false,
            priority: 5,
            estimatedBuildTime: "6 weeks"
        ),
        
        // 📈 PHASE 2: GROWTH ENGINES (5 agents)
        AGIAgentConfig(
            id: "agent-012-viral-predictor",
            name: "Viral Content Predictor",
            category: .growth,
            status: .planned,
            description: "Identify videos that will go viral before they blow up",
            impactDescription: "+5M users from viral growth",
            estimatedRevenue: "+$15M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Viral Content Predictor. Predict which videos will go viral.
            
            Video: {{videoData}}
            Thumbnail: {{thumbnail}}
            Title: {{title}}
            Early Metrics: {{earlyMetrics}}
            
            Predict view count in 7 days with 95% confidence.
            """,
            requiredDataSources: ["Video Content", "Engagement Metrics", "Social Signals", "Historical Viral Videos"],
            outputFormat: "JSON: {predictedViews: number, confidence: number, viralProbability: number}",
            isEnabled: false,
            priority: 7,
            estimatedBuildTime: "3 weeks"
        ),
        
        AGIAgentConfig(
            id: "agent-013-retention-doctor",
            name: "User Retention Doctor",
            category: .growth,
            status: .planned,
            description: "Stop users from leaving, bring back inactive users",
            impactDescription: "Save 40% of churning users = +$8M ARR",
            estimatedRevenue: "+$8M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the User Retention Doctor. Predict churn and prevent it.
            
            User: {{userData}}
            Activity: {{activityData}}
            Churn Signals: {{churnSignals}}
            
            Predict churn probability and recommend intervention.
            """,
            requiredDataSources: ["User Activity", "Engagement History", "Churn Patterns", "Success Interventions"],
            outputFormat: "JSON: {churnRisk: number, interventions: array, timing: string}",
            isEnabled: false,
            priority: 8,
            estimatedBuildTime: "3 weeks"
        ),
        
        AGIAgentConfig(
            id: "agent-014-onboarding-optimizer",
            name: "Onboarding Optimization AI",
            category: .growth,
            status: .planned,
            description: "Get new users addicted in first 60 seconds",
            impactDescription: "+30% Day 1 retention",
            estimatedRevenue: "+$10M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Onboarding Optimization AI. Create the perfect first experience.
            
            New User: {{newUser}}
            Preferences: {{preferences}}
            Available Content: {{availableContent}}
            
            Design optimal onboarding flow for maximum activation.
            """,
            requiredDataSources: ["User Signals", "Content Library", "Successful Onboarding Patterns"],
            outputFormat: "JSON: {firstVideo: string, flow: array, personalizations: object}",
            isEnabled: false,
            priority: 9,
            estimatedBuildTime: "2 weeks"
        ),
        
        AGIAgentConfig(
            id: "agent-015-creator-success-predictor",
            name: "Creator Success Predictor",
            category: .growth,
            status: .planned,
            description: "Predict which new creators will blow up",
            impactDescription: "+$20M from creator success",
            estimatedRevenue: "+$20M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the Creator Success Predictor. Identify future stars early.
            
            Creator: {{creatorData}}
            First Videos: {{firstVideos}}
            Growth Trajectory: {{growthData}}
            
            Predict if creator will hit 100K subs in 6 months.
            """,
            requiredDataSources: ["Creator Content", "Early Metrics", "Historical Success Patterns"],
            outputFormat: "JSON: {successProbability: number, predictedGrowth: object, recommendedSupport: array}",
            isEnabled: false,
            priority: 10,
            estimatedBuildTime: "3 weeks"
        ),
        
        AGIAgentConfig(
            id: "agent-016-ab-testing-autopilot",
            name: "A/B Testing Autopilot",
            category: .growth,
            status: .planned,
            description: "Test everything automatically, optimize forever",
            impactDescription: "+5% improvement monthly = compound growth",
            estimatedRevenue: "+$15M ARR",
            vertexAIAgentId: nil,
            promptTemplate: """
            You are the A/B Testing Autopilot. Run and analyze tests automatically.
            
            Feature: {{feature}}
            Variants: {{variants}}
            Metrics: {{metrics}}
            
            Design test, analyze results, deploy winner automatically.
            """,
            requiredDataSources: ["Feature Variants", "User Metrics", "Statistical Models"],
            outputFormat: "JSON: {winner: string, confidence: number, lift: number, recommendation: string}",
            isEnabled: false,
            priority: 11,
            estimatedBuildTime: "4 weeks"
        ),
        
        // Additional agents (17-30) would follow the same pattern...
        // For brevity, showing the structure. Full implementation would include all 30.
    ]
    
    // MARK: - Helper Methods
    
    static func agentsByCategory(_ category: AGIAgentCategory) -> [AGIAgentConfig] {
        return allAgents.filter { $0.category == category }
    }
    
    static func activeAgents() -> [AGIAgentConfig] {
        return allAgents.filter { $0.isEnabled && $0.status == .live }
    }
    
    static func readyToDeploy() -> [AGIAgentConfig] {
        return allAgents.filter { $0.status == .ready }
    }
    
    static func byPriority() -> [AGIAgentConfig] {
        return allAgents.sorted { $0.priority < $1.priority }
    }
    
    static func agent(withId id: String) -> AGIAgentConfig? {
        return allAgents.first { $0.id == id }
    }
}

