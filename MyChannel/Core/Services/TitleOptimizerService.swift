//
//  TitleOptimizerService.swift
//  MyChannel
//
//  Phase 6: SEO title + description optimizer for Creator Studio.
//  Wires title-optimizer + description-writer Cloud Run services.
//

import Foundation

struct TitleSuggestion: Identifiable, Codable {
    let id: String
    let title: String
    let predictedCTR: Double
    let seoScore: Double

    init(id: String = UUID().uuidString, title: String, predictedCTR: Double = 0, seoScore: Double = 0) {
        self.id = id; self.title = title; self.predictedCTR = predictedCTR; self.seoScore = seoScore
    }
}

struct DescriptionSuggestion: Codable {
    let description: String
    let tags: [String]
    let seoScore: Double
}

@MainActor
final class TitleOptimizerService: ObservableObject {
    static let shared = TitleOptimizerService()
    private init() {}

    @Published var isOptimizing: Bool = false

    func suggestTitles(currentTitle: String, description: String,
                       tags: [String], count: Int = 5) async -> [TitleSuggestion] {
        isOptimizing = true
        defer { isOptimizing = false }

        struct Req: Encodable {
            let title: String; let description: String; let tags: [String]; let count: Int
        }
        struct RawSuggestion: Decodable {
            let title: String?; let predicted_ctr: Double?; let seo_score: Double?
        }
        struct Resp: Decodable { let suggestions: [RawSuggestion]? }

        do {
            let raw: Resp = try await CloudRunAgentRouter.post(
                .titleOptimizer, path: "/predict",
                body: Req(title: currentTitle, description: description, tags: tags, count: count),
                timeout: 20
            )
            return (raw.suggestions ?? []).compactMap { s in
                guard let t = s.title, !t.isEmpty else { return nil }
                return TitleSuggestion(title: t, predictedCTR: s.predicted_ctr ?? 0, seoScore: s.seo_score ?? 0)
            }
        } catch { return [] }
    }

    func suggestDescription(title: String, currentDescription: String,
                            tags: [String]) async -> DescriptionSuggestion? {
        isOptimizing = true
        defer { isOptimizing = false }

        struct Req: Encodable {
            let title: String; let description: String; let tags: [String]
        }
        struct Resp: Decodable {
            let description: String?; let suggested_tags: [String]?; let seo_score: Double?
        }

        do {
            let raw: Resp = try await CloudRunAgentRouter.post(
                .descriptionWriter, path: "/predict",
                body: Req(title: title, description: currentDescription, tags: tags),
                timeout: 20
            )
            return DescriptionSuggestion(
                description: raw.description ?? currentDescription,
                tags: raw.suggested_tags ?? tags,
                seoScore: raw.seo_score ?? 0
            )
        } catch { return nil }
    }
}
