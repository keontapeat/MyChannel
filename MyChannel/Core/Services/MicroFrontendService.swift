//
//  MicroFrontendService.swift
//  MyChannel
//
//  Phase 197: Micro-Frontend Architecture.
//  Modular feature loading, dynamic feature delivery, A/B feature rollout.
//

import Foundation

// MARK: - Models

struct FeatureModule: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let version: String
    let isLoaded: Bool
    let loadPriority: Int
    let sizeKB: Int
    let dependencies: [String]
}

struct FeatureRollout: Codable, Identifiable {
    let id: String
    let featureId: String
    let percentageRolled: Double
    let targetAudience: String
    let status: String
    let startedAt: Date
}

// MARK: - Service

@MainActor
final class MicroFrontendService: ObservableObject {
    static let shared = MicroFrontendService()
    private init() {}

    @Published private(set) var modules: [FeatureModule] = []
    @Published private(set) var rollouts: [FeatureRollout] = []
    @Published var loadedModuleIds: Set<String> = []

    func registerModule(_ module: FeatureModule) {
        guard AppConfig.Features.enableMicroFrontend else { return }
        if !modules.contains(where: { $0.id == module.id }) {
            modules.append(module)
        }
    }

    func loadModule(_ moduleId: String) async {
        guard AppConfig.Features.enableMicroFrontend else { return }
        guard let idx = modules.firstIndex(where: { $0.id == moduleId }) else { return }
        let old = modules[idx]
        for dep in old.dependencies {
            if !loadedModuleIds.contains(dep) { await loadModule(dep) }
        }
        modules[idx] = FeatureModule(id: old.id, name: old.name, version: old.version,
                                     isLoaded: true, loadPriority: old.loadPriority,
                                     sizeKB: old.sizeKB, dependencies: old.dependencies)
        loadedModuleIds.insert(moduleId)
    }

    func unloadModule(_ moduleId: String) {
        guard let idx = modules.firstIndex(where: { $0.id == moduleId }) else { return }
        let old = modules[idx]
        modules[idx] = FeatureModule(id: old.id, name: old.name, version: old.version,
                                     isLoaded: false, loadPriority: old.loadPriority,
                                     sizeKB: old.sizeKB, dependencies: old.dependencies)
        loadedModuleIds.remove(moduleId)
    }

    func isModuleAvailable(_ moduleId: String, for userId: String) -> Bool {
        guard AppConfig.Features.enableMicroFrontend else { return true }
        guard let rollout = rollouts.first(where: { $0.featureId == moduleId }) else { return true }
        let hash = abs(userId.hashValue) % 100
        return Double(hash) < rollout.percentageRolled
    }

    func startRollout(featureId: String, percentageRolled: Double, targetAudience: String) {
        guard AppConfig.Features.enableMicroFrontend else { return }
        rollouts.append(FeatureRollout(id: UUID().uuidString, featureId: featureId,
                                       percentageRolled: percentageRolled, targetAudience: targetAudience,
                                       status: "active", startedAt: Date()))
    }
}
