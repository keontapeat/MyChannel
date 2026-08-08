import UIKit
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif
import UserNotifications
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
import Foundation

enum FirebaseAppCheckConfigurator {
    private static var isConfigured = false

    static func configureProviderFactoryIfAvailable() {
        guard !isConfigured else { return }
        #if canImport(FirebaseAppCheck)
        // 🔥 CRASH FIX (App Store Guideline 2.1(a), submissions 438e47dd / 87a4fcea):
        // AppAttestProvider talks to the Secure Enclave and can hang indefinitely when
        // the device is locked (App Review crash logs show `GACAppAttestProvider.state`
        // blocked on a semaphore + 0x8BADF00D scene-update watchdog). DeviceCheck is
        // asynchronous, does not require unlock, and is the recommended production
        // provider when App Attest is not strictly required at cold launch.
        final class ProviderFactory: NSObject, AppCheckProviderFactory {
            func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
                #if DEBUG
                return AppCheckDebugProvider(app: app)
                #else
                return DeviceCheckProvider(app: app)
                #endif
            }
        }
        AppCheck.setAppCheckProviderFactory(ProviderFactory())
        #endif
        isConfigured = true
    }
}

enum PushTokenRegistrationManager {
    private static let tokenKey = "fcm_token"

    static func store(_ token: String) -> String? {
        let previousToken = KeychainHelper.shared.getString(for: tokenKey)
        _ = KeychainHelper.shared.save(token, for: tokenKey)
        return previousToken
    }

    static func registerStoredToken(for userId: String) async {
        guard let token = KeychainHelper.shared.getString(for: tokenKey) else { return }
        await register(token, for: userId)
    }

    static func register(_ token: String, for userId: String, retiring previousToken: String? = nil) async {
        #if canImport(FirebaseFirestore)
        guard !token.isEmpty, !token.contains("/"), !userId.isEmpty else { return }
        do {
            let tokens = Firestore.firestore()
                .collection("users").document(userId)
                .collection("fcmTokens")
            try await tokens.document(token).setData([
                "token": token,
                "platform": "ios",
                "active": true,
                "registeredAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            if let previousToken,
               previousToken != token,
               !previousToken.contains("/") {
                try? await tokens.document(previousToken).delete()
            }
        } catch {
            print("⚠️ [Push] FCM token registration failed")
        }
        #endif
    }

    static func unregisterStoredToken(for userId: String) async {
        #if canImport(FirebaseFirestore)
        guard let token = KeychainHelper.shared.getString(for: tokenKey),
              !token.isEmpty,
              !token.contains("/"),
              !userId.isEmpty else { return }
        do {
            try await Firestore.firestore()
                .collection("users").document(userId)
                .collection("fcmTokens").document(token)
                .delete()
        } catch {
            print("⚠️ [Push] FCM token unregister failed")
        }
        #endif
    }
}

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    #if canImport(FirebaseAuth)
    private var authStateListener: AuthStateDidChangeListenerHandle?
    #endif

    #if canImport(FirebaseMessaging)
    private func configureMessaging() {
        // Configure FCM if the module is available
        Messaging.messaging().delegate = self
    }
    #endif

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let appLaunchStart = Date()

        FirebaseAppCheckConfigurator.configureProviderFactoryIfAvailable()
        FirebaseManager.shared.configureIfPossible()
        let isFirebaseConfigured = FirebaseManager.shared.isConfigured

        #if canImport(FirebaseAuth)
        if isFirebaseConfigured {
            authStateListener = Auth.auth().addStateDidChangeListener { _, user in
                guard let user else { return }
                Task {
                    await PushTokenRegistrationManager.registerStoredToken(for: user.uid)
                }
            }
        }
        #endif

        // Register every launch handler synchronously before this method returns. The task
        // identifier must exactly match BGTaskSchedulerPermittedIdentifiers in Info.plist.
        BackgroundFetchService.shared.register()

        if isFirebaseConfigured {
            let launchTime = Date().timeIntervalSince(appLaunchStart)
            PerformanceMonitoringManager.shared.trackAppLaunch(launchTime: launchTime)
        } else {
            print("⚠️ [AppLaunch] Firebase configuration unavailable; Firebase services disabled")
        }

        // Ensure GoogleSignIn has client ID configured very early
        #if canImport(GoogleSignIn)
        if GIDSignIn.sharedInstance.configuration == nil,
           let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        }
        #endif

        // Initialize enhanced Firebase services only after Firebase is configured.
        if isFirebaseConfigured {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
                await RemoteConfigManager.shared.fetchAndActivate()

                MonitoringDashboardManager.shared.updateMetric("app_launches", value: 1.0)

                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                EnhancedAnalyticsManager.shared.setUserProperty(appVersion, forName: "app_version")
                EnhancedAnalyticsManager.shared.setUserProperty(UIDevice.current.model, forName: "device_model")

                print("✅ [AppLaunch] Enhanced Firebase services initialized")
            }
        }

        // ChannelBoost install log (non-blocking)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s delay
            let locale = Locale.current.identifier
            await ChannelBoostService.shared.logInstall(platform: "ios", locale: locale, source: "app", campaign: nil, referral: nil)
        }

        // 💰 Initialize Google Mobile Ads SDK for REAL ad revenue!
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
            AdMobManager.shared.initialize()
        }

        // 🛡️ Start Platform Monitor Service — 24/7 fraud + content scanning
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay
            PlatformMonitorService.shared.start()
        }

        // 🤖 Start AGI Agent Scheduler — all agents improving the app daily
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5s delay
            let manager = AGIAgentManager.shared
            // Auto-start scheduler if agents are already deployed
            let liveCount = manager.agents.filter { $0.status == .live && $0.isEnabled }.count
            if liveCount > 0 {
                manager.startScheduler()
                print("⚡ [AppLaunch] AGI Scheduler started with \(liveCount) live agents")
            }
        }

        // Set notification center delegate early (only if Firebase Messaging is usable).
        #if canImport(FirebaseMessaging)
        if isFirebaseConfigured {
            UNUserNotificationCenter.current().delegate = PushNotificationService.shared
            configureMessaging()
        }
        #else
        print("⚠️ Push notifications disabled - requires paid Apple Developer Program membership")
        #endif

        return true
    }

    // MARK: - APNs registration bridging (disabled for personal development team)
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseMessaging)
        // Pass device token to FCM
        Messaging.messaging().apnsToken = deviceToken
        #else
        print("⚠️ APNs registration skipped - requires paid Apple Developer Program membership")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("⚠️ APNs registration failed (expected with personal development team): \(error)")
    }

    deinit {
        #if canImport(FirebaseAuth)
        if let authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
        #endif
    }
}

#if canImport(FirebaseMessaging)
extension FirebaseAppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty, !token.contains("/") else { return }
        let previousToken = PushTokenRegistrationManager.store(token)

        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        guard FirebaseApp.app() != nil, let userId = Auth.auth().currentUser?.uid else { return }
        Task {
            await PushTokenRegistrationManager.register(
                token,
                for: userId,
                retiring: previousToken
            )
        }
        #endif
    }
}
#endif