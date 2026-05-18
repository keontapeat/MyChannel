#if canImport(Sentry)
import Sentry
#endif
import Foundation

/// Sentry Observability — Crash Reporting & Performance Monitoring
/// Tracks ANRs, network latency, slow renders, and custom business events.
final class SentryObservabilityService {
    static let shared = SentryObservabilityService()

    private var isConfigured = false

    private init() {}

    func configure(dsn: String, environment: String = "production") {
        #if canImport(Sentry)
        guard !isConfigured else { return }
        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.tracesSampleRate = 0.2
            options.enableCrashHandler = true
            options.enableNetworkBreadcrumbs = true
            options.enableAutoBreadcrumbTracking = true
        }
        isConfigured = true
        print("✅ [Sentry] Configured for \(environment).")
        #endif
    }

    func identifyUser(uid: String, email: String?) {
        #if canImport(Sentry)
        let user = Sentry.User(userId: uid)
        user.email = email
        SentrySDK.setUser(user)
        #endif
    }

    func captureError(_ error: Error, context: [String: Any]? = nil) {
        #if canImport(Sentry)
        SentrySDK.capture(error: error) { scope in
            if let ctx = context {
                scope.setContext(value: ctx, key: "extra")
            }
        }
        #else
        print("⚠️ [Sentry] Error (not reported): \(error.localizedDescription)")
        #endif
    }

    func captureMessage(_ message: String, level: String = "info") {
        #if canImport(Sentry)
        let sentryLevel: SentryLevel
        switch level {
        case "error": sentryLevel = .error
        case "warning": sentryLevel = .warning
        case "debug": sentryLevel = .debug
        default: sentryLevel = .info
        }
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(sentryLevel)
        }
        #endif
    }

    func startTransaction(name: String, operation: String) -> Any? {
        #if canImport(Sentry)
        return SentrySDK.startTransaction(name: name, operation: operation)
        #else
        return nil
        #endif
    }

    func addBreadcrumb(category: String, message: String, level: String = "info") {
        #if canImport(Sentry)
        let crumb = Breadcrumb()
        crumb.category = category
        crumb.message = message
        crumb.level = level == "error" ? .error : .info
        SentrySDK.addBreadcrumb(crumb)
        #endif
    }

    func clearUser() {
        #if canImport(Sentry)
        SentrySDK.setUser(nil)
        #endif
    }
}
