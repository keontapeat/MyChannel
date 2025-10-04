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
            return
        }
        FirebaseApp.configure()
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