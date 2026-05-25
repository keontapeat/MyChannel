//
//  PlatformMigrationService.swift
//  MyChannel
//
//  Phase 200: Platform v2.0 Migration Engine.
//  Zero-downtime schema migration, feature flag graduation, legacy cleanup.
//  Uses `auto-scaler` Cloud Run.
//

import Foundation

// MARK: - Models

struct SchemaMigration: Codable, Identifiable {
    let id: String
    let version: String
    let description: String
    let status: MigrationStatus
    let affectedCollections: [String]
    let startedAt: Date?
    let completedAt: Date?
    let rollbackAvailable: Bool
}

enum MigrationStatus: String, Codable { case pending, running, completed, failed, rolledBack }

struct FeatureFlagGraduation: Codable, Identifiable {
    let id: String
    let flagName: String
    let phase: Int
    let currentValue: Bool
    let readyToGraduate: Bool
    let dependsOn: [String]
}

struct LegacyCleanupItem: Codable, Identifiable {
    let id: String
    let type: String
    let path: String
    let description: String
    let safeToRemove: Bool
    let lastUsed: Date?
}

// MARK: - Service

@MainActor
final class PlatformMigrationService: ObservableObject {
    static let shared = PlatformMigrationService()
    private init() {}

    @Published private(set) var migrations: [SchemaMigration] = []
    @Published private(set) var graduations: [FeatureFlagGraduation] = []
    @Published private(set) var cleanupItems: [LegacyCleanupItem] = []

    func loadMigrations() async throws {
        guard AppConfig.Features.enablePlatformMigration else { return }
        struct Request: Encodable { let task: String }
        struct RawMigration: Decodable { let version: String; let desc: String; let status: String; let collections: [String]; let rollback: Bool }
        struct Raw: Decodable { let migrations: [RawMigration]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Request(task: "list_migrations")
        )
        migrations = (r.migrations ?? []).map {
            SchemaMigration(id: UUID().uuidString, version: $0.version, description: $0.desc,
                          status: MigrationStatus(rawValue: $0.status) ?? .pending,
                          affectedCollections: $0.collections, startedAt: nil, completedAt: nil,
                          rollbackAvailable: $0.rollback)
        }
    }

    func runMigration(migrationId: String) async throws {
        guard AppConfig.Features.enablePlatformMigration else { return }
        if let idx = migrations.firstIndex(where: { $0.id == migrationId }) {
            let old = migrations[idx]
            migrations[idx] = SchemaMigration(id: old.id, version: old.version, description: old.description,
                                             status: .running, affectedCollections: old.affectedCollections,
                                             startedAt: Date(), completedAt: nil, rollbackAvailable: old.rollbackAvailable)
        }
        struct Request: Encodable { let task: String; let migrationId: String }
        struct Raw: Decodable { let status: String? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Request(task: "run_migration", migrationId: migrationId), timeout: 300
        )
    }

    func scanLegacyCode() async throws {
        guard AppConfig.Features.enablePlatformMigration else { return }
        struct Request: Encodable { let task: String }
        struct RawItem: Decodable { let type: String; let path: String; let desc: String; let safe: Bool }
        struct Raw: Decodable { let items: [RawItem]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .autoScaler, path: "/predict",
            body: Request(task: "scan_legacy")
        )
        cleanupItems = (r.items ?? []).map {
            LegacyCleanupItem(id: UUID().uuidString, type: $0.type, path: $0.path,
                            description: $0.desc, safeToRemove: $0.safe, lastUsed: nil)
        }
    }

    func graduateFlag(flagName: String) {
        guard AppConfig.Features.enablePlatformMigration else { return }
        if let idx = graduations.firstIndex(where: { $0.flagName == flagName }) {
            let old = graduations[idx]
            graduations[idx] = FeatureFlagGraduation(id: old.id, flagName: old.flagName, phase: old.phase,
                                                    currentValue: true, readyToGraduate: old.readyToGraduate,
                                                    dependsOn: old.dependsOn)
        }
    }
}
