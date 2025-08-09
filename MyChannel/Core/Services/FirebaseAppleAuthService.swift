import Foundation
import AuthenticationServices
import CryptoKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
final class FirebaseAppleAuthService: NSObject {
    static let shared = FirebaseAppleAuthService()
    private override init() {}

    private var currentNonce: String?

    var isAvailable: Bool {
        #if canImport(FirebaseAuth)
        return true
        #else
        return false
        #endif
    }

    func signIn() async throws -> AuthPayload {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleAuthControllerDelegate { [weak self] result in
                switch result {
                case .success(let credential):
                    Task { @MainActor in
                        do {
                            let payload = try await self?.completeFirebaseSignIn(with: credential, nonce: nonce)
                            if let payload { continuation.resume(returning: payload) }
                            else { continuation.resume(throwing: AuthError.unknown) }
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            delegate.retainSelf = delegate
            controller.performRequests()
        }
    }

    private func completeFirebaseSignIn(with credential: ASAuthorizationAppleIDCredential, nonce: String) async throws -> AuthPayload {
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

        let firebaseUser = result.user
        let email = firebaseUser.email ?? credential.email
        let fullName = credential.fullName?.formatted() ?? firebaseUser.displayName ?? "Apple User"
        let uid = firebaseUser.uid

        return AuthPayload(uid: uid, email: email, displayName: fullName)
        #else
        throw AuthError.socialLoginDisabled
        #endif
    }

    // MARK: - Helpers (Nonce)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
}

// MARK: - Delegate + Presentation
private final class AppleAuthControllerDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void
    var retainSelf: AppleAuthControllerDelegate?

    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let cred = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(cred))
        } else {
            completion(.failure(AuthError.unknown))
        }
        retainSelf = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
        retainSelf = nil
    }
}

// MARK: - Payload
struct AuthPayload {
    let uid: String
    let email: String?
    let displayName: String
}