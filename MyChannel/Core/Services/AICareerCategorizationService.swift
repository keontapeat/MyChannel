//
//  AICareerCategorizationService.swift
//  MyChannel
//
//  AI-Powered Video Categorization for Career Paths
//  Uses GPT-5/Claude to intelligently classify videos
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class AICareerCategorizationService: ObservableObject {
    static let shared = AICareerCategorizationService()
    private init() {}
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    // MARK: - Categorization
    
    /// Categorize a video into career paths using AI
    func categorizeVideo(
        videoId: String,
        title: String,
        description: String,
        tags: [String],
        category: String?
    ) async throws -> VideoCategorization {
        // Check cache first
        if let cached = try await getCachedCategorization(videoId: videoId) {
            print("✅ [AI Categorization] Using cached result for video: \(videoId)")
            return cached
        }
        
        print("🤖 [AI Categorization] Analyzing video: \(title)")
        
        // Build AI prompt
        let prompt = buildCategorizationPrompt(
            title: title,
            description: description,
            tags: tags,
            category: category
        )
        
        // Call AI service (mock for now - integrate with your AI service)
        let aiResult = try await callAIForCategorization(prompt: prompt)
        
        // Parse AI response
        var categorization = parseAIResponse(aiResult, videoId: videoId)
        
        // 🔥 NEW: Calculate quality score
        categorization.qualityScore = calculateQualityScore(title: title, description: description)
        
        // 🔥 NEW: Determine certificate eligibility
        categorization.certificateEligible = isCertificateEligible(categorization: categorization)
        
        // 🔥 NEW: Calculate AI verification score
        categorization.aiVerificationScore = calculateAIVerificationScore(categorization: categorization)
        
        // Cache result
        try await cacheCategorization(categorization)
        
        print("✅ [AI Categorization] Categorized into \(categorization.careerPaths.count) career paths")
        print("   Confidence: \(Int(categorization.confidence * 100))% | Quality: \(categorization.qualityScore) | Certificate Eligible: \(categorization.certificateEligible)")
        
        return categorization
    }
    
    /// Batch categorize multiple videos (for watch history)
    func categorizeVideos(_ videos: [(videoId: String, title: String, description: String, tags: [String], category: String?)]) async throws -> [VideoCategorization] {
        print("🚀 [AI Categorization] Batch processing \(videos.count) videos...")
        
        var results: [VideoCategorization] = []
        
        for (index, video) in videos.enumerated() {
            do {
                let categorization = try await categorizeVideo(
                    videoId: video.videoId,
                    title: video.title,
                    description: video.description,
                    tags: video.tags,
                    category: video.category
                )
                results.append(categorization)
                
                if (index + 1) % 10 == 0 {
                    print("📊 [AI Categorization] Progress: \(index + 1)/\(videos.count) videos processed")
                }
                
                // Rate limiting - wait 100ms between requests
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                print("⚠️ [AI Categorization] Failed to categorize video \(video.videoId): \(error)")
                // Continue with next video
            }
        }
        
        print("✅ [AI Categorization] Batch processing complete: \(results.count)/\(videos.count) videos categorized")
        
        return results
    }
    
    // MARK: - AI Prompt Building
    
    private func buildCategorizationPrompt(
        title: String,
        description: String,
        tags: [String],
        category: String?
    ) -> String {
        let allCareerPaths = CareerPath.allCareerPaths.map { path in
            "\(path.name): \(path.keywords.joined(separator: ", "))"
        }.joined(separator: "\n")
        
        return """
        Analyze this video and determine which career paths it belongs to.
        
        Video Title: \(title)
        Description: \(description)
        Tags: \(tags.joined(separator: ", "))
        Category: \(category ?? "Unknown")
        
        Available Career Paths:
        \(allCareerPaths)
        
        Instructions:
        1. Determine which career paths this video teaches (can be multiple)
        2. Assign a confidence score (0.0-1.0) for each career path
        3. Only include career paths with confidence >= 0.7
        4. Extract specific skill tags covered in the video
        5. Determine difficulty level (beginner, intermediate, advanced, expert)
        
        Respond in JSON format:
        {
          "careerPaths": [
            {
              "id": "career-path-id",
              "confidence": 0.95
            }
          ],
          "skillTags": ["skill1", "skill2"],
          "difficulty": "intermediate",
          "reasoning": "Brief explanation"
        }
        """
    }
    
    // MARK: - AI Service Call (Mock)
    
    private func callAIForCategorization(prompt: String) async throws -> String {
        // TODO: Replace with actual AI service call (GPT-5, Claude, etc.)
        // For now, use mock categorization based on keywords
        
        try await Task.sleep(nanoseconds: 200_000_000) // Simulate API delay
        
        // Mock response - in production, this would call your AI service
        return mockAIResponse(prompt: prompt)
    }
    
    private func mockAIResponse(prompt: String) -> String {
        // Simple keyword matching for demo
        let lowercasePrompt = prompt.lowercased()
        
        var careerPaths: [[String: Any]] = []
        
        // Check each career path
        for careerPath in CareerPath.allCareerPaths {
            var matchCount = 0
            for keyword in careerPath.keywords {
                if lowercasePrompt.contains(keyword.lowercased()) {
                    matchCount += 1
                }
            }
            
            if matchCount > 0 {
                let confidence = min(0.95, Double(matchCount) / Double(careerPath.keywords.count) + 0.5)
                if confidence >= 0.7 {
                    careerPaths.append([
                        "id": careerPath.id,
                        "confidence": confidence
                    ])
                }
            }
        }
        
        // Extract skill tags (simplified)
        var skillTags: [String] = []
        if lowercasePrompt.contains("programming") || lowercasePrompt.contains("coding") {
            skillTags.append("Programming")
        }
        if lowercasePrompt.contains("design") {
            skillTags.append("Design")
        }
        if lowercasePrompt.contains("marketing") {
            skillTags.append("Marketing")
        }
        
        let difficulty = lowercasePrompt.contains("advanced") ? "advanced" :
                        lowercasePrompt.contains("beginner") ? "beginner" : "intermediate"
        
        let response: [String: Any] = [
            "careerPaths": careerPaths,
            "skillTags": skillTags,
            "difficulty": difficulty,
            "reasoning": "Categorized based on video content analysis"
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{}"
    }
    
    // MARK: - Response Parsing
    
    private func parseAIResponse(_ response: String, videoId: String) -> VideoCategorization {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("⚠️ [AI Categorization] Failed to parse AI response")
            return VideoCategorization(
                videoId: videoId,
                careerPaths: [],
                skillTags: [],
                difficulty: .intermediate,
                confidence: 0.0,
                categorizedAt: Date(),
                reasoning: "Failed to parse"
            )
        }
        
        let careerPathsData = json["careerPaths"] as? [[String: Any]] ?? []
        let careerPaths = careerPathsData.compactMap { dict -> CareerPathMatch? in
            guard let id = dict["id"] as? String,
                  let confidence = dict["confidence"] as? Double else {
                return nil
            }
            return CareerPathMatch(careerPathId: id, confidence: confidence)
        }
        
        let skillTags = json["skillTags"] as? [String] ?? []
        let difficultyString = json["difficulty"] as? String ?? "intermediate"
        let difficulty = UniversityVideo.DifficultyLevel(rawValue: difficultyString.capitalized) ?? .intermediate
        let reasoning = json["reasoning"] as? String ?? ""
        
        // Overall confidence is the average of all career path confidences
        let avgConfidence = careerPaths.isEmpty ? 0.0 : careerPaths.map(\.confidence).reduce(0, +) / Double(careerPaths.count)
        
        return VideoCategorization(
            videoId: videoId,
            careerPaths: careerPaths,
            skillTags: skillTags,
            difficulty: difficulty,
            confidence: avgConfidence,
            categorizedAt: Date(),
            reasoning: reasoning
        )
    }
    
    // MARK: - 🔥 NEW: Quality Scoring & Eligibility
    
    /// Calculate video quality score (0-100)
    /// Factors: title length, description quality, professional keywords
    private func calculateQualityScore(title: String, description: String) -> Int {
        var score = 50 // Base score
        
        // Title length check (optimal: 40-70 chars)
        let titleLength = title.count
        if titleLength >= 40 && titleLength <= 70 {
            score += 15
        } else if titleLength >= 20 && titleLength <= 100 {
            score += 8
        }
        
        // Description quality (optimal: 100+ chars, structured)
        let descLength = description.count
        if descLength >= 200 {
            score += 15
        } else if descLength >= 100 {
            score += 8
        }
        
        // Professional keywords in title
        let professionalKeywords = ["learn", "tutorial", "guide", "course", "lesson", "master", "complete", "beginner", "advanced", "professional", "training", "education"]
        let titleLower = title.lowercased()
        let professionalCount = professionalKeywords.filter { titleLower.contains($0) }.count
        score += min(professionalCount * 5, 20)
        
        // Cap at 100
        return min(score, 100)
    }
    
    /// Determine if video is eligible for certificate tracking
    /// Requirements: 1+ career path, 0.7+ confidence, 70+ quality score
    private func isCertificateEligible(categorization: VideoCategorization) -> Bool {
        // Must have at least 1 career path
        guard !categorization.careerPaths.isEmpty else { return false }
        
        // Must have high confidence (0.7+) for at least 1 path
        let hasHighConfidence = categorization.careerPaths.contains { $0.confidence >= 0.7 }
        guard hasHighConfidence else { return false }
        
        // Must have quality score 70+
        guard categorization.qualityScore >= 70 else { return false }
        
        return true
    }
    
    /// Calculate overall AI verification score (0-100)
    /// Combines categorization confidence + quality score
    private func calculateAIVerificationScore(categorization: VideoCategorization) -> Int {
        guard !categorization.careerPaths.isEmpty else { return 0 }
        
        // Weighted: 60% categorization confidence, 40% quality
        let verificationScore = (categorization.confidence * 0.6 + Double(categorization.qualityScore) / 100.0 * 0.4) * 100
        
        return Int(verificationScore)
    }
    
    // MARK: - Caching
    
    private func getCachedCategorization(videoId: String) async throws -> VideoCategorization? {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("video_categorizations").document(videoId).getDocument()
            
            if doc.exists, let data = doc.data() {
                return try parseCategorization(from: data, videoId: videoId)
            }
        } catch {
            print("⚠️ [AI Categorization] Cache lookup failed: \(error)")
        }
        #endif
        
        return nil
    }
    
    private func cacheCategorization(_ categorization: VideoCategorization) async throws {
        #if canImport(FirebaseFirestore)
        do {
            let data = try categorizationToDict(categorization)
            try await db.collection("video_categorizations").document(categorization.videoId).setData(data)
            print("💾 [AI Categorization] Cached result for video: \(categorization.videoId)")
        } catch {
            print("⚠️ [AI Categorization] Failed to cache: \(error)")
        }
        #endif
    }
    
    private func parseCategorization(from data: [String: Any], videoId: String) throws -> VideoCategorization {
        let careerPathsData = data["careerPaths"] as? [[String: Any]] ?? []
        let careerPaths = careerPathsData.compactMap { dict -> CareerPathMatch? in
            guard let id = dict["careerPathId"] as? String,
                  let confidence = dict["confidence"] as? Double else {
                return nil
            }
            return CareerPathMatch(careerPathId: id, confidence: confidence)
        }
        
        let skillTags = data["skillTags"] as? [String] ?? []
        let difficultyString = data["difficulty"] as? String ?? "intermediate"
        let difficulty = UniversityVideo.DifficultyLevel(rawValue: difficultyString) ?? .intermediate
        let confidence = data["confidence"] as? Double ?? 0.0
        let categorizedAt = (data["categorizedAt"] as? Timestamp)?.dateValue() ?? Date()
        let reasoning = data["reasoning"] as? String ?? ""
        
        return VideoCategorization(
            videoId: videoId,
            careerPaths: careerPaths,
            skillTags: skillTags,
            difficulty: difficulty,
            confidence: confidence,
            categorizedAt: categorizedAt,
            reasoning: reasoning
        )
    }
    
    private func categorizationToDict(_ categorization: VideoCategorization) throws -> [String: Any] {
        return [
            "videoId": categorization.videoId,
            "careerPaths": categorization.careerPaths.map { ["careerPathId": $0.careerPathId, "confidence": $0.confidence] },
            "skillTags": categorization.skillTags,
            "difficulty": categorization.difficulty.rawValue,
            "confidence": categorization.confidence,
            "categorizedAt": Timestamp(date: categorization.categorizedAt),
            "reasoning": categorization.reasoning
        ]
    }
}

// MARK: - Models

struct VideoCategorization: Codable {
    let videoId: String
    let careerPaths: [CareerPathMatch]
    let skillTags: [String]
    let difficulty: UniversityVideo.DifficultyLevel
    let confidence: Double // 0.0-1.0
    let categorizedAt: Date
    let reasoning: String
    
    // 🔥 NEW: Quality & Eligibility
    var qualityScore: Int = 0 // 0-100 content quality score
    var certificateEligible: Bool = false // Eligible for certificate tracking
    var aiVerificationScore: Int = 0 // 0-100 overall AI score
}

struct CareerPathMatch: Codable {
    let careerPathId: String
    let confidence: Double // 0.0-1.0
}

