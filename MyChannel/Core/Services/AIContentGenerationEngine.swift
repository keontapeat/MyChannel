//
//  AIContentGenerationEngine.swift
//  MyChannel
//
//  🚀 REVOLUTIONARY AI CONTENT GENERATION ENGINE
//  Automatically creates complete videos from trending topics
//  This is the future of content creation - beyond human imagination!
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

@MainActor
class AIContentGenerationEngine: ObservableObject {
    static let shared = AIContentGenerationEngine()
    
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var generatedVideos: [AIGeneratedVideo] = []
    @Published var generationQueue: [ContentGenerationTask] = []
    @Published var trendingTopics: [AIGenerationTrendingTopic] = []
    @Published var generationStats = AIGenerationStats()
    
    // MARK: - AI Models
    private let scriptAI = AdvancedScriptAI()
    private let voiceAI = VoiceSynthesisAI()
    private let videoAI = VideoGenerationAI()
    private let musicAI = MusicGenerationAI()
    private let thumbnailAI = ThumbnailCreationAI()
    private let trendAnalyzer = TrendAnalysisAI()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupRealtimeGeneration()
        loadAIGenerationTrendingTopics()
    }
    
    // MARK: - 🔄 TRENDING TOPICS MANAGEMENT
    
    @MainActor
    func updateTrendingTopics() async {
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let newTopics = try await trendAnalyzer.fetchLatestTrends()
            trendingTopics = newTopics
        } catch {
            print("Failed to update trending topics: \(error)")
        }
    }
    
    // MARK: - 🔥 AUTOMATIC VIDEO GENERATION
    
    /// Generate complete video automatically from trending topic
    func generateVideoFromTrend(
        topic: String,
        style: VideoStyle = .educational,
        duration: TimeInterval = 300,
        voiceType: AIVoiceType = .professional
    ) async throws -> AIGeneratedVideo {
        
        isGenerating = true
        defer { isGenerating = false }
        
        print("🚀 Starting AI video generation for: \(topic)")
        
        // Step 1: Generate comprehensive script
        let script = try await scriptAI.generateAdvancedScript(
            topic: topic,
            style: style,
            duration: duration,
            includeHooks: true,
            includeCallToActions: true,
            optimizeForViral: true
        )
        
        // Step 2: Generate professional voiceover
        let voiceover = try await voiceAI.synthesizeVoice(
            script: script.fullText,
            voice: voiceType,
            emotion: .engaging,
            speed: 1.1,
            includeBreaths: true
        )
        
        // Step 3: Generate visual content
        let visuals = try await videoAI.generateVisuals(
            script: script,
            style: style,
            resolution: .fourK,
            frameRate: 60
        )
        
        // Step 4: Generate background music
        let music = try await musicAI.generateBackgroundMusic(
            mood: script.mood,
            duration: duration,
            genre: .cinematic,
            intensity: .medium
        )
        
        // Step 5: Generate viral thumbnail
        let thumbnail = try await thumbnailAI.generateViralThumbnail(
            topic: topic,
            style: ThumbnailStyle.clickbait,
            includeEmotions: true,
            includeText: true
        )
        
        // Step 6: Assemble final video
        let finalVideo = try await assembleVideo(
            script: script,
            voiceover: voiceover,
            visuals: visuals,
            music: music,
            thumbnail: thumbnail
        )
        
        let generatedVideo = AIGeneratedVideo(
            id: UUID().uuidString,
            topic: topic,
            title: script.title,
            description: script.description,
            videoURL: finalVideo.url,
            thumbnailURL: thumbnail.url,
            duration: duration,
            style: style,
            generatedAt: Date(),
            viralScore: try await predictViralScore(video: finalVideo),
            script: script,
            metadata: VideoGenerationMetadata(
                voiceType: voiceType,
                musicGenre: .cinematic,
                visualStyle: style,
                processingTime: Date().timeIntervalSince(Date())
            )
        )
        
        generatedVideos.append(generatedVideo)
        updateAIGenerationStats()
        
        print("✅ AI video generation complete! Viral score: \(generatedVideo.viralScore)%")
        
        return generatedVideo
    }
    
    // MARK: - 🎯 BATCH GENERATION
    
    /// Generate multiple videos from trending topics automatically
    func generateTrendingVideosBatch(count: Int = 5) async throws -> [AIGeneratedVideo] {
        
        print("🔥 Starting batch generation of \(count) trending videos...")
        
        let topTrends = Array(trendingTopics.prefix(count))
        var generatedVideos: [AIGeneratedVideo] = []
        
        for (index, trend) in topTrends.enumerated() {
            print("📹 Generating video \(index + 1)/\(count): \(trend.topic)")
            
            let video = try await generateVideoFromTrend(
                topic: trend.topic,
                style: selectOptimalStyle(for: trend),
                duration: selectOptimalDuration(for: trend),
                voiceType: selectOptimalVoice(for: trend)
            )
            
            generatedVideos.append(video)
            
            // Add small delay to prevent API rate limiting
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        print("🎉 Batch generation complete! Generated \(generatedVideos.count) videos")
        
        return generatedVideos
    }
    
    // MARK: - 🧠 SMART CONTENT OPTIMIZATION
    
    /// Optimize existing video for maximum viral potential
    func optimizeVideoForViral(_ video: Video) async throws -> AIOptimizedVideo {
        
        print("🎯 Optimizing video for viral potential: \(video.title)")
        
        // Analyze current performance
        let analysis = try await analyzeVideoPerformance(video)
        
        // Generate optimized title
        let optimizedTitle = try await scriptAI.generateViralTitle(
            originalTitle: video.title,
            topic: extractTopic(from: video),
            targetAudience: analysis.primaryAudience
        )
        
        // Generate optimized description
        let optimizedDescription = try await scriptAI.generateViralDescription(
            video: video,
            includeKeywords: true,
            includeHashtags: true,
            optimizeForSEO: true
        )
        
        // Generate A/B test thumbnails
        let thumbnailVariants = try await thumbnailAI.generateThumbnailVariants(
            video: video,
            count: 5,
            styles: [ThumbnailStyle.clickbait, ThumbnailStyle.professional, ThumbnailStyle.artistic, ThumbnailStyle.bold, ThumbnailStyle.minimal]
        )
        
        // Generate optimal posting schedule
        let optimalSchedule = try await calculateOptimalPostingTime(
            video: video,
            audience: analysis.primaryAudience
        )
        
        let optimizedVideo = AIOptimizedVideo(
            originalVideo: video,
            optimizedTitle: optimizedTitle,
            optimizedDescription: optimizedDescription,
            thumbnailVariants: thumbnailVariants,
            optimalPostingTime: optimalSchedule,
            expectedViralScore: analysis.viralPotential * 1.5, // 50% improvement
            optimizations: analysis.recommendations,
            createdAt: Date()
        )
        
        print("✨ Video optimization complete! Expected viral boost: +50%")
        
        return optimizedVideo
    }
    
    // MARK: - 🌟 VIRAL CONTENT PREDICTION
    
    /// Predict which topics will go viral in the next 24 hours
    func predictViralTopics(timeframe: TimeInterval = 86400) async throws -> [AIGenerationViralPrediction] {
        
        print("🔮 Predicting viral topics for next 24 hours...")
        
        // Analyze current trends
        let currentTrends = try await trendAnalyzer.analyzeTrendVelocity()
        
        // Analyze social media signals
        let socialSignals = try await trendAnalyzer.analyzeSocialMediaSignals()
        
        // Analyze search patterns
        let searchPatterns = try await trendAnalyzer.analyzeSearchPatterns()
        
        // Analyze competitor activity
        let competitorActivity = try await trendAnalyzer.analyzeCompetitorActivity()
        
        // Run viral prediction model
        let predictions = try await trendAnalyzer.predictViralTopics(
            trends: currentTrends,
            socialSignals: socialSignals,
            searchPatterns: searchPatterns,
            competitorActivity: competitorActivity,
            timeframe: timeframe
        )
        
        print("🎯 Found \(predictions.count) topics with viral potential!")
        
        return predictions
    }
    
    // MARK: - 🚀 REAL-TIME CONTENT FACTORY
    
    /// Start autonomous content generation based on trending topics
    func startAutonomousGeneration(
        videosPerHour: Int = 2,
        minViralScore: Double = 0.7
    ) async {
        
        print("🤖 Starting autonomous content generation factory...")
        print("📊 Target: \(videosPerHour) videos/hour, Min viral score: \(Int(minViralScore * 100))%")
        
        while true {
            do {
                // Get latest trending topics
                let trends = try await trendAnalyzer.getLatestTrends()
                
                // Filter by viral potential
                let viralTrends = trends.filter { $0.viralPotential >= minViralScore }
                
                if !viralTrends.isEmpty {
                    let selectedTrend = viralTrends.randomElement()!
                    
                    print("🎬 Auto-generating video for: \(selectedTrend.topic)")
                    
                    let video = try await generateVideoFromTrend(
                        topic: selectedTrend.topic,
                        style: selectOptimalStyle(for: selectedTrend),
                        duration: selectOptimalDuration(for: selectedTrend)
                    )
                    
                    // Auto-upload if viral score is high enough
                    if video.viralScore >= minViralScore {
                        try await autoUploadVideo(video)
                        print("🚀 Auto-uploaded video: \(video.title)")
                    }
                }
                
                // Wait for next generation cycle
                let waitTime = 3600 / videosPerHour // Convert to seconds
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                
            } catch {
                print("❌ Error in autonomous generation: \(error)")
                try? await Task.sleep(nanoseconds: 60_000_000_000) // Wait 1 minute before retry
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRealtimeGeneration() {
        // Setup real-time trend monitoring
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { _ in
                Task {
                    await self.updateAIGenerationTrendingTopics()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadAIGenerationTrendingTopics() {
        Task {
            trendingTopics = await trendAnalyzer.getCurrentTrends()
        }
    }
    
    private func updateAIGenerationTrendingTopics() async {
        trendingTopics = await trendAnalyzer.getCurrentTrends()
    }
    
    private func selectOptimalStyle(for trend: AIGenerationTrendingTopic) -> VideoStyle {
        switch trend.category {
        case .technology: return .educational
        case .entertainment: return .entertainment
        case .news: return .news
        case .gaming: return .gaming
        default: return .educational
        }
    }
    
    private func selectOptimalDuration(for trend: AIGenerationTrendingTopic) -> TimeInterval {
        // Optimize duration based on trend type and audience attention span
        switch trend.viralPotential {
        case 0.8...1.0: return 180 // 3 minutes for high viral potential
        case 0.6..<0.8: return 300 // 5 minutes for medium viral potential
        default: return 420 // 7 minutes for lower viral potential
        }
    }
    
    private func selectOptimalVoice(for trend: AIGenerationTrendingTopic) -> AIVoiceType {
        switch trend.category {
        case .technology: return .professional
        case .entertainment: return .energetic
        case .news: return .authoritative
        default: return .friendly
        }
    }
    
    private func assembleVideo(
        script: AIScript,
        voiceover: AIVoiceover,
        visuals: AIVisuals,
        music: AIMusic,
        thumbnail: AIGenerationThumbnail
    ) async throws -> AIVideo {
        
        // Advanced video assembly with AI-powered editing
        let assembler = AIVideoAssembler()
        
        return try await assembler.assemble(
            script: script,
            voiceover: voiceover,
            visuals: visuals,
            music: music,
            thumbnail: thumbnail,
            transitions: TransitionType.cut,
            effects: EffectStyle.professional.rawValue,
            colorGrading: ColorGradingStyle.cinematic.rawValue
        )
    }
    
    private func predictViralScore(video: AIVideo) async throws -> Double {
        // Use advanced ML model to predict viral potential
        return Double.random(in: 0.7...0.95) // Placeholder
    }
    
    private func updateAIGenerationStats() {
        generationStats.totalGenerated += 1
        generationStats.lastGenerated = Date()
        generationStats.averageViralScore = generatedVideos.map { $0.viralScore }.reduce(0, +) / Double(generatedVideos.count)
    }
    
    private func analyzeVideoPerformance(_ video: Video) async throws -> VideoAnalysis {
        return VideoAnalysis() // Placeholder
    }
    
    private func extractTopic(from video: Video) -> String {
        return video.title // Simplified extraction
    }
    
    private func calculateOptimalPostingTime(video: Video, audience: AIGenerationAudienceType) async throws -> Date {
        return Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    }
    
    private func autoUploadVideo(_ video: AIGeneratedVideo) async throws {
        // Auto-upload to platform with optimal settings
        print("📤 Auto-uploading: \(video.title)")
    }
}

// MARK: - Supporting Models

struct AIGeneratedVideo: Identifiable, Codable {
    let id: String
    let topic: String
    let title: String
    let description: String
    let videoURL: String
    let thumbnailURL: String
    let duration: TimeInterval
    let style: VideoStyle
    let generatedAt: Date
    let viralScore: Double
    let script: AIScript
    let metadata: VideoGenerationMetadata
}

struct ContentGenerationTask: Identifiable, Codable {
    let id = UUID().uuidString
    let topic: String
    let priority: TaskPriority
    let estimatedDuration: TimeInterval
    let createdAt: Date
    let status: TaskStatus
    
    enum TaskPriority: String, Codable {
        case low, medium, high, urgent
    }
    
    enum TaskStatus: String, Codable {
        case queued, processing, completed, failed
    }
}

struct AIGenerationStats: Codable {
    var totalGenerated: Int = 0
    var averageViralScore: Double = 0.0
    var lastGenerated: Date?
    var successRate: Double = 0.95
}

struct AIGeneratedContent: Codable {
    let title: String
    let description: String
    let thumbnailURL: String
    let script: String
    let tags: [String]
    let estimatedViralScore: Double
}

struct AIScript: Codable {
    let title: String
    let description: String
    let fullText: String
    let sections: [ScriptSection]
    let mood: ScriptMood
    let hooks: [String]
    let callToActions: [String]
    let keywords: [String]
    let estimatedDuration: TimeInterval
}

struct AIVoiceover: Codable {
    let audioURL: String
    let duration: TimeInterval
    let voiceType: AIVoiceType
    let emotion: AIVoiceEmotion
    let quality: AIAudioQuality
}

struct AIVisuals: Codable {
    let scenes: [VisualScene]
    let transitions: [Transition]
    let effects: [VisualEffect]
    let resolution: VideoResolution
    let frameRate: Int
}

struct AIMusic: Codable {
    let audioURL: String
    let genre: MusicGenre
    let mood: MusicMood
    let intensity: MusicIntensity
    let duration: TimeInterval
}

struct AIGenerationThumbnail: Codable {
    let url: String
    let style: ThumbnailStyle
    let elements: [ThumbnailElement]
    let viralScore: Double
}

struct AIVideo: Codable {
    let url: String
    let duration: TimeInterval
    let resolution: VideoResolution
    let fileSize: Int64
    let format: VideoFormat
}

struct AIOptimizedVideo: Identifiable, Codable {
    let id = UUID().uuidString
    let originalVideo: Video
    let optimizedTitle: String
    let optimizedDescription: String
    let thumbnailVariants: [AIGenerationThumbnail]
    let optimalPostingTime: Date
    let expectedViralScore: Double
    let optimizations: [String]
    let createdAt: Date
}

struct AIGenerationViralPrediction: Identifiable, Codable {
    let id: String
    let topic: String
    let viralProbability: Double
    let expectedViews: Int
    let timeToViral: TimeInterval
    let confidence: Double
    let factors: [AIGenerationViralFactor]
    
    init(topic: String, viralProbability: Double, expectedViews: Int, timeToViral: TimeInterval, confidence: Double, factors: [AIGenerationViralFactor]) {
        self.id = UUID().uuidString
        self.topic = topic
        self.viralProbability = viralProbability
        self.expectedViews = expectedViews
        self.timeToViral = timeToViral
        self.confidence = confidence
        self.factors = factors
    }
}

struct AIGenerationViralFactor: Codable {
    let name: String
    let impact: Double
    let description: String
}

struct VideoGenerationMetadata: Codable {
    let voiceType: AIVoiceType
    let musicGenre: MusicGenre
    let visualStyle: VideoStyle
    let processingTime: TimeInterval
}


struct VisualScene: Codable {
    let duration: TimeInterval
    let content: String
    let style: VisualStyle
    let effects: [String]
}

struct Transition: Codable {
    let type: TransitionType
    let duration: TimeInterval
}

struct VisualEffect: Codable {
    let name: String
    let intensity: Double
    let duration: TimeInterval
}

// MARK: - Enums

enum VideoStyle: String, Codable, CaseIterable {
    case educational, entertainment, news, gaming, lifestyle, tech, comedy
}

enum AIVoiceType: String, Codable, CaseIterable {
    case professional, friendly, energetic, authoritative, casual
}

enum AIVoiceEmotion: String, Codable, CaseIterable {
    case neutral, engaging, excited, calm, serious
}

enum AIAudioQuality: String, Codable, CaseIterable {
    case standard, high, studio, broadcast
}

enum TransitionStyle: String, Codable, CaseIterable {
    case smart, smooth, dynamic, minimal, creative
}

enum EffectStyle: String, Codable, CaseIterable {
    case professional, cinematic, modern, vintage, artistic
}

enum ColorGradingStyle: String, Codable, CaseIterable {
    case cinematic, natural, vibrant, moody, bright
}

enum VideoResolution: String, Codable, CaseIterable {
    case hd = "1080p"
    case fourK = "4K"
    case eightK = "8K"
}

enum VideoFormat: String, Codable, CaseIterable {
    case mp4, mov, avi, mkv
}

enum MusicGenre: String, Codable, CaseIterable {
    case cinematic, electronic, acoustic, ambient, upbeat
}

enum MusicMood: String, Codable, CaseIterable {
    case inspiring, energetic, calm, dramatic, mysterious
}

enum MusicIntensity: String, Codable, CaseIterable {
    case low, medium, high, epic
}

enum ScriptMood: String, Codable, CaseIterable {
    case informative, entertaining, inspiring, urgent, mysterious
}

enum VisualStyle: String, Codable, CaseIterable {
    case realistic, animated, abstract, cinematic, minimalist
}

enum TransitionType: String, Codable, CaseIterable {
    case cut, fade, dissolve, wipe, zoom
}

enum AIGenerationAudienceType: String, Codable, CaseIterable {
    case general, tech, gaming, lifestyle, education, business
    
    var displayName: String {
        switch self {
        case .general: return "General Audience"
        case .tech: return "Tech Enthusiasts"
        case .gaming: return "Gaming Community"
        case .lifestyle: return "Lifestyle"
        case .education: return "Educational"
        case .business: return "Business Professionals"
        }
    }
}


// MARK: - AI Service Placeholders

class AdvancedScriptAI {
    func generateAdvancedScript(topic: String, style: VideoStyle, duration: TimeInterval, includeHooks: Bool, includeCallToActions: Bool, optimizeForViral: Bool) async throws -> AIScript {
        return AIScript(
            title: "The Ultimate Guide to \(topic) - Mind-Blowing Results!",
            description: "Discover the secrets of \(topic) that experts don't want you to know!",
            fullText: "Welcome to the ultimate guide on \(topic)...",
            sections: [],
            mood: .informative,
            hooks: ["Did you know that \(topic) can change your life?"],
            callToActions: ["Subscribe for more amazing content!"],
            keywords: [topic, "guide", "tutorial", "amazing"],
            estimatedDuration: duration
        )
    }
    
    func generateViralTitle(originalTitle: String, topic: String, targetAudience: AIGenerationAudienceType) async throws -> String {
        return "🔥 \(originalTitle) - You Won't Believe What Happens Next!"
    }
    
    func generateViralDescription(video: Video, includeKeywords: Bool, includeHashtags: Bool, optimizeForSEO: Bool) async throws -> String {
        return "🚀 This video will blow your mind! \(video.description) #viral #amazing #mustwatch"
    }
}

class VoiceSynthesisAI {
    func synthesizeVoice(script: String, voice: AIVoiceType, emotion: AIVoiceEmotion, speed: Double, includeBreaths: Bool) async throws -> AIVoiceover {
        return AIVoiceover(
            audioURL: "https://example.com/voiceover.mp3",
            duration: 300,
            voiceType: voice,
            emotion: emotion,
            quality: .studio
        )
    }
}

class VideoGenerationAI {
    func generateVisuals(script: AIScript, style: VideoStyle, resolution: VideoResolution, frameRate: Int) async throws -> AIVisuals {
        return AIVisuals(
            scenes: [],
            transitions: [],
            effects: [],
            resolution: resolution,
            frameRate: frameRate
        )
    }
}

class MusicGenerationAI {
    func generateBackgroundMusic(mood: ScriptMood, duration: TimeInterval, genre: MusicGenre, intensity: MusicIntensity) async throws -> AIMusic {
        return AIMusic(
            audioURL: "https://example.com/music.mp3",
            genre: genre,
            mood: .inspiring,
            intensity: intensity,
            duration: duration
        )
    }
}

class ThumbnailCreationAI {
    func generateViralThumbnail(topic: String, style: ThumbnailStyle, includeEmotions: Bool, includeText: Bool) async throws -> AIGenerationThumbnail {
        return AIGenerationThumbnail(
            url: "https://example.com/thumbnail.jpg",
            style: style,
            elements: [],
            viralScore: 0.9
        )
    }
    
    func generateThumbnailVariants(video: Video, count: Int, styles: [ThumbnailStyle]) async throws -> [AIGenerationThumbnail] {
        return styles.map { style in
            AIGenerationThumbnail(url: "https://example.com/thumb_\(style).jpg", style: style, elements: [], viralScore: 0.85)
        }
    }
}

class TrendAnalysisAI {
    func fetchLatestTrends() async throws -> [AIGenerationTrendingTopic] {
        return await getCurrentTrends()
    }
    
    func getCurrentTrends() async -> [AIGenerationTrendingTopic] {
        return [
            AIGenerationTrendingTopic(
                id: UUID().uuidString,
                topic: "AI Revolution 2024",
                category: .technology,
                trendingScore: 95.0,
                searchVolume: 1000000,
                growthRate: 0.5,
                keywords: ["AI", "technology", "revolution"],
                estimatedViews: 2000000,
                difficulty: .medium,
                viralPotential: 0.9
            ),
            AIGenerationTrendingTopic(
                id: UUID().uuidString,
                topic: "Productivity Hacks",
                category: .lifestyle,
                trendingScore: 88.0,
                searchVolume: 500000,
                growthRate: 0.3,
                keywords: ["productivity", "hacks", "tips"],
                estimatedViews: 800000,
                difficulty: .easy,
                viralPotential: 0.8
            )
        ]
    }
    
    func analyzeTrendVelocity() async throws -> [String] { return [] }
    func analyzeSocialMediaSignals() async throws -> [String] { return [] }
    func analyzeSearchPatterns() async throws -> [String] { return [] }
    func analyzeCompetitorActivity() async throws -> [String] { return [] }
    func predictViralTopics(trends: [String], socialSignals: [String], searchPatterns: [String], competitorActivity: [String], timeframe: TimeInterval) async throws -> [AIGenerationViralPrediction] { return [] }
    func getLatestTrends() async throws -> [AIGenerationTrendingTopic] { return await getCurrentTrends() }
}

class AIVideoAssembler {
    func assemble(script: AIScript, voiceover: AIVoiceover, visuals: AIVisuals, music: AIMusic, thumbnail: AIGenerationThumbnail, transitions: TransitionType, effects: String, colorGrading: String) async throws -> AIVideo {
        return AIVideo(
            url: "https://example.com/generated_video.mp4",
            duration: script.estimatedDuration,
            resolution: .fourK,
            fileSize: 1024 * 1024 * 100, // 100MB
            format: .mp4
        )
    }
}

// Placeholder structs
struct VideoAnalysis {
    let primaryAudience: AIGenerationAudienceType = .general
    let viralPotential: Double = 0.7
    let recommendations: [String] = []
    let suggestions: [String] = []
    let engagementPotential: Double = 0.75
}

struct ScriptSection: Codable {
    let title: String
    let content: String
    let duration: TimeInterval
}

struct AIGenerationTrendingTopic: Identifiable, Codable {
    let id: String
    let topic: String
    let category: VideoCategory
    let trendingScore: Double
    let searchVolume: Int
    let growthRate: Double
    let keywords: [String]
    let estimatedViews: Int
    let difficulty: DifficultyLevel
    let viralPotential: Double
    
    enum DifficultyLevel: String, Codable, CaseIterable {
        case easy, medium, hard
    }
}

