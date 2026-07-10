//
//  DependencyContainer.swift
//  MyChannel
//
//  Centralized Dependency Injection Container for Enterprise Architecture
//  Allows robust mocking and zero singleton spaghetti.
//

import Foundation

/// Central registry for all application services
@MainActor
final class DependencyContainer: @unchecked Sendable {
    static let shared = DependencyContainer()
    
    // Thread-safe storage for factories
    private var factories: [String: Any] = [:]
    // Thread-safe storage for cached singletons
    private var cachedInstances: [String: Any] = [:]
    
    private let queue = DispatchQueue(label: "com.mychannel.di", attributes: .concurrent)
    
    private init() {
        registerDefaultServices()
    }

    /// SwiftUI previews use the same registry. Override registrations in `#Preview`
    /// setup before the view body resolves `@Injected` properties.
    static var preview: DependencyContainer { shared }
    
    /// Register a service factory
    func register<Service>(_ type: Service.Type, isSingleton: Bool = true, factory: @escaping () -> Service) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.factories[key] = factory
            if !isSingleton {
                self.cachedInstances.removeValue(forKey: key)
            }
        }
    }
    
    /// Resolve a service dependency
    func resolve<Service>(_ type: Service.Type) -> Service {
        let key = String(describing: type)
        
        return queue.sync {
            // Return cached instance if it exists
            if let cached = cachedInstances[key] as? Service {
                return cached
            }
            
            // Otherwise generate via factory
            guard let factory = factories[key] as? () -> Service else {
                let message = """
                🛑 [DI] No registered dependency for '\(key)'.
                Register it in DependencyContainer.registerDefaultServices() \
                or call container.register(\(key).self) { … } before resolve().
                See docs/injected-property-wrapper.md
                """
                print(message)
                preconditionFailure(message)
            }
            
            let instance = factory()
            // Cache it as a singleton by default
            cachedInstances[key] = instance
            return instance
        }
    }

    /// Graceful variant of `resolve` for callers that can tolerate a missing
    /// registration. Returns `nil` instead of trapping.
    func resolveOptional<Service>(_ type: Service.Type) -> Service? {
        let key = String(describing: type)
        return queue.sync {
            if let cached = cachedInstances[key] as? Service {
                return cached
            }
            guard let factory = factories[key] as? () -> Service else {
                print("⚠️ [DI] No registered dependency for \(key) (resolveOptional → nil).")
                return nil
            }
            let instance = factory()
            cachedInstances[key] = instance
            return instance
        }
    }

    /// Drop user-scoped cached singletons on logout so the next session cannot
    /// read stale wallet/compliance state from the prior account.
    func unregisterUserScopedServices() {
        let userScopedKeys = [
            String(describing: VSMatchWalletService.self),
            String(describing: VSMatchComplianceService.self),
            String(describing: VersusMatchService.self),
            String(describing: MoneyEscrowService.self),
            String(describing: StripeConnectService.self),
        ]
        queue.async(flags: .barrier) {
            for key in userScopedKeys {
                self.cachedInstances.removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - App Defaults
    private func registerDefaultServices() {
        // Network / cache
        register(NetworkService.self) { NetworkService.shared }
        register(RedisCacheService.self) { RedisCacheService.shared }
        register(ObjectStorageOrchestrator.self) { ObjectStorageOrchestrator.shared }
        register(AnalyticsService.self) { AnalyticsService.shared }
        register(AgentAPIService.self) { AgentAPIService.shared }
        register(VideoFirestoreService.self) { VideoFirestoreService.shared }
        register(SeedCatalogService.self) { SeedCatalogService.shared }

        // Auth
        register(AuthenticationManager.self) { AuthenticationManager.shared }

        // Playback
        register(GlobalVideoPlayerManager.self) { GlobalVideoPlayerManager.shared }

        // Monetization / compliance / offline
        register(MoneyEscrowService.self) { MoneyEscrowService.shared }
        register(MoneyEscrowing.self) { MoneyEscrowService.shared }
        register(VSMatchComplianceService.self) { VSMatchComplianceService.shared }
        register(ComplianceChecking.self) { VSMatchComplianceService.shared }
        register(VSMatchWalletService.self) { VSMatchWalletService.shared }
        register(VSMatchWalleting.self) { VSMatchWalletService.shared }
        register(VersusMatchService.self) { VersusMatchService.shared }
        register(VersusMatching.self) { VersusMatchService.shared }
        register(StripeConnectService.self) { StripeConnectService.shared }
        register(StripeConnecting.self) { StripeConnectService.shared }
        register(OfflineDownloadService.self) { OfflineDownloadService.shared }

        // AI facade (prefer over UnifiedAGIBrain / SuperAGI)
        register(CreatorIntelligenceService.self) { CreatorIntelligenceService.shared }

        // Gaming / playlists
        register(ChampionshipBeltSystem.self) { ChampionshipBeltSystem.shared }
        register(PlaylistFirestoreService.self) { PlaylistFirestoreService.shared }
    }
}
