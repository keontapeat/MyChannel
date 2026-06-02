//
//  AuthTokenProvider.swift
//  MyChannel
//
//  🔐 Central helper for attaching a verified Firebase ID token to outbound
//  requests against our money/payout Cloud Functions. The backend verifies this
//  token with the Admin SDK and enforces that the caller owns the resource, so
//  these endpoints can never be driven by an anonymous or spoofed caller.
//

import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum AuthTokenError: Error, LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You must be signed in to perform this action."
        }
    }
}

enum AuthTokenProvider {
    /// Returns a fresh Firebase ID token for the signed-in user.
    /// Throws `AuthTokenError.notSignedIn` when there is no authenticated user.
    static func idToken(forceRefresh: Bool = false) async throws -> String {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw AuthTokenError.notSignedIn
        }
        return try await user.getIDToken(forcingRefresh: forceRefresh)
        #else
        throw AuthTokenError.notSignedIn
        #endif
    }

    /// Convenience: attaches `Authorization: Bearer <token>` to a request.
    /// Throws if the user is not signed in.
    static func authorize(_ request: inout URLRequest, forceRefresh: Bool = false) async throws {
        let token = try await idToken(forceRefresh: forceRefresh)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
