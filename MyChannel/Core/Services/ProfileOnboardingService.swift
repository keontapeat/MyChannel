//
//  ProfileOnboardingService.swift
//  MyChannel
//
//  Phase 255: Profile Onboarding & Setup Wizard.
//  Guided profile setup, completeness score, suggested actions,
//  template profiles, first-time creator flow.
//  Uses `creator-relations-ai` Cloud Run.
//

import Foundation

// MARK: - Models

struct ProfileCompleteness: Codable {
    let creatorId: String
    let score: Double
    let missing: [MissingItem]
    let suggestedActions: [SuggestedAction]

    struct MissingItem: Codable {
        let field: String
        let importance: String
        let label: String
    }

    struct SuggestedAction: Codable, Identifiable {
        let id: String
        let action: String
        let description: String
        let priority: Int
    }
}

struct ProfileTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let previewImageURL: String?
    let presetBio: String?
    let presetTheme: String?
}

struct ProfileOnboardingStep: Codable, Identifiable {
    let id: String
    let step: Int
    let title: String
    let description: String
    let isComplete: Bool
    let required: Bool
}

// MARK: - Service

@MainActor
final class ProfileOnboardingService: ObservableObject {
    static let shared = ProfileOnboardingService()
    private init() {}

    @Published private(set) var completeness: ProfileCompleteness?
    @Published private(set) var templates: [ProfileTemplate] = []
    @Published private(set) var steps: [ProfileOnboardingStep] = []

    func fetchCompleteness(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileOnboarding else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawMissing: Decodable { let field: String; let importance: String; let label: String }
        struct RawAction: Decodable { let id: String; let action: String; let desc: String; let priority: Int }
        struct Raw: Decodable { let score: Double?; let missing: [RawMissing]?; let actions: [RawAction]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "fetch_completeness", creatorId: creatorId)
        )
        completeness = ProfileCompleteness(creatorId: creatorId, score: r.score ?? 0,
                                             missing: (r.missing ?? []).map { ProfileCompleteness.MissingItem(field: $0.field, importance: $0.importance, label: $0.label) },
                                             suggestedActions: (r.actions ?? []).map { ProfileCompleteness.SuggestedAction(id: $0.id, action: $0.action, description: $0.desc, priority: $0.priority) })
    }

    func fetchTemplates(category: String? = nil) async throws {
        guard AppConfig.Features.enableProfileOnboarding else { return }
        struct Req: Encodable { let task: String; let category: String? }
        struct RawT: Decodable { let id: String; let name: String; let category: String; let preview: String?; let bio: String?; let theme: String? }
        struct Raw: Decodable { let templates: [RawT]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "fetch_profile_templates", category: category)
        )
        templates = (r.templates ?? []).map {
            ProfileTemplate(id: $0.id, name: $0.name, category: $0.category, previewImageURL: $0.preview,
                            presetBio: $0.bio, presetTheme: $0.theme)
        }
    }

    func fetchOnboardingSteps(creatorId: String) async throws {
        guard AppConfig.Features.enableProfileOnboarding else { return }
        struct Req: Encodable { let task: String; let creatorId: String }
        struct RawS: Decodable { let id: String; let step: Int; let title: String; let desc: String; let complete: Bool; let required: Bool }
        struct Raw: Decodable { let steps: [RawS]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "fetch_onboarding_steps", creatorId: creatorId)
        )
        steps = (r.steps ?? []).map {
            ProfileOnboardingStep(id: $0.id, step: $0.step, title: $0.title, description: $0.desc, isComplete: $0.complete, required: $0.required)
        }
    }

    func completeStep(stepId: String) async throws {
        guard AppConfig.Features.enableProfileOnboarding else { return }
        struct Req: Encodable { let task: String; let stepId: String }
        struct Raw: Decodable { let ok: Bool? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .creatorRelationsAI, path: "/predict",
            body: Req(task: "complete_onboarding_step", stepId: stepId)
        )
        if let idx = steps.firstIndex(where: { $0.id == stepId }) {
            let old = steps[idx]
            steps[idx] = ProfileOnboardingStep(id: old.id, step: old.step, title: old.title, description: old.description, isComplete: true, required: old.required)
        }
    }
}
