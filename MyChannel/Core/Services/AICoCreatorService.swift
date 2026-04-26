//
//  AICoCreatorService.swift
//  MyChannel
//
//  Phase 191: AI Co-Creator Studio.
//  Script writing, storyboard gen, voice cloning.
//  Uses `super-ai-team` Cloud Run.
//

import Foundation

// MARK: - Models

struct GeneratedScript: Codable, Identifiable {
    let id: String
    let title: String
    let sections: [CoCreatorScriptSection]
    let estimatedDurationMin: Int
    let tone: String
}

struct CoCreatorScriptSection: Codable, Identifiable {
    let id: String
    let heading: String
    let body: String
    let durationSec: Int
    let visualNotes: String
}

struct Storyboard: Codable, Identifiable {
    let id: String
    let frames: [StoryboardFrame]
}

struct StoryboardFrame: Codable, Identifiable {
    let id: String
    let imageURL: URL?
    let description: String
    let durationSec: Int
    let cameraAngle: String
}

struct CoCreatorVoiceClone: Codable, Identifiable {
    let id: String
    let name: String
    let sampleURL: URL?
    let language: String
    let status: String
}

// MARK: - Service

@MainActor
final class AICoCreatorService: ObservableObject {
    static let shared = AICoCreatorService()
    private init() {}

    @Published private(set) var script: GeneratedScript?
    @Published private(set) var storyboard: Storyboard?
    @Published private(set) var voiceClones: [CoCreatorVoiceClone] = []
    @Published var isGenerating: Bool = false

    func generateScript(topic: String, tone: String, durationMin: Int) async throws {
        guard AppConfig.Features.enableAICoCreator else { return }
        isGenerating = true; defer { isGenerating = false }
        struct Request: Encodable { let task: String; let topic: String; let tone: String; let duration: Int }
        struct RawSection: Decodable { let heading: String; let body: String; let duration: Int; let visual: String }
        struct Raw: Decodable { let title: String?; let sections: [RawSection]?; let duration: Int? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "generate_script", topic: topic, tone: tone, duration: durationMin), timeout: 60
        )
        script = GeneratedScript(
            id: UUID().uuidString, title: r.title ?? topic,
            sections: (r.sections ?? []).map {
                CoCreatorScriptSection(id: UUID().uuidString, heading: $0.heading, body: $0.body, durationSec: $0.duration, visualNotes: $0.visual)
            },
            estimatedDurationMin: r.duration ?? durationMin, tone: tone
        )
    }

    func generateStoryboard(scriptId: String) async throws {
        guard AppConfig.Features.enableAICoCreator else { return }
        isGenerating = true; defer { isGenerating = false }
        struct Request: Encodable { let task: String; let scriptId: String }
        struct RawFrame: Decodable { let image: String?; let desc: String; let duration: Int; let angle: String }
        struct Raw: Decodable { let frames: [RawFrame]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "generate_storyboard", scriptId: scriptId), timeout: 60
        )
        storyboard = Storyboard(id: UUID().uuidString, frames: (r.frames ?? []).map {
            StoryboardFrame(id: UUID().uuidString, imageURL: $0.image.flatMap(URL.init(string:)),
                          description: $0.desc, durationSec: $0.duration, cameraAngle: $0.angle)
        })
    }

    func cloneVoice(name: String, sampleURL: URL) async throws -> String {
        guard AppConfig.Features.enableAICoCreator else { return "" }
        struct Request: Encodable { let task: String; let name: String; let sample: String }
        struct Raw: Decodable { let clone_id: String? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam, path: "/predict",
            body: Request(task: "clone_voice", name: name, sample: sampleURL.absoluteString), timeout: 120
        )
        return r.clone_id ?? ""
    }
}
