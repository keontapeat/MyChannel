//
//  LazyServiceManager.swift
//  MyChannel
//
//  🚀 LAZY SERVICE INITIALIZATION SYSTEM
//  Load services on-demand for <2 second cold start
//

import Foundation
import SwiftUI

// MARK: - Service Priority Levels
enum ServicePriority: Int, Comparable {
    case critical = 0      // Must load at launch (Auth, Firebase)
    case high = 1          // Load within 1 second (Video, User data)
    case medium = 2        // Load within 2 seconds (Analytics, AI)
    case low = 3           // Load on-demand (Background services)
    case deferred = 4      // Load when needed (Advanced features)
    
    static func < (lhs: ServicePriority, rhs: ServicePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Service Registration
struct ServiceRegistration {
    let name: String
    let priority: ServicePriority
    let initializer: () async -> Void
    var isInitialized: Bool = false
    var initializationTime: TimeInterval = 0
}

// MARK: - Lazy Service Manager
@MainActor
class LazyServiceManager: ObservableObject {
    static let shared = LazyServiceManager()
    
    @Published var isReady = false
    @Published var initializationProgress: Double = 0
    @Published var currentlyInitializing: String = ""
    
    private var services: [String: ServiceRegistration] = [:]
    private var initializationStartTime: Date?
    private var criticalServicesLoaded = false
    
    private init() {
        registerAllServices()
    }
    
    // MARK: - Service Registration
    
    private func registerAllServices() {
        // CRITICAL: Must load at launch (<500ms)
        register("Security", priority: .critical) {
            AppSecurityService.shared.configure()
        }

        register("ValetStorage", priority: .critical) {
            _ = ValetSecureStorageService.shared
        }

        register("JWTSigning", priority: .critical) {
            _ = JWTRequestSigningService.shared
        }

        register("CertValidation", priority: .critical) {
            _ = CertificateValidationService.shared
        }

        register("ScreenProtection", priority: .critical) {
            _ = ScreenProtectionService.shared
        }

        register("Firebase", priority: .critical) {
            FirebaseManager.shared.configureIfPossible()
        }
        
        register("Authentication", priority: .critical) {
            // Auth manager already initialized as @StateObject
        }
        
        // HIGH: Load within 1 second
        register("LiveTV", priority: .high) {
            await LiveTVService.shared.initialize()
        }
        
        register("VideoService", priority: .high) {
            // Video service initialization
        }
        
        // MEDIUM: Load within 2 seconds — Observability & Monetization
        register("Sentry", priority: .medium) {
            let dsn = AppSecrets.sentryDSN
            guard !dsn.isEmpty else { return }
            SentryObservabilityService.shared.configure(dsn: dsn)
        }

        register("PostHog", priority: .medium) {
            let key = AppSecrets.postHogAPIKey
            guard !key.isEmpty else { return }
            await PostHogAnalyticsService.shared.configure(apiKey: key)
        }

        register("RevenueCat", priority: .medium) {
            let key = AppSecrets.revenueCatAPIKey
            guard !key.isEmpty else { return }
            await RevenueCatService.shared.configure(apiKey: key)
        }

        register("Stripe", priority: .medium) {
            let key = AppSecrets.stripePublishableKey
            guard !key.isEmpty else { return }
            await StripeCreatorPayoutService.shared.configure(publishableKey: key)
        }

        register("RealmOffline", priority: .medium) {
            await RealmOfflineService.shared.refreshCounts()
        }

        register("Analytics", priority: .medium) {
            // Firebase Analytics auto-starts with FirebaseApp.configure()
        }
        
        register("UserSeeder", priority: .medium) {
            await SmartUserSeederService.shared.initialize()
        }
        
        register("ImagePrefetcher", priority: .medium) {
            // Prewarm critical images from Firestore videos
            let vids = await VideoFirestoreService.shared.fetchAllPublicVideos(limit: 20)
            let criticalURLs = vids.compactMap { $0.posterCandidates.first }
            ImagePrefetcher.shared.prewarmCritical(urls: criticalURLs)
        }
        
        register("OfflineZip", priority: .medium) {
            _ = OfflineZipService.shared.offlineSizeBytes
        }

        // LOW: Load on-demand
        register("LiveTVPreload", priority: .low) {
            await LiveTVService.shared.preloadFireChannels(count: 12)
        }

        // AI agents deferred — do not touch cold-start path
        register("OpenAIAgent", priority: .deferred) {
            _ = OpenAIAgentService.shared
        }

        register("AgentLog", priority: .deferred) {
            _ = AgentLogService.shared
        }

        register("AlamofireAdmin", priority: .low) {
            _ = AlamofireAdminNetworkService.shared
        }

        register("PerspectiveModeration", priority: .low) {
            _ = PerspectiveModerationService.shared
        }

        register("CommandCenterReport", priority: .low) {
            _ = CommandCenterReportService.shared
        }

        register("CreatorAnalytics", priority: .low) {
            _ = CreatorAnalyticsChartService.shared
        }

        register("LiveChatWebSocket", priority: .low) {
            _ = LiveChatWebSocketService.shared
        }

        register("SharePlay", priority: .low) {
            SharePlayWatchService.shared.configureGroupSessions()
        }

        register("AutoCaption", priority: .low) {
            _ = AutoCaptionService.shared
        }

        register("LiveActivity", priority: .low) {
            _ = LiveActivityService.shared
        }
        
        register("PerformanceOptimizer", priority: .low) {
            PerformanceOptimizer.shared.optimizeAppLaunch()
        }
        
        // DEFERRED: Load when needed
        register("Doctor", priority: .deferred) {
            MyChannelDoctorService.shared.startMonitoring()
        }
    }
    
    // MARK: - Service Registration API
    
    func register(_ name: String, priority: ServicePriority, initializer: @escaping () async -> Void) {
        services[name] = ServiceRegistration(
            name: name,
            priority: priority,
            initializer: initializer
        )
    }
    
    // MARK: - Initialization
    
    func initializeApp() async {
        initializationStartTime = Date()
        print("🚀 [LazyServiceManager] Starting app initialization...")
        
        // Phase 1: Critical services (blocking, must complete)
        await initializeServices(priority: .critical)
        criticalServicesLoaded = true
        print("✅ [LazyServiceManager] Critical services loaded in \(elapsedTime())ms")
        
        // Phase 2: High priority (non-blocking, parallel)
        Task.detached(priority: .high) {
            await self.initializeServices(priority: .high)
            await MainActor.run {
                print("✅ [LazyServiceManager] High priority services loaded in \(self.elapsedTime())ms")
            }
        }
        
        // Phase 3: Medium priority (background)
        Task.detached(priority: .medium) {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            await self.initializeServices(priority: .medium)
            await MainActor.run {
                print("✅ [LazyServiceManager] Medium priority services loaded in \(self.elapsedTime())ms")
            }
        }
        
        // Phase 4: Low priority (background, delayed)
        Task.detached(priority: .low) {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
            await self.initializeServices(priority: .low)
            await MainActor.run {
                print("✅ [LazyServiceManager] Low priority services loaded in \(self.elapsedTime())ms")
            }
        }

        // 🔥 Apple Watch: activate WatchConnectivity so the watch gets now-playing updates
        Task.detached(priority: .low) {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay — after main stack is up
            await MainActor.run {
                WatchConnectivityService.shared.activate()
                print("⌚️ [LazyServiceManager] WatchConnectivity activated")
            }
        }
        
        // Phase 5: Deferred (load when needed)
        Task.detached(priority: .background) {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay
            await self.initializeServices(priority: .deferred)
            await MainActor.run {
                print("✅ [LazyServiceManager] Deferred services loaded in \(self.elapsedTime())ms")
                self.isReady = true
            }
        }
    }
    
    private func initializeServices(priority: ServicePriority) async {
        let servicesToInit = services.values
            .filter { $0.priority == priority && !$0.isInitialized }
            .sorted { $0.name < $1.name }
        
        for var service in servicesToInit {
            await MainActor.run {
                currentlyInitializing = service.name
            }
            
            let startTime = Date()
            await service.initializer()
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                service.isInitialized = true
                service.initializationTime = duration
                services[service.name] = service
                
                updateProgress()
                
                print("  ✓ [\(priority)] \(service.name) initialized in \(Int(duration * 1000))ms")
            }
        }
    }
    
    // MARK: - On-Demand Loading
    
    func ensureServiceLoaded(_ name: String) async {
        guard var service = services[name], !service.isInitialized else { return }
        
        print("🔄 [LazyServiceManager] Loading on-demand: \(name)")
        let startTime = Date()
        await service.initializer()
        let duration = Date().timeIntervalSince(startTime)
        
        service.isInitialized = true
        service.initializationTime = duration
        services[name] = service
        
        print("  ✓ \(name) loaded in \(Int(duration * 1000))ms")
    }
    
    // MARK: - Progress Tracking
    
    private func updateProgress() {
        let total = services.count
        let initialized = services.values.filter { $0.isInitialized }.count
        initializationProgress = Double(initialized) / Double(total)
    }
    
    private func elapsedTime() -> Int {
        guard let start = initializationStartTime else { return 0 }
        return Int(Date().timeIntervalSince(start) * 1000)
    }
    
    // MARK: - Statistics
    
    func printStatistics() {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 SERVICE INITIALIZATION STATISTICS")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Total Time: \(elapsedTime())ms")
        print("Services Loaded: \(services.values.filter { $0.isInitialized }.count)/\(services.count)")
        print("\nBy Priority:")
        
        for priority in [ServicePriority.critical, .high, .medium, .low, .deferred] {
            let priorityServices = services.values.filter { $0.priority == priority }
            let loaded = priorityServices.filter { $0.isInitialized }.count
            let avgTime = priorityServices.filter { $0.isInitialized }
                .map { $0.initializationTime }
                .reduce(0, +) / Double(max(loaded, 1))
            
            print("  [\(priority)]: \(loaded)/\(priorityServices.count) (avg: \(Int(avgTime * 1000))ms)")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}

// MARK: - Service Access Helpers

extension LazyServiceManager {
    /// Ensure a service is loaded before accessing it
    func withService<T>(_ name: String, operation: () async -> T) async -> T {
        await ensureServiceLoaded(name)
        return await operation()
    }
}
