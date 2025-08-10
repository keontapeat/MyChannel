import UIKit
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
import UserNotifications

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
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
        FirebaseManager.shared.configureIfPossible()

        // Set notification center delegate early
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared

        #if canImport(FirebaseMessaging)
        configureMessaging()
        #endif
        return true
    }

    // MARK: - APNs registration bridging
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseMessaging)
        // Pass device token to FCM
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error)")
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