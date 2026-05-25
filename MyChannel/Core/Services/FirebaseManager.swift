import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

final class FirebaseManager {
    static let shared = FirebaseManager()
    private init() {}

    private(set) var isConfigured = false
    private let analyticsEnabledKey = "privacy.analyticsEnabled"

    func configureIfPossible() {
        #if canImport(FirebaseCore)
        if isConfigured { return }
        if FirebaseApp.app() != nil {
            isConfigured = true
            Task { @MainActor in
                configureAdditionalServices()
            }
            return
        }
        // Ensure GoogleService-Info.plist exists before configuring to avoid runtime crashes
        let hasGooglePlist: Bool = {
            if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                return true
            }
            // Some projects embed under a nested path; try to locate via info dictionary as well
            return Bundle.main.object(forInfoDictionaryKey: "GOOGLE_APP_ID") != nil
        }()

        guard hasGooglePlist else {
            isConfigured = false
            return
        }

        FirebaseApp.configure()
        Task { @MainActor in
            configureAdditionalServices()
        }
        
        #if canImport(FirebaseAnalytics)
        if UserDefaults.standard.bool(forKey: analyticsEnabledKey) {
            Analytics.logEvent("app_launch", parameters: [
                "ts": Date().timeIntervalSince1970
            ])
        }
        #endif
        isConfigured = true
        #else
        isConfigured = false
        #endif
    }
    
    @MainActor
    private func configureAdditionalServices() {
        // Configure Performance Monitoring
        PerformanceMonitoringManager.shared.configure()
        
        // Configure Remote Config
        RemoteConfigManager.shared.configure()
        
        // Configure A/B Testing
        ABTestingManager.shared.configure()
        
        // Configure Error Reporting
        ErrorReportingManager.shared.configure()
        
        print("✅ [Firebase] All enhanced services configured")
    }

    func logEvent(_ name: String, parameters: [String: Any] = [:]) {
        #if canImport(FirebaseAnalytics)
        if UserDefaults.standard.bool(forKey: analyticsEnabledKey) {
            Analytics.logEvent(name, parameters: parameters)
        }
        #else
        print("Analytics [stub] \(name): \(parameters)")
        #endif
    }

    func setUserId(_ userId: String?) {
        #if canImport(FirebaseAnalytics)
        if UserDefaults.standard.bool(forKey: analyticsEnabledKey) {
            Analytics.setUserID(userId)
        }
        #endif
    }

    func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        if UserDefaults.standard.bool(forKey: analyticsEnabledKey) {
            Analytics.setUserProperty(value, forName: name)
        }
        #endif
    }

    // MARK: - Privacy Toggles
    func setAnalyticsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: analyticsEnabledKey)
    }
    func isAnalyticsEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: analyticsEnabledKey)
    }

    func currentFcmToken() async -> String? {
        #if canImport(FirebaseMessaging)
        return await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                continuation.resume(returning: token)
            }
        }
        #else
        return nil
        #endif
    }
}