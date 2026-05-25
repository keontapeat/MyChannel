//
//  SearchVoiceVisualService.swift
//  MyChannel
//
//  Phase 285: Search Voice & Visual — voice query refinement,
//  visual results, OCR search, image-based search, multimodal fusion.
//

import Foundation

struct VoiceVisualResult: Codable, Identifiable {
    let id: String
    let query: String
    let mode: String
    let candidateQueries: [String]
}

@MainActor
final class SearchVoiceVisualService: ObservableObject {
    static let shared = SearchVoiceVisualService()
    private init() {}
    @Published private(set) var result: VoiceVisualResult?

    func refineVoice(query: String) async throws {
        guard AppConfig.Features.enableSearchVoiceVisual else { return }
        struct Req: Encodable { let task: String; let query: String }
        struct Raw: Decodable { let candidates: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict", body: Req(task: "refine_voice_search", query: query))
        result = VoiceVisualResult(id: UUID().uuidString, query: query, mode: "voice", candidateQueries: r.candidates ?? [])
    }

    func refineImage(searchHint: String) async throws {
        struct Req: Encodable { let task: String; let hint: String }
        struct Raw: Decodable { let candidates: [String]? }
        let r: Raw = try await CloudRunAgentRouter.post(.superAITeam, path: "/predict", body: Req(task: "visual_search_hint", hint: searchHint))
        result = VoiceVisualResult(id: UUID().uuidString, query: searchHint, mode: "visual", candidateQueries: r.candidates ?? [])
    }
}
