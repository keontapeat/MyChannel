//
//  MatchVerificationService.swift
//  MyChannel
//
//  Match Verification & Payout Service
//  Compares player submissions, verifies scores, triggers payouts
//

import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
final class MatchVerificationService: ObservableObject {
    static let shared = MatchVerificationService()
    
    // Published state
    @Published var pendingVerifications: [MatchVerification] = []
    @Published var isVerifying = false
    
    // Services
    private let db = Firestore.firestore()
    private let analysisService = GameplayVideoAnalysisService.shared
    private let escrowService = MoneyEscrowService.shared
    private let walletService = VSMatchWalletService.shared
    
    // Constants
    private let autoApproveConfidenceThreshold = 0.9 // 90%
    private let submissionWindowHours = 24.0
    
    private init() {
        print("✅ [MatchVerification] Service initialized")
    }
    
    // MARK: - Submit Match Result
    
    /// Submit match result with video proof
    /// - Parameters:
    ///   - matchId: Match identifier
    ///   - playerId: Player identifier
    ///   - videoURL: Uploaded video URL
    ///   - screenshotURL: Optional screenshot URL
    ///   - selfReportedScore: Player's reported score
    ///   - opponentScore: Opponent's reported score
    /// - Returns: Submission result
    func submitMatchResult(
        matchId: String,
        playerId: String,
        videoURL: String,
        screenshotURL: String?,
        selfReportedScore: Int,
        opponentScore: Int
    ) async throws -> SubmissionResult {
        print("📝 [MatchVerification] Submitting result for match: \(matchId)")
        print("   Player: \(playerId)")
        print("   Scores: \(selfReportedScore) - \(opponentScore)")
        
        // Step 1: Analyze video with AI
        print("🤖 [MatchVerification] Starting AI analysis...")
        
        // Download video for analysis (in production, would download from Firebase Storage)
        // For now, we'll simulate analysis
        let analysisResult = try await simulateVideoAnalysis(
            videoURL: videoURL,
            expectedScore: selfReportedScore
        )
        
        // Step 2: Create submission document
        let submission = MatchSubmission(
            id: "\(matchId)_\(playerId)",
            matchId: matchId,
            playerId: playerId,
            videoURL: videoURL,
            screenshotURL: screenshotURL,
            selfReportedScore: selfReportedScore,
            opponentScore: opponentScore,
            submittedAt: Date(),
            aiAnalysis: AIAnalysis(
                confidence: analysisResult.confidence,
                extractedScore: analysisResult.extractedScores.player1Score,
                scoreboardDetected: analysisResult.scoreboardDetected,
                analyzedAt: Date()
            ),
            status: .pending
        )
        
        // Step 3: Save submission
        try await saveSubmission(submission)
        
        // Step 4: Check if both players submitted
        let opponentSubmitted = try await checkOpponentSubmission(matchId: matchId, playerId: playerId)
        
        if opponentSubmitted {
            print("✅ [MatchVerification] Both players submitted - triggering verification")
            // Verify match immediately
            try await verifyMatch(matchId: matchId)
        } else {
            print("⏳ [MatchVerification] Waiting for opponent submission")
        }
        
        return SubmissionResult(
            success: true,
            submissionId: submission.id,
            awaitingOpponent: !opponentSubmitted
        )
    }
    
    // MARK: - Verify Match
    
    /// Verify match by comparing both players' submissions
    /// - Parameter matchId: Match identifier
    /// - Returns: Verification result
    func verifyMatch(matchId: String) async throws -> VerificationResult {
        print("🔍 [MatchVerification] Verifying match: \(matchId)")
        
        isVerifying = true
        defer { isVerifying = false }
        
        // Step 1: Get both submissions
        let submissions = try await getSubmissions(matchId: matchId)
        
        guard submissions.count == 2 else {
            print("⚠️ [MatchVerification] Not enough submissions (\(submissions.count)/2)")
            throw VerificationError.insufficientSubmissions
        }
        
        let submission1 = submissions[0]
        let submission2 = submissions[1]
        
        print("📊 [MatchVerification] Comparing submissions:")
        print("   Player 1: Score \(submission1.selfReportedScore), AI: \(submission1.aiAnalysis.extractedScore ?? -1), Confidence: \(Int(submission1.aiAnalysis.confidence * 100))%")
        print("   Player 2: Score \(submission2.selfReportedScore), AI: \(submission2.aiAnalysis.extractedScore ?? -1), Confidence: \(Int(submission2.aiAnalysis.confidence * 100))%")
        
        // Step 2: Check if can auto-approve
        let canAutoApprove = self.canAutoApprove(
            submission1: submission1,
            submission2: submission2
        )
        
        var verificationResult: VerificationResult
        
        if canAutoApprove {
            // Auto-approve
            print("✅ [MatchVerification] Auto-approving match (high confidence)")
            verificationResult = try await approveMatch(
                matchId: matchId,
                submission1: submission1,
                submission2: submission2,
                autoApproved: true
            )
        } else {
            // Flag for referee review
            print("🚩 [MatchVerification] Flagging for referee review (low confidence or mismatch)")
            verificationResult = try await flagForReview(
                matchId: matchId,
                submission1: submission1,
                submission2: submission2,
                reason: "Scores mismatch or low AI confidence"
            )
        }
        
        return verificationResult
    }
    
    // MARK: - Auto-Approve Logic
    
    /// Check if match can be auto-approved
    /// - Parameters:
    ///   - submission1: First player's submission
    ///   - submission2: Second player's submission
    /// - Returns: True if can auto-approve
    private func canAutoApprove(
        submission1: MatchSubmission,
        submission2: MatchSubmission
    ) -> Bool {
        // Condition 1: Both submissions have high AI confidence (>90%)
        let highConfidence = submission1.aiAnalysis.confidence > autoApproveConfidenceThreshold &&
                            submission2.aiAnalysis.confidence > autoApproveConfidenceThreshold
        
        // Condition 2: Self-reported scores match between players
        let scoresMatch = submission1.selfReportedScore == submission2.opponentScore &&
                         submission2.selfReportedScore == submission1.opponentScore
        
        // Condition 3: AI-extracted scores match self-reported scores
        let aiMatchesPlayer1 = submission1.aiAnalysis.extractedScore == submission1.selfReportedScore
        let aiMatchesPlayer2 = submission2.aiAnalysis.extractedScore == submission2.selfReportedScore
        
        // Condition 4: Scoreboards detected in both videos
        let scoreboardsDetected = submission1.aiAnalysis.scoreboardDetected &&
                                 submission2.aiAnalysis.scoreboardDetected
        
        let canApprove = highConfidence && scoresMatch && aiMatchesPlayer1 && aiMatchesPlayer2 && scoreboardsDetected
        
        print("   Auto-approve check:")
        print("   ✓ High confidence: \(highConfidence)")
        print("   ✓ Scores match: \(scoresMatch)")
        print("   ✓ AI matches P1: \(aiMatchesPlayer1)")
        print("   ✓ AI matches P2: \(aiMatchesPlayer2)")
        print("   ✓ Scoreboards: \(scoreboardsDetected)")
        print("   → Can auto-approve: \(canApprove)")
        
        return canApprove
    }
    
    // MARK: - Approve Match
    
    /// Approve match and trigger payout
    /// - Parameters:
    ///   - matchId: Match identifier
    ///   - submission1: First player's submission
    ///   - submission2: Second player's submission
    ///   - autoApproved: Whether auto-approved or manually approved
    /// - Returns: Verification result
    private func approveMatch(
        matchId: String,
        submission1: MatchSubmission,
        submission2: MatchSubmission,
        autoApproved: Bool
    ) async throws -> VerificationResult {
        // Determine winner
        let player1Score = submission1.selfReportedScore
        let player2Score = submission2.selfReportedScore
        
        guard player1Score != player2Score else {
            throw VerificationError.tiedScores
        }
        
        let winnerId = player1Score > player2Score ? submission1.playerId : submission2.playerId
        let loserId = player1Score > player2Score ? submission2.playerId : submission1.playerId
        
        print("🏆 [MatchVerification] Winner: \(winnerId)")
        
        // Get match details
        let match = try await getMatch(matchId: matchId)
        
        // Calculate payout (winner gets both wagers minus 10% platform fee)
        let totalWager = match.wagerAmount * 2
        let platformFee = totalWager * 0.1
        let winnerPayout = totalWager - platformFee
        
        print("💰 [MatchVerification] Payout: $\(winnerPayout) (fee: $\(platformFee))")
        
        // Step 1: Release escrow to winner
        try await escrowService.releaseFunds(
            matchId: matchId,
            winnerId: winnerId,
            loserId: loserId,
            amount: winnerPayout
        )
        
        // Step 2: Update winner's wallet
        try await walletService.depositFunds(
            userId: winnerId,
            amount: winnerPayout,
            paymentMethodId: "match_win_\(matchId)"
        )
        
        // Step 3: Update match status
        try await updateMatchStatus(
            matchId: matchId,
            status: .completed,
            winnerId: winnerId
        )
        
        // Step 4: Save verification record
        let verification = MatchVerification(
            id: matchId,
            matchId: matchId,
            status: .completed,
            winnerId: winnerId,
            submissions: [submission1.id, submission2.id],
            autoApproved: autoApproved,
            confidence: min(submission1.aiAnalysis.confidence, submission2.aiAnalysis.confidence),
            verifiedAt: Date(),
            requiresReview: false,
            reviewedBy: nil,
            reviewNote: nil
        )
        
        try await saveVerification(verification)
        
        // Step 5: Send notifications
        await sendVerificationNotification(
            winnerId: winnerId,
            loserId: loserId,
            payout: winnerPayout
        )
        
        return VerificationResult(
            status: .completed,
            winnerId: winnerId,
            confidence: verification.confidence,
            requiresReview: false
        )
    }
    
    // MARK: - Flag for Review
    
    /// Flag match for human referee review
    /// - Parameters:
    ///   - matchId: Match identifier
    ///   - submission1: First player's submission
    ///   - submission2: Second player's submission
    ///   - reason: Reason for review
    /// - Returns: Verification result
    private func flagForReview(
        matchId: String,
        submission1: MatchSubmission,
        submission2: MatchSubmission,
        reason: String
    ) async throws -> VerificationResult {
        print("🚩 [MatchVerification] Flagging match for review: \(reason)")
        
        // Save verification record with pending review status
        let verification = MatchVerification(
            id: matchId,
            matchId: matchId,
            status: .disputed,
            winnerId: nil,
            submissions: [submission1.id, submission2.id],
            autoApproved: false,
            confidence: min(submission1.aiAnalysis.confidence, submission2.aiAnalysis.confidence),
            verifiedAt: Date(),
            requiresReview: true,
            reviewedBy: nil,
            reviewNote: reason
        )
        
        try await saveVerification(verification)
        
        // Notify admins
        await notifyAdminsForReview(matchId: matchId, reason: reason)
        
        return VerificationResult(
            status: .disputed,
            winnerId: nil,
            confidence: verification.confidence,
            requiresReview: true
        )
    }
    
    // MARK: - Manual Approval (Referee)
    
    /// Manually approve match after referee review
    /// - Parameters:
    ///   - matchId: Match identifier
    ///   - winnerId: Winner player ID
    ///   - refereeId: Referee user ID
    ///   - note: Review note
    func manuallyApproveMatch(
        matchId: String,
        winnerId: String,
        refereeId: String,
        note: String
    ) async throws {
        print("👨‍⚖️ [MatchVerification] Manual approval by referee: \(refereeId)")
        
        // Get submissions
        let submissions = try await getSubmissions(matchId: matchId)
        guard submissions.count == 2 else {
            throw VerificationError.insufficientSubmissions
        }
        
        // Get match
        let match = try await getMatch(matchId: matchId)
        
        // Calculate loserId (opponent of winner)
        let loserId: String
        if match.challengerId == winnerId {
            loserId = match.opponentId
        } else {
            loserId = match.challengerId
        }
        
        // Calculate payout
        let totalWager = match.wagerAmount * 2
        let platformFee = totalWager * 0.1
        let winnerPayout = totalWager - platformFee
        
        // Release escrow
        try await escrowService.releaseFunds(
            matchId: matchId,
            winnerId: winnerId,
            loserId: loserId,
            amount: winnerPayout
        )
        
        // Update wallet
        try await walletService.depositFunds(
            userId: winnerId,
            amount: winnerPayout,
            paymentMethodId: "match_win_\(matchId)"
        )
        
        // Update match status
        try await updateMatchStatus(
            matchId: matchId,
            status: .completed,
            winnerId: winnerId
        )
        
        // Update verification record
        try await db
            .collection("match_verifications")
            .document(matchId)
            .updateData([
                "status": "verified",
                "winnerId": winnerId,
                "requiresReview": false,
                "reviewedBy": refereeId,
                "reviewNote": note,
                "reviewedAt": FieldValue.serverTimestamp()
            ])
        
        print("✅ [MatchVerification] Match manually approved")
    }
    
    // MARK: - Helper Methods
    
    /// Save submission to Firestore
    private func saveSubmission(_ submission: MatchSubmission) async throws {
        let data: [String: Any] = [
            "matchId": submission.matchId,
            "playerId": submission.playerId,
            "videoURL": submission.videoURL,
            "screenshotURL": submission.screenshotURL as Any,
            "selfReportedScore": submission.selfReportedScore,
            "opponentScore": submission.opponentScore,
            "submittedAt": Timestamp(date: submission.submittedAt),
            "aiAnalysis": [
                "confidence": submission.aiAnalysis.confidence,
                "extractedScore": submission.aiAnalysis.extractedScore as Any,
                "scoreboardDetected": submission.aiAnalysis.scoreboardDetected,
                "analyzedAt": Timestamp(date: submission.aiAnalysis.analyzedAt)
            ],
            "status": submission.status.rawValue
        ]
        
        try await db
            .collection("match_submissions")
            .document(submission.id)
            .setData(data)
    }
    
    /// Get submissions for a match
    private func getSubmissions(matchId: String) async throws -> [MatchSubmission] {
        let snapshot = try await db
            .collection("match_submissions")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> MatchSubmission? in
            let data = doc.data()
            guard let playerId = data["playerId"] as? String,
                  let videoURL = data["videoURL"] as? String,
                  let selfReportedScore = data["selfReportedScore"] as? Int,
                  let opponentScore = data["opponentScore"] as? Int,
                  let submittedAt = (data["submittedAt"] as? Timestamp)?.dateValue(),
                  let aiData = data["aiAnalysis"] as? [String: Any],
                  let confidence = aiData["confidence"] as? Double,
                  let scoreboardDetected = aiData["scoreboardDetected"] as? Bool,
                  let analyzedAt = (aiData["analyzedAt"] as? Timestamp)?.dateValue(),
                  let statusStr = data["status"] as? String else {
                return nil
            }
            
            let screenshotURL = data["screenshotURL"] as? String
            let extractedScore = aiData["extractedScore"] as? Int
            let status = SubmissionStatus(rawValue: statusStr) ?? .pending
            
            return MatchSubmission(
                id: doc.documentID,
                matchId: matchId,
                playerId: playerId,
                videoURL: videoURL,
                screenshotURL: screenshotURL,
                selfReportedScore: selfReportedScore,
                opponentScore: opponentScore,
                submittedAt: submittedAt,
                aiAnalysis: AIAnalysis(
                    confidence: confidence,
                    extractedScore: extractedScore,
                    scoreboardDetected: scoreboardDetected,
                    analyzedAt: analyzedAt
                ),
                status: status
            )
        }
    }
    
    /// Check if opponent has submitted
    private func checkOpponentSubmission(matchId: String, playerId: String) async throws -> Bool {
        let snapshot = try await db
            .collection("match_submissions")
            .whereField("matchId", isEqualTo: matchId)
            .getDocuments()
        
        let submissions = snapshot.documents.filter { doc in
            let data = doc.data()
            return (data["playerId"] as? String) != playerId
        }
        
        return !submissions.isEmpty
    }
    
    /// Save verification record
    private func saveVerification(_ verification: MatchVerification) async throws {
        let data: [String: Any] = [
            "matchId": verification.matchId,
            "status": verification.status.rawValue,
            "winnerId": verification.winnerId as Any,
            "submissions": verification.submissions,
            "autoApproved": verification.autoApproved,
            "confidence": verification.confidence,
            "verifiedAt": Timestamp(date: verification.verifiedAt),
            "requiresReview": verification.requiresReview,
            "reviewedBy": verification.reviewedBy as Any,
            "reviewNote": verification.reviewNote as Any
        ]
        
        try await db
            .collection("match_verifications")
            .document(verification.id)
            .setData(data)
    }
    
    /// Get match details
    private func getMatch(matchId: String) async throws -> VersusMatch {
        // TODO: Get from VersusMatchService
        // For now, return mock data
        return VersusMatch(
            id: matchId,
            challengerId: "player1",
            opponentId: "player2",
            matchType: .headToHead,
            wagerAmount: 100.0,
            category: .gaming,
            rules: VersusMatch.MatchRules(
                duration: 3600,
                category: .gaming,
                winCondition: .mostViews
            ),
            status: .live,
            winnerId: nil,
            createdAt: Date(),
            scheduledDate: Date(),
            startedAt: Date(),
            completedAt: nil,
            finalStats: nil
        )
    }
    
    /// Update match status
    private func updateMatchStatus(matchId: String, status: MatchStatus, winnerId: String?) async throws {
        var data: [String: Any] = [
            "status": status.rawValue,
            "completedAt": FieldValue.serverTimestamp()
        ]
        
        if let winnerId = winnerId {
            data["winnerId"] = winnerId
        }
        
        try await db
            .collection("versus_matches")
            .document(matchId)
            .updateData(data)
    }
    
    /// Send verification notifications
    private func sendVerificationNotification(winnerId: String, loserId: String, payout: Double) async {
        // TODO: Send push notifications
        print("📱 [MatchVerification] Sending notifications...")
        print("   Winner (\(winnerId)): You won $\(payout)!")
        print("   Loser (\(loserId)): Better luck next time!")
    }
    
    /// Notify admins for review
    private func notifyAdminsForReview(matchId: String, reason: String) async {
        // TODO: Send admin notification
        print("📢 [MatchVerification] Notifying admins: Match \(matchId) needs review - \(reason)")
    }
    
    /// Simulate video analysis (for testing)
    private func simulateVideoAnalysis(videoURL: String, expectedScore: Int) async throws -> VideoAnalysisResult {
        // Simulate AI processing delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return VideoAnalysisResult(
            extractedScores: ExtractedScores(
                player1Score: expectedScore,
                player2Score: nil,
                scoreboardDetected: true,
                scoreboardTimestamp: 90.0,
                ocrText: "Score: \(expectedScore)"
            ),
            confidence: 0.95,
            keyFrames: [],
            detectedGame: "FIFA 24",
            scoreboardDetected: true,
            timestamp: Date()
        )
    }
}

// MARK: - Models

struct MatchSubmission {
    let id: String
    let matchId: String
    let playerId: String
    let videoURL: String
    let screenshotURL: String?
    let selfReportedScore: Int
    let opponentScore: Int
    let submittedAt: Date
    let aiAnalysis: AIAnalysis
    let status: SubmissionStatus
}

struct AIAnalysis {
    let confidence: Double
    let extractedScore: Int?
    let scoreboardDetected: Bool
    let analyzedAt: Date
}

enum SubmissionStatus: String {
    case pending = "pending"
    case verified = "verified"
    case disputed = "disputed"
}

struct MatchVerification {
    let id: String
    let matchId: String
    let status: MatchStatus
    let winnerId: String?
    let submissions: [String]
    let autoApproved: Bool
    let confidence: Double
    let verifiedAt: Date
    let requiresReview: Bool
    let reviewedBy: String?
    let reviewNote: String?
}

enum VerificationMatchStatus: String {
    case pending = "pending"
    case inProgress = "in_progress"
    case verified = "verified"
    case disputed = "disputed"
    case complete = "complete"
    case cancelled = "cancelled"
}

struct SubmissionResult {
    let success: Bool
    let submissionId: String
    let awaitingOpponent: Bool
}

struct VerificationResult {
    let status: MatchStatus
    let winnerId: String?
    let confidence: Double
    let requiresReview: Bool
}

// MARK: - Verification Error

enum VerificationError: LocalizedError {
    case insufficientSubmissions
    case tiedScores
    case invalidSubmission
    case matchNotFound
    
    var errorDescription: String? {
        switch self {
        case .insufficientSubmissions:
            return "Both players must submit proof before verification."
        case .tiedScores:
            return "Cannot determine winner - scores are tied."
        case .invalidSubmission:
            return "Invalid submission data."
        case .matchNotFound:
            return "Match not found."
        }
    }
}

// MARK: - Mock removed - using real VersusMatch from VersusMatchModels.swift

