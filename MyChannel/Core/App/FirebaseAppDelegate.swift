import UIKit
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
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

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    // Optional: Firebase App Check
    private func configureAppCheckIfAvailable() {
        #if canImport(FirebaseAppCheck)
        class ProviderFactory: NSObject, AppCheckProviderFactory {
            func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
                #if DEBUG
                return AppCheckDebugProvider(app: app)
                #else
                if #available(iOS 14.0, *) {
                    return AppAttestProvider(app: app)
                } else {
                    return DeviceCheckProvider(app: app)
                }
                #endif
            }
        }
        AppCheck.setAppCheckProviderFactory(ProviderFactory())
        #endif
    }
    
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
        
        configureAppCheckIfAvailable()
        FirebaseManager.shared.configureIfPossible()
        
        // Track app launch performance
        let launchTime = Date().timeIntervalSince(appLaunchStart)
        PerformanceMonitoringManager.shared.trackAppLaunch(launchTime: launchTime)
        
        // Ensure GoogleSignIn has client ID configured very early
        #if canImport(GoogleSignIn)
        if GIDSignIn.sharedInstance.configuration == nil,
           let clientId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        }
        #endif
        
        // Initialize enhanced Firebase services
        Task { @MainActor in
            // Fetch remote config early
            await RemoteConfigManager.shared.fetchAndActivate()
            
            // Start monitoring dashboard
            MonitoringDashboardManager.shared.updateMetric("app_launches", value: 1.0)
            
            // Set up analytics user properties
            EnhancedAnalyticsManager.shared.setUserProperty(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown", forName: "app_version")
            EnhancedAnalyticsManager.shared.setUserProperty(UIDevice.current.model, forName: "device_model")
            
            print("✅ [AppLaunch] Enhanced Firebase services initialized")
        }
        
        // ChannelBoost install log (non-blocking)
        Task { @MainActor in
            let locale = Locale.current.identifier
            await ChannelBoostService.shared.logInstall(platform: "ios", locale: locale, source: "app", campaign: nil, referral: nil)
        }
        
        // 💰 Initialize Google Mobile Ads SDK for REAL ad revenue!
        Task { @MainActor in
            AdMobManager.shared.initialize()
        }
        
        // 🛡️ Start Platform Monitor Service — 24/7 fraud + content scanning
        Task { @MainActor in
            PlatformMonitorService.shared.start()
        }
        
        // 🤖 Start AGI Agent Scheduler — all agents improving the app daily
        Task { @MainActor in
            let manager = AGIAgentManager.shared
            // Auto-start scheduler if agents are already deployed
            let liveCount = manager.agents.filter { $0.status == .live && $0.isEnabled }.count
            if liveCount > 0 {
                manager.startScheduler()
                print("⚡ [AppLaunch] AGI Scheduler started with \(liveCount) live agents")
            }
        }
        
        // Set notification center delegate early (only if push notifications are available)
        // Note: Push notifications require a paid Apple Developer Program membership
        #if canImport(FirebaseMessaging)
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared
        configureMessaging()
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
}

#if canImport(FirebaseMessaging)
extension FirebaseAppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("✅ FCM registration token: \(token)")
        // Optionally forward to backend or store securely
        _ = KeychainHelper.shared.save(token, for: "fcm_token")
    }
}
#endif