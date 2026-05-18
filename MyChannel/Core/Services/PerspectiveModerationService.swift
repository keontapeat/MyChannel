import Alamofire
import Foundation

/// Real-time toxicity scoring via Google Perspective API + OpenAI Moderation.
/// Auto-scores every flagged item in 3-Strike Review before it reaches the human queue.
@MainActor
final class PerspectiveModerationService: ObservableObject {
    static let shared = PerspectiveModerationService()

    @Published var isAnalyzing = false

    private let perspectiveURL = "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze"

    struct ToxicityReport: Identifiable {
        let id = UUID()
        let text: String
        let toxicityScore: Double          // 0.0 – 1.0
        let severeToxicityScore: Double
        let threatScore: Double
        let insultScore: Double
        let identityAttackScore: Double
        let profanityScore: Double
        let openAIFlagged: Bool
        let openAITopCategory: String?
        let recommendation: Recommendation
        let analyzedAt: Date

        enum Recommendation: String {
            case looksFine        = "Looks Fine"
            case reviewSuggested  = "Worth Reviewing"
            case autoStrike       = "Auto-Strike"        // clear violation — strike issued, you notified
            case ownerReviewBan   = "🚨 Awaiting Your Ban Approval"  // 3 strikes hit — YOU decide ban
        }
    }

    private init() {}

    // MARK: - Analyze text (Perspective + OpenAI combined)

    func analyze(text: String, userId: String) async -> ToxicityReport {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // OpenAI Moderation is always available — use as primary
        let openAI = (try? await OpenAIAgentService.shared.moderateContent(text))
            ?? OpenAIModerationResult(flagged: false, categories: [:], scores: [:])

        // Perspective is optional — fire concurrently, use if it returns data
        let perspective = await callPerspective(text: text)

        // Blend: Perspective wins if it responded, otherwise fall back to OpenAI scores
        let scores: PerspectiveScores = perspective.toxicity > 0 ? perspective : PerspectiveScores(
            toxicity: openAI.maxScore,
            severeToxicity: openAI.scores["hate"] ?? 0,
            threat: openAI.scores["violence"] ?? 0,
            insult: openAI.scores["harassment"] ?? 0,
            identityAttack: openAI.scores["hate"] ?? 0,
            profanity: openAI.scores["sexual"] ?? 0
        )

        let toxicity = scores.toxicity
        let recommendation = computeRecommendation(toxicity: toxicity, openAIFlagged: openAI.flagged, openAIMaxScore: openAI.maxScore)

        AgentLogService.shared.strikeIssued(
            userId: userId,
            strikeCount: 0,
            reason: "toxicity_score_\(String(format: "%.2f", toxicity))",
            toxicityScore: toxicity
        )

        return ToxicityReport(
            text: text,
            toxicityScore: toxicity,
            severeToxicityScore: scores.severeToxicity,
            threatScore: scores.threat,
            insultScore: scores.insult,
            identityAttackScore: scores.identityAttack,
            profanityScore: scores.profanity,
            openAIFlagged: openAI.flagged,
            openAITopCategory: openAI.topCategory,
            recommendation: recommendation,
            analyzedAt: Date()
        )
    }

    // MARK: - Batch analyze (for Command Center bulk review)

    func analyzeBatch(items: [(text: String, userId: String)]) async -> [ToxicityReport] {
        var results: [ToxicityReport] = []
        for item in items {
            let report = await analyze(text: item.text, userId: item.userId)
            results.append(report)
        }
        return results
    }

    // MARK: - Recommendation logic

    private func computeRecommendation(toxicity: Double, openAIFlagged: Bool, openAIMaxScore: Double) -> ToxicityReport.Recommendation {
        let combined = max(toxicity, openAIMaxScore)
        switch combined {
        case 0..<0.4:
            return .looksFine
        case 0.4..<0.7:
            return .reviewSuggested
        default:
            // 0.7+ = porn, extreme violence, hate — auto-strike
            // Ban is NEVER automatic — owner reviews after 3 strikes
            return openAIFlagged ? .autoStrike : .reviewSuggested
        }
    }

    /// Call this to check if a user has hit 3 strikes and needs ban review
    func checkForBanReview(userId: String, currentStrikeCount: Int) -> ToxicityReport.Recommendation? {
        guard currentStrikeCount >= 3 else { return nil }
        return .ownerReviewBan
    }

    // MARK: - Perspective API call

    private struct PerspectiveScores {
        var toxicity: Double = 0
        var severeToxicity: Double = 0
        var threat: Double = 0
        var insult: Double = 0
        var identityAttack: Double = 0
        var profanity: Double = 0
    }

    private func callPerspective(text: String) async -> PerspectiveScores {
        let apiKey = AppSecrets.googleCloudAPIKey
        guard !apiKey.isEmpty else { return PerspectiveScores() }

        let payload: [String: Any] = [
            "comment": ["text": text],
            "languages": ["en"],
            "requestedAttributes": [
                "TOXICITY": [:],
                "SEVERE_TOXICITY": [:],
                "THREAT": [:],
                "INSULT": [:],
                "IDENTITY_ATTACK": [:],
                "PROFANITY": [:]
            ]
        ]

        return await withCheckedContinuation { cont in
            AF.request("\(perspectiveURL)?key=\(apiKey)",
                       method: .post,
                       parameters: payload,
                       encoding: JSONEncoding.default)
            .validate()
            .responseJSON { response in
                guard let json = try? response.result.get() as? [String: Any],
                      let attrs = json["attributeScores"] as? [String: Any] else {
                    cont.resume(returning: PerspectiveScores())
                    return
                }
                func score(_ key: String) -> Double {
                    (attrs[key] as? [String: Any])?["summaryScore"] as? [String: Any]
                    != nil
                    ? ((attrs[key] as? [String: Any])?["summaryScore"] as? [String: Any])?["value"] as? Double ?? 0
                    : 0
                }
                cont.resume(returning: PerspectiveScores(
                    toxicity: score("TOXICITY"),
                    severeToxicity: score("SEVERE_TOXICITY"),
                    threat: score("THREAT"),
                    insult: score("INSULT"),
                    identityAttack: score("IDENTITY_ATTACK"),
                    profanity: score("PROFANITY")
                ))
            }
        }
    }
}
