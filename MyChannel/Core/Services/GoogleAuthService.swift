import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
final class GoogleAuthService {
    static let shared = GoogleAuthService()
    private init() {}

    struct Payload { let uid: String; let email: String; let displayName: String; let photoURL: String? }

    func signIn() async throws -> Payload {
        #if canImport(FirebaseAuth)
        #if canImport(GoogleSignIn)
        guard let presenting = topViewController() else {
            throw NSError(domain: "GoogleAuth", code: -10, userInfo: [NSLocalizedDescriptionKey: "No presenter available"])
        }

        // Use async/await Google Sign-In API
        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        let gidUser = signInResult.user

        guard let idToken = gidUser.idToken?.tokenString else {
            throw NSError(domain: "GoogleAuth", code: -12, userInfo: [NSLocalizedDescriptionKey: "Missing ID token"])
        }
        let accessToken = gidUser.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let result = try await Auth.auth().signIn(with: credential)
        let fuser = result.user
        return Payload(uid: fuser.uid,
                       email: fuser.email ?? gidUser.profile?.email ?? "",
                       displayName: fuser.displayName ?? gidUser.profile?.name ?? "Google User",
                       photoURL: fuser.photoURL?.absoluteString)
        #else
        throw NSError(domain: "GoogleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In SDK not linked. Add via SPM: https://github.com/google/GoogleSignIn-iOS"])
        #endif
        #else
        throw NSError(domain: "GoogleAuth", code: -2, userInfo: [NSLocalizedDescriptionKey: "FirebaseAuth not available"])
        #endif
    }

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        #if canImport(UIKit)
        let baseVC: UIViewController? = base ?? {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController { return root }
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        }()
        if let nav = baseVC as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = baseVC as? UITabBarController { return topViewController(base: tab.selectedViewController) }
        if let presented = baseVC?.presentedViewController { return topViewController(base: presented) }
        return baseVC
        #else
        return nil
        #endif
    }
}
