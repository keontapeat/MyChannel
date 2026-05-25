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
    // Cached on @MainActor before performRequests() to avoid DispatchQueue.main.sync deadlock on iPadOS 26+
    nonisolated(unsafe) private var _anchorWindow: UIWindow?

    var isAvailable: Bool {
        #if canImport(FirebaseAuth)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Nonce for SwiftUI SignInWithAppleButton flow

    /// Returns (rawNonce, hashedNonce). Pass hashedNonce to the ASAuthorizationAppleIDRequest,
    /// and rawNonce to handleCredential(_, rawNonce:) in the completion handler.
    /// This avoids shared mutable state and eliminates the iPad race condition.
    func generateNoncePair() -> (raw: String, hashed: String) {
        let raw = randomNonceString()
        return (raw, sha256(raw))
    }

    /// 🔥 iPad-Safe: One-shot atomic nonce holder used by SwiftUI SignInWithAppleButton flow.
    /// Stores the rawNonce between onRequest and onCompletion across SwiftUI render passes.
    /// Returns the hashed nonce to use in the request.
    func captureNonce() -> String {
        let raw = randomNonceString()
        AppleSignInNonceHolder.shared.rawNonce = raw
        return sha256(raw)
    }

    /// Consumes and returns the previously captured raw nonce. Returns nil if no nonce captured.
    func consumeNonce() -> String? {
        let raw = AppleSignInNonceHolder.shared.rawNonce
        AppleSignInNonceHolder.shared.rawNonce = nil
        return raw
    }

    /// Legacy: stores nonce in shared state. Prefer generateNoncePair() + handleCredential(_:rawNonce:).
    func prepareNonce() -> String {
        let nonce = randomNonceString()
        pendingNonce = nonce
        return sha256(nonce)
    }

    /// iPad-safe: accepts the raw nonce directly instead of reading shared state.
    func handleCredential(_ credential: ASAuthorizationAppleIDCredential, rawNonce: String) async throws -> AuthPayload {
        return try await completeFirebaseSignIn(credential: credential, nonce: rawNonce)
    }

    /// Legacy: reads nonce from shared state. Prefer handleCredential(_:rawNonce:).
    func handleCredential(_ credential: ASAuthorizationAppleIDCredential) async throws -> AuthPayload {
        guard let nonce = pendingNonce else {
            print("🍎 [Apple Sign In] ERROR: pendingNonce is nil — race condition on iPad")
            throw AuthError.unknown
        }
        pendingNonce = nil
        return try await completeFirebaseSignIn(credential: credential, nonce: nonce)
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

        self._anchorWindow = self.resolveKeyWindow()
        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            self.pendingContinuation = continuation
            self.activeController = controller
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Window resolver
    // 🔥 iPad-Safe: Walks the presented-view-controller chain so Apple's
    // authorization sheet anchors to the *topmost* presented window (e.g. a sheet
    // or fullScreenCover), not the root window which on iPad with an active sheet
    // is the WRONG window and causes the Apple Sign In sheet to fail to appear or
    // appear behind other UI.
    //
    // Reference: Apple recommends returning the window that contains the view
    // initiating the auth request, not just `keyWindow`.
    // https://developer.apple.com/documentation/authenticationservices/asauthorizationcontrollerpresentationcontextproviding/presentationanchor(for:)
    private func resolveKeyWindow() -> UIWindow? {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        // Prefer the foreground active scene's key window
        let foregroundScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let scene = foregroundScene else { return nil }

        // Find the key window in this scene
        let keyWindow = scene.keyWindow
            ?? scene.windows.first(where: { $0.isKeyWindow })
            ?? scene.windows.first

        // Walk the presented-view-controller chain to find the topmost window.
        // On iPad with an active .sheet, the sheet's view lives in the same window
        // but with a presented view controller chain on top of the root. We need
        // the window that contains the topmost VC so Apple's auth sheet presents
        // from the correct anchor.
        if let window = keyWindow, let root = window.rootViewController {
            var top: UIViewController = root
            while let presented = top.presentedViewController {
                top = presented
            }
            // Return the window of the topmost presented controller (may be a
            // different window if SwiftUI created a fresh UIWindow for the sheet,
            // which iPadOS 18 sometimes does for form sheets).
            return top.view.window ?? window
        }

        // Fallback: create a window in the active scene
        if keyWindow == nil {
            let w = UIWindow(windowScene: scene)
            w.makeKeyAndVisible()
            return w
        }
        return keyWindow
        #else
        return nil
        #endif
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
            self._anchorWindow = nil
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
            self._anchorWindow = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension FirebaseAppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the window cached on @MainActor before performRequests() was called.
        // This avoids DispatchQueue.main.sync, which deadlocks on iPadOS 26+ because Apple
        // now calls presentationAnchor synchronously on the main thread before performRequests() returns.
        return _anchorWindow ?? UIWindow()
    }
}

// MARK: - Payload
struct AuthPayload {
    let uid: String
    let email: String?
    let displayName: String
}

// MARK: - 🔥 iPad-Safe Nonce Holder
// Class-based storage that survives SwiftUI render passes and avoids @State capture issues
// in SignInWithAppleButton onRequest/onCompletion closures. This is the iPad bug fix.
final class AppleSignInNonceHolder: @unchecked Sendable {
    static let shared = AppleSignInNonceHolder()
    private let lock = NSLock()
    private var _rawNonce: String?

    private init() {}

    var rawNonce: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _rawNonce
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _rawNonce = newValue
        }
    }
}