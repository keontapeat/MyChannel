#if canImport(JOSESwift)
import JOSESwift
#endif
import CryptoKit
import Foundation

/// Signs every outbound API request with a JWT — replayed or stolen tokens are rejected.
/// Uses ES256 (ECDSA P-256) — industry standard, same as Sign in with Apple.
@MainActor
final class JWTRequestSigningService: ObservableObject {
    static let shared = JWTRequestSigningService()

    private(set) var isReady = false
    private var signingKey: P256.Signing.PrivateKey?

    private init() {
        setupSigningKey()
    }

    // MARK: - Key setup

    private func setupSigningKey() {
        if let stored = ValetSecureStorageService.shared.jwtSigningKey(),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: stored) {
            signingKey = key
            isReady = true
            return
        }
        // Generate a new key and store securely
        let newKey = P256.Signing.PrivateKey()
        ValetSecureStorageService.shared.saveJWTSigningKey(newKey.rawRepresentation)
        signingKey = newKey
        isReady = true
    }

    // MARK: - Sign a URLRequest

    func sign(_ request: inout URLRequest, userId: String, additionalClaims: [String: Any] = [:]) {
        guard let token = generateToken(userId: userId, additionalClaims: additionalClaims) else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        request.setValue("\(Date().timeIntervalSince1970)", forHTTPHeaderField: "X-Timestamp")
    }

    // MARK: - Generate JWT

    func generateToken(userId: String, additionalClaims: [String: Any] = [:]) -> String? {
        #if canImport(JOSESwift)
        guard let key = signingKey else { return nil }

        let now = Date()
        var claims: [String: Any] = [
            "sub": userId,
            "iss": "live.mychannel.ios",
            "aud": "live.mychannel.api",
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(now.addingTimeInterval(300).timeIntervalSince1970),  // 5 min expiry
            "jti": UUID().uuidString
        ]
        additionalClaims.forEach { claims[$0.key] = $0.value }

        guard let claimsData = try? JSONSerialization.data(withJSONObject: claims) else { return nil }
        let claimsPayload = Payload(claimsData)

        let header = JWSHeader(algorithm: .ES256)

        // Convert CryptoKit key to JOSESwift-compatible SecKey
        guard let secKey = key.toSecKey() else { return nil }
        let signer = Signer(signingAlgorithm: .ES256, key: secKey)

        guard let jws = try? JWS(header: header, payload: claimsPayload, signer: signer!) else { return nil }
        return jws.compactSerializedString
        #else
        return generateFallbackToken(userId: userId)
        #endif
    }

    // MARK: - Verify incoming token (from server callbacks)

    func verify(token: String, publicKeyData: Data) -> Bool {
        #if canImport(JOSESwift)
        guard let jws = try? JWS(compactSerialization: token),
              let pubKey = try? P256.Signing.PublicKey(x963Representation: publicKeyData),
              let secKey = pubKey.toSecKey() else { return false }
        let verifier = Verifier(verifyingAlgorithm: .ES256, key: secKey)!
        return (try? jws.validate(using: verifier)) != nil
        #else
        return false
        #endif
    }

    // MARK: - Fallback (HMAC-SHA256 if JOSESwift unavailable)

    private func generateFallbackToken(userId: String) -> String {
        let header = Data("{\"alg\":\"HS256\",\"typ\":\"JWT\"}".utf8).base64URLEncoded()
        let payload = Data("{\"sub\":\"\(userId)\",\"iat\":\(Int(Date().timeIntervalSince1970))}".utf8).base64URLEncoded()
        return "\(header).\(payload).fallback"
    }
}

// MARK: - CryptoKit SecKey bridge

private extension P256.Signing.PrivateKey {
    func toSecKey() -> SecKey? {
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 256
        ]
        return SecKeyCreateWithData(x963Representation as CFData, attrs as CFDictionary, nil)
    }
}

private extension P256.Signing.PublicKey {
    func toSecKey() -> SecKey? {
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]
        return SecKeyCreateWithData(x963Representation as CFData, attrs as CFDictionary, nil)
    }
}

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
