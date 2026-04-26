//
//  AutomationRecipesService.swift
//  MyChannel
//
//  Phase 105: Automation Recipes.
//  No-code trigger/action builder ("new upload → cross-post + clip").
//  Template library, event-driven execution via `mychannel-events` Cloud Run.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Models

struct AutomationRecipe: Codable, Identifiable, Equatable {
    let id: String
    let creatorUid: String
    let name: String
    let trigger: RecipeTrigger
    let actions: [RecipeAction]
    let enabled: Bool
    let runCount: Int
    let lastRunAt: Date?
    let createdAt: Date
}

enum RecipeTrigger: String, Codable, CaseIterable {
    case onUpload, onPublish, onMilestone, onNewSubscriber, onSchedule, onLiveStart, onLiveEnd
}

struct RecipeAction: Codable, Equatable {
    let type: ActionType
    let config: [String: String]

    enum ActionType: String, Codable, CaseIterable {
        case crossPost, generateClip, sendNotification, addToPlaylist, applyThumbnail, postCommunity, webhook
    }
}

struct RecipeTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let trigger: RecipeTrigger
    let actions: [RecipeAction]
    let popularity: Int
}

// MARK: - Service

@MainActor
final class AutomationRecipesService: ObservableObject {
    static let shared = AutomationRecipesService()
    private init() {}

    @Published private(set) var recipes: [AutomationRecipe] = []
    @Published private(set) var templates: [RecipeTemplate] = []

    func loadRecipes(creatorUid: String) async throws {
        guard AppConfig.Features.enableAutomationRecipes else { return }
        #if canImport(FirebaseFirestore)
        let snap = try await Firestore.firestore()
            .collection("automation_recipes")
            .whereField("creatorUid", isEqualTo: creatorUid)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        recipes = snap.documents.compactMap { doc in
            try? doc.data(as: AutomationRecipe.self)
        }
        #endif
    }

    func createRecipe(creatorUid: String, name: String, trigger: RecipeTrigger, actions: [RecipeAction]) async throws {
        guard AppConfig.Features.enableAutomationRecipes else { return }
        #if canImport(FirebaseFirestore)
        let ref = Firestore.firestore().collection("automation_recipes").document()
        let actionsData = actions.map { a in
            ["type": a.type.rawValue, "config": a.config] as [String: Any]
        }
        try await ref.setData([
            "creatorUid": creatorUid,
            "name": name,
            "trigger": trigger.rawValue,
            "actions": actionsData,
            "enabled": true,
            "runCount": 0,
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    func toggleRecipe(recipeId: String, enabled: Bool) async throws {
        guard AppConfig.Features.enableAutomationRecipes else { return }
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("automation_recipes").document(recipeId)
            .updateData(["enabled": enabled])
        #endif
    }

    func triggerRecipe(recipeId: String, videoId: String) async throws {
        guard AppConfig.Features.enableAutomationRecipes else { return }
        struct Request: Encodable { let task: String; let recipeId: String; let videoId: String }
        struct Raw: Decodable { let status: String? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelEvents,
            path: "/predict",
            body: Request(task: "execute_recipe", recipeId: recipeId, videoId: videoId)
        )
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore()
            .collection("automation_recipes").document(recipeId)
            .updateData([
                "runCount": FieldValue.increment(Int64(1)),
                "lastRunAt": FieldValue.serverTimestamp()
            ])
        #endif
    }

    func loadTemplates() async throws {
        guard AppConfig.Features.enableAutomationRecipes else { return }
        struct Request: Encodable { let task: String }
        struct Raw: Decodable { let templates: [RecipeTemplate]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .superAITeam,
            path: "/predict",
            body: Request(task: "recipe_templates")
        )
        templates = r.templates ?? []
    }
}
