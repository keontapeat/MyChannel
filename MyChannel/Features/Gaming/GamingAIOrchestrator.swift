//
//  GamingAIOrchestrator.swift
//  MyChannel
//
//  🔥🔥🔥 NUCLEAR-LEVEL VERTEX AI GAMING AGENTS 🔥🔥🔥
//  The BEST ML agents in the world for competitive gaming!
//
//  7 Specialized AI Agents:
//  1. 🎮 Match Fairness AI - Ensures fair matchmaking with skill-based ELO
//  2. 🛡️ Anti-Cheat Guardian AI - Real-time cheat detection with ML
//  3. 💰 Prize Pool Optimizer AI - Dynamic prize optimization
//  4. 🏆 Tournament Bracket AI - Intelligent bracket generation
//  5. 📊 Performance Predictor AI - Win probability & skill analysis
//  6. 🎯 Gameplay Video Analyzer AI - Frame-by-frame analysis for verification
//  7. ⚖️ Dispute Resolution AI - AI-powered referee decisions
//
//  Created by Keonta Peat
//  Copyright © 2025 MyChannel. All rights reserved.
//

import Foundation
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - 🎮 Gaming AI Orchestrator (Master Controller)

@MainActor
final class GamingAIOrchestrator: ObservableObject {
    static let shared = GamingAIOrchestrator()
    
    // MARK: - Published State
    @Published var isOnline = false
    @Published var agentsActive: Int = 0
    @Published var totalPredictions: Int = 0
    @Published var accuracy: Double = 0.0
    @Published var latencyMs: Double = 0.0
    
    // MARK: - 7 Specialized Gaming AI Agents
    let matchFairnessAI = MatchFairnessAI.shared
    let antiCheatGuardianAI = AntiCheatGuardianAI.shared
    let prizePoolOptimizerAI = PrizePoolOptimizerAI.shared
    let tournamentBracketAI = TournamentBracketAI.shared
    let performancePredictorAI = PerformancePredictorAI.shared
    let gameplayVideoAnalyzerAI = GameplayVideoAnalyzerAI.shared
    let disputeResolutionAI = DisputeResolutionAI.shared
    
    // MARK: - Google Cloud Configuration
    private let projectID = AppSecrets.googleCloudProjectID.isEmpty ? "mychannel-ca26d" : AppSecrets.googleCloudProjectID
    private let location = "us-central1"
    
    // 🔥 LIVE Cloud Run endpoints - ALL 7 AGENTS DEPLOYED!
    private let agentEndpoints: [String: String] = [
        "matchFairness": "https://mychannel-gaming-match-fairness-fkri6ifojq-uc.a.run.app",
        "antiCheat": "https://mychannel-gaming-anti-cheat-fkri6ifojq-uc.a.run.app",
        "prizePool": "https://mychannel-gaming-prize-pool-fkri6ifojq-uc.a.run.app",
        "tournamentBracket": "https://mychannel-gaming-tournament-bracket-fkri6ifojq-uc.a.run.app",
        "performancePredictor": "https://mychannel-gaming-performance-predictor-fkri6ifojq-uc.a.run.app",
        "gameplayAnalyzer": "https://mychannel-gaming-gameplay-analyzer-fkri6ifojq-uc.a.run.app",
        "disputeResolution": "https://mychannel-gaming-dispute-resolution-fkri6ifojq-uc.a.run.app"
    ]
    
    // URLSession for API calls
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    /// Prevents runtime traps when converting telemetry values to Int for logs.
    private func safeInt(_ value: Double, fallback: Int = 0) -> Int {
        guard value.isFinite else { return fallback }
        return Int(value.rounded())
    }
    
    private init() {
        Task {
            await initializeAllAgents()
        }
    }
    
    // MARK: - Initialize All Agents
    
    private func initializeAllAgents() async {
        print("🚀 [GamingAI] Initializing 7 Nuclear-Level Gaming AI Agents...")
        
        let startTime = Date()
        
        // Initialize all agents in parallel, passing self reference to prevent circular dependency
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { await self.matchFairnessAI.initialize(orchestrator: self) }
            group.addTask { await self.antiCheatGuardianAI.initialize() }
            group.addTask { await self.prizePoolOptimizerAI.initialize() }
            group.addTask { await self.tournamentBracketAI.initialize() }
            group.addTask { await self.performancePredictorAI.initialize() }
            group.addTask { await self.gameplayVideoAnalyzerAI.initialize() }
            group.addTask { await self.disputeResolutionAI.initialize() }
            
            var activeCount = 0
            for await result in group {
                if result { activeCount += 1 }
            }
            agentsActive = activeCount
        }
        
        latencyMs = Date().timeIntervalSince(startTime) * 1000
        isOnline = agentsActive == 7
        
        print("✅ [GamingAI] \(agentsActive)/7 agents online in \(safeInt(latencyMs))ms")
    }
    
    // MARK: - 🌐 Cloud Function API Calls
    
    /// Call a Cloud Function endpoint with JSON payload
    func callCloudFunction<T: Decodable>(
        agent: String,
        payload: [String: Any]
    ) async throws -> T {
        guard let endpoint = agentEndpoints[agent],
              let url = URL(string: endpoint) else {
            throw GamingAIError.invalidEndpoint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add API key if available
        if !AppSecrets.googleCloudAPIKey.isEmpty {
            request.setValue("Bearer \(AppSecrets.googleCloudAPIKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GamingAIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ [GamingAI] API error: \(httpResponse.statusCode)")
            throw GamingAIError.apiError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    /// Call Cloud Function with fallback to local computation
    func callWithFallback<T: Decodable>(
        agent: String,
        payload: [String: Any],
        fallback: () async -> T
    ) async -> T {
        do {
            return try await callCloudFunction(agent: agent, payload: payload)
        } catch {
            print("⚠️ [GamingAI] Cloud function failed, using local fallback: \(error)")
            return await fallback()
        }
    }
    
    // MARK: - 🎮 MATCH CREATION PIPELINE
    
    /// Complete AI pipeline for creating a fair VS match
    func createFairMatch(
        challengerId: String,
        opponentId: String,
        wagerAmount: Double,
        category: String
    ) async throws -> AIMatchCreationResult {
        print("🤖 [GamingAI] Creating fair match with full AI pipeline...")
        let startTime = Date()
        
        // Step 1: Analyze both players' skill levels
        let challengerSkill = await performancePredictorAI.analyzePlayerSkill(playerId: challengerId)
        let opponentSkill = await performancePredictorAI.analyzePlayerSkill(playerId: opponentId)
        
        // Step 2: Check fairness score
        let fairnessResult = await matchFairnessAI.evaluateMatchFairness(
            player1Skill: challengerSkill,
            player2Skill: opponentSkill,
            wagerAmount: wagerAmount
        )
        
        // Step 3: Run fraud detection on both players
        let challengerFraudRisk = await antiCheatGuardianAI.analyzePlayerRisk(playerId: challengerId)
        let opponentFraudRisk = await antiCheatGuardianAI.analyzePlayerRisk(playerId: opponentId)
        
        // Step 4: Optimize prize pool
        let optimizedPrize = await prizePoolOptimizerAI.optimizePrizePool(
            baseWager: wagerAmount,
            playerSkills: [challengerSkill, opponentSkill],
            category: category
        )
        
        // Step 5: Calculate win probabilities
        let winProbability = await performancePredictorAI.predictWinProbability(
            player1Skill: challengerSkill,
            player2Skill: opponentSkill,
            category: category
        )
        
        totalPredictions += 5
        let latency = Date().timeIntervalSince(startTime) * 1000
        
        print("✅ [GamingAI] Match created in \(safeInt(latency))ms - Fairness: \(safeInt(fairnessResult.fairnessScore * 100))%")
        
        return AIMatchCreationResult(
            fairnessScore: fairnessResult.fairnessScore,
            challengerSkillRating: challengerSkill.eloRating,
            opponentSkillRating: opponentSkill.eloRating,
            challengerWinProbability: winProbability.player1WinProbability,
            opponentWinProbability: winProbability.player2WinProbability,
            recommendedDuration: fairnessResult.recommendedDuration,
            optimizedPrizePool: optimizedPrize.optimizedAmount,
            platformFee: optimizedPrize.platformFee,
            challengerRiskLevel: challengerFraudRisk.riskLevel,
            opponentRiskLevel: opponentFraudRisk.riskLevel,
            aiConfidence: fairnessResult.confidence,
            processingTimeMs: latency
        )
    }
    
    // MARK: - 🏆 TOURNAMENT PIPELINE
    
    /// AI-powered tournament bracket generation
    func generateTournamentBracket(
        players: [String],
        prizePool: Double,
        format: TournamentFormat
    ) async throws -> AITournamentBracket {
        print("🤖 [GamingAI] Generating AI-optimized tournament bracket...")
        
        // Step 1: Analyze all player skills
        var playerSkills: [String: PlayerSkillAnalysis] = [:]
        await withTaskGroup(of: (String, PlayerSkillAnalysis).self) { group in
            for playerId in players {
                group.addTask {
                    let skill = await self.performancePredictorAI.analyzePlayerSkill(playerId: playerId)
                    return (playerId, skill)
                }
            }
            for await (playerId, skill) in group {
                playerSkills[playerId] = skill
            }
        }
        
        // Step 2: Generate seeded bracket
        let bracket = await tournamentBracketAI.generateSeededBracket(
            players: players,
            skills: playerSkills,
            format: format
        )
        
        // Step 3: Optimize prize distribution
        let prizeDistribution = await prizePoolOptimizerAI.optimizeTournamentPrizes(
            totalPrize: prizePool,
            playerCount: players.count,
            format: format
        )
        
        totalPredictions += players.count + 2
        
        return AITournamentBracket(
            rounds: bracket.rounds,
            seeds: bracket.seeds,
            prizeDistribution: prizeDistribution,
            estimatedDuration: bracket.estimatedDuration,
            fairnessScore: bracket.fairnessScore
        )
    }
    
    // MARK: - 🎯 MATCH VERIFICATION PIPELINE
    
    /// AI-powered match result verification
    func verifyMatchResult(
        matchId: String,
        player1VideoURL: String,
        player2VideoURL: String,
        player1Score: Int,
        player2Score: Int
    ) async throws -> AIMatchVerificationResult {
        print("🤖 [GamingAI] Running AI match verification pipeline...")
        let startTime = Date()
        
        // Step 1: Analyze both gameplay videos in parallel
        async let video1Analysis = gameplayVideoAnalyzerAI.analyzeGameplayVideo(
            videoURL: player1VideoURL,
            reportedScore: player1Score
        )
        
        async let video2Analysis = gameplayVideoAnalyzerAI.analyzeGameplayVideo(
            videoURL: player2VideoURL,
            reportedScore: player2Score
        )
        
        let (analysis1, analysis2) = await (video1Analysis, video2Analysis)
        
        // Step 2: Cross-validate scores
        let scoreValidation = await gameplayVideoAnalyzerAI.crossValidateScores(
            analysis1: analysis1,
            analysis2: analysis2,
            reported1: player1Score,
            reported2: player2Score
        )
        
        // Step 3: Check for cheating indicators
        let cheatCheck1 = await antiCheatGuardianAI.analyzeGameplayForCheats(analysis: analysis1)
        let cheatCheck2 = await antiCheatGuardianAI.analyzeGameplayForCheats(analysis: analysis2)
        
        // Step 4: Determine winner
        let verifiedWinner: String?
        let verificationStatus: GamingVerificationStatus
        
        if scoreValidation.scoresMatch && !cheatCheck1.cheatingDetected && !cheatCheck2.cheatingDetected {
            verifiedWinner = analysis1.detectedScore > analysis2.detectedScore ? "player1" : "player2"
            verificationStatus = .verified
        } else if cheatCheck1.cheatingDetected || cheatCheck2.cheatingDetected {
            verifiedWinner = nil
            verificationStatus = .flaggedForReview
        } else {
            verifiedWinner = nil
            verificationStatus = .disputed
        }
        
        totalPredictions += 4
        let latency = Date().timeIntervalSince(startTime) * 1000
        
        print("✅ [GamingAI] Verification complete in \(safeInt(latency))ms - Status: \(verificationStatus)")
        
        return AIMatchVerificationResult(
            status: verificationStatus,
            verifiedWinner: verifiedWinner,
            player1DetectedScore: analysis1.detectedScore,
            player2DetectedScore: analysis2.detectedScore,
            player1CheatProbability: cheatCheck1.cheatProbability,
            player2CheatProbability: cheatCheck2.cheatProbability,
            scoreMatchConfidence: scoreValidation.confidence,
            processingTimeMs: latency
        )
    }
    
    // MARK: - ⚖️ DISPUTE RESOLUTION PIPELINE
    
    /// AI-powered dispute resolution
    func resolveDispute(
        matchId: String,
        player1Claim: String,
        player2Claim: String,
        evidence: [String]
    ) async throws -> AIDisputeResolution {
        print("🤖 [GamingAI] Running AI dispute resolution...")
        
        let resolution = await disputeResolutionAI.analyzeDispute(
            matchId: matchId,
            player1Claim: player1Claim,
            player2Claim: player2Claim,
            evidence: evidence
        )
        
        totalPredictions += 1
        
        return resolution
    }
    
    // MARK: - 📊 REAL-TIME MONITORING
    
    /// Start real-time monitoring for a live match
    func startLiveMatchMonitoring(matchId: String) async {
        print("🤖 [GamingAI] Starting real-time match monitoring...")
        await antiCheatGuardianAI.startRealTimeMonitoring(matchId: matchId)
    }
    
    /// Stop monitoring
    func stopLiveMatchMonitoring(matchId: String) async {
        await antiCheatGuardianAI.stopRealTimeMonitoring(matchId: matchId)
    }

    // MARK: - 🏆 CHAMPIONSHIP TRACKING

    /// Track any championship event (view opened, medal tapped, division switched, defense scheduled)
    /// Persists to Firestore so AI agents can learn from engagement patterns
    func trackChampionshipEvent(
        userId: String,
        event: ChampionshipAIEvent
    ) async {
        totalPredictions += 1
        print("📊 [GamingAI] Championship event: \(event.rawValue) for user: \(userId.prefix(8))")

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let payload: [String: Any] = [
            "userId": userId,
            "event": event.rawValue,
            "timestamp": FieldValue.serverTimestamp(),
            "agentsActive": agentsActive,
            "source": "championship_hub"
        ]
        try? await db.collection("ai_championship_events").addDocument(data: payload)
        #endif
    }

    /// AI refreshes rankings for a division using PerformancePredictor + LeaderboardCalculator
    /// Called when user opens ChampionshipHubView or switches divisions
    func refreshRankingsWithAI(
        division: String,
        currentUserIds: [String]
    ) async -> AIRankingRefreshResult {
        print("🤖 [GamingAI] AI refreshing \(division) rankings for \(currentUserIds.count) players...")
        let start = Date()

        // Analyze each player skill in parallel
        var skills: [String: PlayerSkillAnalysis] = [:]
        await withTaskGroup(of: (String, PlayerSkillAnalysis).self) { group in
            for uid in currentUserIds {
                group.addTask {
                    let skill = await self.performancePredictorAI.analyzePlayerSkill(playerId: uid)
                    return (uid, skill)
                }
            }
            for await (uid, skill) in group {
                skills[uid] = skill
            }
        }

        // Sort by ELO for AI-suggested ranking order
        let sorted = currentUserIds.sorted {
            (skills[$0]?.eloRating ?? 1000) > (skills[$1]?.eloRating ?? 1000)
        }

        let avgConfidence = skills.values.map { $0.dataConfidence }.reduce(0, +) / Double(max(skills.count, 1))
        let latencyMs = Date().timeIntervalSince(start) * 1000
        totalPredictions += currentUserIds.count

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        try? await db.collection("ai_ranking_refreshes").addDocument(data: [
            "division": division,
            "playerCount": currentUserIds.count,
            "avgConfidence": avgConfidence,
            "latencyMs": latencyMs,
            "timestamp": FieldValue.serverTimestamp()
        ])
        #endif

        print("✅ [GamingAI] Rankings refreshed in \(safeInt(latencyMs))ms — avg confidence: \(safeInt(avgConfidence * 100))%")
        return AIRankingRefreshResult(
            sortedPlayerIds: sorted,
            skillMap: skills,
            avgConfidence: avgConfidence,
            latencyMs: latencyMs
        )
    }

    /// AI analyses a tournament bracket for fairness and surfaces insights
    func analyzeBracketFairness(
        tournamentId: String,
        playerIds: [String]
    ) async -> AIBracketInsight {
        print("🤖 [GamingAI] Analyzing bracket fairness for tournament: \(tournamentId.prefix(8))")

        guard !playerIds.isEmpty else {
            return AIBracketInsight(fairnessScore: 1.0, topSeed: nil, predictedChampion: nil, insight: "No players yet", confidence: 0)
        }

        var skills: [String: PlayerSkillAnalysis] = [:]
        await withTaskGroup(of: (String, PlayerSkillAnalysis).self) { group in
            for uid in playerIds.prefix(16) {
                group.addTask {
                    let skill = await self.performancePredictorAI.analyzePlayerSkill(playerId: uid)
                    return (uid, skill)
                }
            }
            for await (uid, skill) in group {
                skills[uid] = skill
            }
        }

        let sorted = playerIds.sorted { (skills[$0]?.eloRating ?? 1000) > (skills[$1]?.eloRating ?? 1000) }
        let topSeed = sorted.first
        let predictedChampion = sorted.first

        let eloValues = skills.values.map { $0.eloRating }
        let avgElo = eloValues.reduce(0, +) / Double(max(eloValues.count, 1))
        let variance = eloValues.map { pow($0 - avgElo, 2) }.reduce(0, +) / Double(max(eloValues.count, 1))
        let stdDev = sqrt(variance)
        let fairnessScore = max(0.4, 1.0 - (stdDev / 600.0))

        let insight: String
        if fairnessScore > 0.85 {
            insight = "Highly competitive bracket — evenly matched field"
        } else if fairnessScore > 0.65 {
            insight = "Moderate skill spread — upsets likely"
        } else {
            insight = "Wide skill gap — top seeds heavily favored"
        }

        totalPredictions += playerIds.count
        return AIBracketInsight(
            fairnessScore: fairnessScore,
            topSeed: topSeed,
            predictedChampion: predictedChampion,
            insight: insight,
            confidence: skills.values.map { $0.dataConfidence }.reduce(0, +) / Double(max(skills.count, 1))
        )
    }
}


// ⚡ All result types + AI agent sub-types extracted to GamingAITypes.swift
