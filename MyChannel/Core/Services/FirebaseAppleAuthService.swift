import Foundation
import AuthenticationServices
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - FirebaseAppleAuthService
// Uses itself as the ASAuthorizationController delegate (singleton = never deallocated).
// Stores the continuation as a property — no closure captures, no [weak self] risk.
@MainActor
final class FirebaseAppleAuthService: NSObject {
    static let shared = FirebaseAppleAuthService()
    private override init() { super.init() }

    // Retained for the duration of each sign-in flow
    private var activeController: ASAuthorizationController?
    // Active nonce for the in-flight request
    private var pendingNonce: String?
    // Continuation resumed when the flow ends
    private var pendingContinuation: CheckedContinuation<AuthPayload, Error>?

    var isAvailable: Bool {
        #if canImport(FirebaseAuth)
        return true
        #else
        return false
        #endif
    }

    func signIn() async throws -> AuthPayload {
        // Cancel any stale in-flight request
        pendingContinuation?.resume(throwing: AuthError.unknown)
        pendingContinuation = nil
        activeController = nil

        let nonce = randomNonceString()
        pendingNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            self.pendingContinuation = continuation
            self.activeController = controller
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Firebase credential exchange
    private func completeFirebaseSignIn(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws -> AuthPayload {
        guard let tokenData = credential.identityToken,
              let idTokenString = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.unknown
        }
        #if canImport(FirebaseAuth)
        let oauth = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        let result = try await Auth.auth().signIn(with: oauth)
        let fu = result.user
        let email = fu.email ?? credential.email
        let displayName = credential.fullName?.formatted() ?? fu.displayName ?? "Apple User"
        return AuthPayload(uid: fu.uid, email: email, displayName: displayName)
        #else
        throw AuthError.socialLoginDisabled
        #endif
    }

    // MARK: - Nonce helpers
    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            guard SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms) == errSecSuccess else {
                fatalError("SecRandomCopyBytes failed")
            }
            for r in randoms {
                guard remaining > 0 else { break }
                if Int(r) < charset.count { result.append(charset[Int(r)]); remaining -= 1 }
            }
        }
        return result
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension FirebaseAppleAuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = self.pendingNonce,
                  let continuation = self.pendingContinuation else {
                self.pendingContinuation?.resume(throwing: AuthError.unknown)
                self.pendingContinuation = nil
                self.activeController = nil
                return
            }
            self.pendingContinuation = nil
            self.activeController = nil
            do {
                let payload = try await self.completeFirebaseSignIn(credential: cred, nonce: nonce)
                continuation.resume(returning: payload)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            self.pendingContinuation?.resume(throwing: error)
            self.pendingContinuation = nil
            self.activeController = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension FirebaseAppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        // 1. Foreground-active scene key window
        if let fg = scenes.first(where: { $0.activationState == .foregroundActive }) {
            if let w = fg.keyWindow { return w }
            if let w = fg.windows.first { return w }
        }
        // 2. Any scene's key window
        for s in scenes { if let w = s.keyWindow { return w } }
        // 3. Any scene's first window
        for s in scenes { if let w = s.windows.first { return w } }
        // 4. Last resort
        if let scene = scenes.first {
            let w = UIWindow(windowScene: scene)
            w.makeKeyAndVisible()
            return w
        }
        return UIWindow()
    }
}

// MARK: - Payload
struct AuthPayload {
    let uid: String
    let email: String?
    let displayName: String
}