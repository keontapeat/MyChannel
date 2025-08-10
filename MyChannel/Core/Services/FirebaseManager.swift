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

    func configureIfPossible() {
        #if canImport(FirebaseCore)
        if isConfigured { return }
        if FirebaseApp.app() != nil {
            isConfigured = true
            return
        }
        FirebaseApp.configure()
        isConfigured = true
        #else
        isConfigured = false
        #endif
    }

    func logEvent(_ name: String, parameters: [String: Any] = [:]) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: parameters)
        #else
        print("Analytics [stub] \(name): \(parameters)")
        #endif
    }

    func setUserId(_ userId: String?) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(userId)
        #endif
    }

    func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
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