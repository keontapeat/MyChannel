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
            case autoApprove  = "Auto-Approve"
            case sendToReview = "Send to Review"
            case autoStrike   = "Auto-Strike"
            case autoBan      = "Auto-Ban"
        }
    }

    private init() {}

    // MARK: - Analyze text (Perspective + OpenAI combined)

    func analyze(text: String, userId: String) async -> ToxicityReport {
        isAnalyzing = true
        defer { isAnalyzing = false }

        async let perspectiveResult = callPerspective(text: text)
        async let openAIResult = OpenAIAgentService.shared.moderateContent(text)

        let (pScore, oResult) = await (perspectiveResult, (try? openAIResult) ?? ModerationResult(flagged: false, categories: [:], scores: [:]))

        let toxicity = pScore.toxicity
        let recommendation = computeRecommendation(toxicity: toxicity, openAIFlagged: oResult.flagged, openAIMaxScore: oResult.maxScore)

        AgentLogService.shared.strikeIssued(
            userId: userId,
            strikeCount: 0,
            reason: "toxicity_score_\(String(format: "%.2f", toxicity))",
            toxicityScore: toxicity
        )

        return ToxicityReport(
            text: text,
            toxicityScore: toxicity,
            severeToxicityScore: pScore.severeToxicity,
            threatScore: pScore.threat,
            insultScore: pScore.insult,
            identityAttackScore: pScore.identityAttack,
            profanityScore: pScore.profanity,
            openAIFlagged: oResult.flagged,
            openAITopCategory: oResult.topCategory,
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
        case 0..<0.3:
            return .autoApprove
        case 0.3..<0.6:
            return .sendToReview
        case 0.6..<0.85:
            return openAIFlagged ? .autoStrike : .sendToReview
        default:
            return .autoBan
        }
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
