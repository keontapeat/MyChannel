//
//  SmartBriefingService.swift
//  MyChannel
//
//  Phase 888: Smart Owner Briefing Engine
//  Personalized AI briefing with Gemini, action items, priority ranking
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class SmartBriefingService: ObservableObject {
    static let shared = SmartBriefingService()

    // MARK: - Domain Models

    struct Briefing: Identifiable, Codable {
        let id: String
        let generatedAt: Date
        let summary: String
        let actionItems: [ActionItem]
        let priorityInsights: [PriorityInsight]
        let trendNarrative: String
        let competitorComparison: String?
        let overallHealth: Double
        let urgencyLevel: UrgencyLevel
    }

    struct ActionItem: Identifiable, Codable {
        let id: String
        let title: String
        let detail: String
        let priority: String
        let department: String
        let deadline: String
        let businessImpact: String
    }

    struct PriorityInsight: Identifiable, Codable {
        let id: String
        let metric: String
        let currentValue: String
        let trend: String
        let recommendation: String
        let impact: String
    }

    enum UrgencyLevel: String, Codable {
        case critical = "CRITICAL"
        case high = "HIGH"
        case normal = "NORMAL"
        case low = "LOW"
    }

    struct BriefingArchive: Identifiable, Codable {
        let id: String
        let date: Date
        let healthScore: Double
        let actionCount: Int
        let summary: String
    }

    // MARK: - Published State

    @Published private(set) var currentBriefing: Briefing?
    @Published private(set) var briefingArchive: [BriefingArchive] = []
    @Published private(set) var isGenerating = false
    @Published private(set) var lastGeneratedAt: Date?

    private var db = Firestore.firestore()

    private init() {}

    // MARK: - Cloud Run Integration

    private let cloudRunBase = "https://smart-briefing-fkri6ifojq-uc.a.run.app"

    // MARK: - Generate Briefing

    func generateBriefing(platformStats: [String: Any]) async {
        guard AppConfig.Features.enableSmartBriefing else { return }
        isGenerating = true
        defer { isGenerating = false }

        // Call Cloud Run for ML-augmented briefing data
        var mlInsights: [String: Any] = [:]
        if let result = await callCloudRun(endpoint: "insights", body: platformStats) {
            mlInsights = result
        }

        // Build Gemini prompt with ML insights
        let prompt = buildPrompt(stats: platformStats, insights: mlInsights)
        let briefingText = await callGemini(prompt: prompt)

        if let text = briefingText {
            let briefing = parseBriefing(text, mlInsights: mlInsights)
            currentBriefing = briefing
            lastGeneratedAt = Date()

            // Archive
            try? await db.collection("briefingArchive").addDocument(data: [
                "date": Timestamp(date: Date()),
                "healthScore": briefing.overallHealth,
                "actionCount": briefing.actionItems.count,
                "summary": String(briefing.summary.prefix(200))
            ])
            await loadArchive()
        }
    }

    // MARK: - Archive

    func loadArchive() async {
        let snap = try? await db.collection("briefingArchive")
            .order(by: "date", descending: true)
            .limit(to: 30)
            .getDocuments()
        briefingArchive = snap?.documents.compactMap { doc in
            let d = doc.data()
            return BriefingArchive(
                id: doc.documentID,
                date: (d["date"] as? Timestamp)?.dateValue() ?? Date(),
                healthScore: d["healthScore"] as? Double ?? 0,
                actionCount: d["actionCount"] as? Int ?? 0,
                summary: d["summary"] as? String ?? ""
            )
        } ?? []
    }

    // MARK: - Cloud Run Call

    private func callCloudRun(endpoint: String, body: [String: Any]? = nil) async -> [String: Any]? {
        guard let url = URL(string: "\(cloudRunBase)/\(endpoint)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        request.timeoutInterval = 30
        do {
            let (data, _) = try await URLSession.configured.data(for: request)
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch { return nil }
    }

    // MARK: - Gemini Call

    private func callGemini(prompt: String) async -> String? {
        let key = AppSecrets.googleCloudAPIKey
        guard !key.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=\(key)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["maxOutputTokens": 800, "temperature": 0.4]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.configured.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        return nil
    }

    // MARK: - Prompt Builder

    private func buildPrompt(stats: [String: Any], insights: [String: Any]) -> String {
        """
        You are the Chief AI Officer for MyChannel. Generate a CEO-level daily briefing for the owner (Keonta).

        PLATFORM STATS:
        \(stats.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))

        ML INSIGHTS:
        \(insights.isEmpty ? "No additional ML insights" : insights.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))

        Format your response EXACTLY as:
        SUMMARY: [2-3 sentence executive summary]
        URGENCY: [CRITICAL/HIGH/NORMAL/LOW]
        HEALTH: [0-100 score]
        ACTION: [title] | [detail] | [CRITICAL/HIGH/MEDIUM/LOW] | [department] | [deadline] | [business impact]
        ACTION: [repeat for each action item, 3-5 total]
        INSIGHT: [metric] | [current value] | [trend] | [recommendation] | [impact]
        INSIGHT: [repeat, 3-5 total]
        NARRATIVE: [2-3 sentence trend narrative comparing to last week]
        COMPETITOR: [1-2 sentence competitive comparison if data available]

        Be data-driven, concise, and action-oriented. Use $ and % where relevant.
        """
    }

    // MARK: - Parse

    private func parseBriefing(_ text: String, mlInsights: [String: Any]) -> Briefing {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var summary = "", narrative = "", competitor: String?
        var actions: [ActionItem] = [], insights: [PriorityInsight] = []
        var urgency = UrgencyLevel.normal, health = 75.0

        for line in lines {
            if line.hasPrefix("SUMMARY:") { summary = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces) }
            else if line.hasPrefix("URGENCY:") { urgency = UrgencyLevel(rawValue: String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)) ?? .normal }
            else if line.hasPrefix("HEALTH:") { health = Double(String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)) ?? 75.0 }
            else if line.hasPrefix("ACTION:") {
                let parts = String(line.dropFirst(7)).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 2 {
                    actions.append(ActionItem(
                        id: UUID().uuidString, title: parts[0], detail: parts.count > 1 ? parts[1] : "",
                        priority: parts.count > 2 ? parts[2] : "MEDIUM",
                        department: parts.count > 3 ? parts[3] : "Operations",
                        deadline: parts.count > 4 ? parts[4] : "EOD",
                        businessImpact: parts.count > 5 ? parts[5] : ""
                    ))
                }
            }
            else if line.hasPrefix("INSIGHT:") {
                let parts = String(line.dropFirst(8)).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 2 {
                    insights.append(PriorityInsight(
                        id: UUID().uuidString, metric: parts[0], currentValue: parts.count > 1 ? parts[1] : "",
                        trend: parts.count > 2 ? parts[2] : "stable",
                        recommendation: parts.count > 3 ? parts[3] : "",
                        impact: parts.count > 4 ? parts[4] : ""
                    ))
                }
            }
            else if line.hasPrefix("NARRATIVE:") { narrative = String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces) }
            else if line.hasPrefix("COMPETITOR:") { competitor = String(line.dropFirst(11)).trimmingCharacters(in: .whitespaces) }
        }

        return Briefing(
            id: UUID().uuidString, generatedAt: Date(), summary: summary,
            actionItems: actions, priorityInsights: insights,
            trendNarrative: narrative, competitorComparison: competitor,
            overallHealth: health, urgencyLevel: urgency
        )
    }
}
