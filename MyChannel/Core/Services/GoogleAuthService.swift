//
//  GoogleAuthService.swift
//  MyChannel
//
//  Google Sign-In authentication: token management,
//  credential refresh, scope management. Wraps Firebase Google Auth.
//

import Foundation
import GoogleSignIn
import FirebaseAuth

@MainActor
final class GoogleAuthService: ObservableObject {
    static let shared = GoogleAuthService()
    private init() {}
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var userEmail: String?
    @Published private(set) var userName: String?

    func signIn() async throws -> GoogleSignInPayload {
        guard let presentingVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            throw NSError(domain: "GoogleAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"])
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "GoogleAuth", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing ID token"])
        }
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        let authResult = try await Auth.auth().signIn(with: credential)
        let firebaseUser = authResult.user
        userEmail = firebaseUser.email ?? result.user.profile?.email
        userName = firebaseUser.displayName ?? result.user.profile?.name
        isAuthenticated = true
        return GoogleSignInPayload(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? result.user.profile?.email ?? "",
            displayName: firebaseUser.displayName ?? result.user.profile?.name ?? "User",
            photoURL: firebaseUser.photoURL?.absoluteString ?? result.user.profile?.imageURL(withDimension: 200)?.absoluteString
        )
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isAuthenticated = false
        userEmail = nil
        userName = nil
    }

    func restorePreviousSignIn() -> Bool {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                Task { @MainActor in
                    self?.isAuthenticated = user != nil
                    self?.userEmail = user?.profile?.email
                    self?.userName = user?.profile?.name
                }
            }
            return true
        }
        return false
    }

    func currentAccessToken() -> String? {
        GIDSignIn.sharedInstance.currentUser?.accessToken.tokenString
    }
}

struct GoogleSignInPayload {
    let uid: String
    let email: String
    let displayName: String
    let photoURL: String?
}
