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
                fatalError("No registered dependency found for \(key)")
            }
            
            let instance = factory()
            // Cache it as a singleton by default
            cachedInstances[key] = instance
            return instance
        }
    }
    
    // MARK: - App Defaults
    private func registerDefaultServices() {
        // Register core network and cache services
        register(NetworkService.self) { NetworkService.shared }
        register(RedisCacheService.self) { RedisCacheService.shared }
        register(ObjectStorageOrchestrator.self) { ObjectStorageOrchestrator.shared }
        register(AnalyticsService.self) { AnalyticsService.shared }
        register(AgentAPIService.self) { AgentAPIService.shared }
        register(VideoFirestoreService.self) { VideoFirestoreService.shared }
        register(SeedCatalogService.self) { SeedCatalogService.shared }
    }
}
