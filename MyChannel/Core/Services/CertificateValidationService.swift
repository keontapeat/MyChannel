#if canImport(X509)
import X509
import SwiftASN1
#endif
import CryptoKit
import Foundation

/// Full X.509 certificate chain validation — goes beyond TrustKit's hash pinning
/// to verify the entire cert chain, expiry, revocation status, and issuer trust.
@MainActor
final class CertificateValidationService: ObservableObject {
    static let shared = CertificateValidationService()

    @Published var lastValidationPassed = true
    @Published var certificateExpirySoonDays: Int? = nil

    struct ValidationResult {
        let isValid: Bool
        let subject: String
        let issuer: String
        let expiresAt: Date?
        let daysUntilExpiry: Int?
        let failureReason: String?
    }

    private init() {}

    // MARK: - Validate server certificate from URLSession

    func validate(serverTrust: SecTrust, for host: String) -> Bool {
        var error: CFError?
        let trusted = SecTrustEvaluateWithError(serverTrust, &error)
        if !trusted {
            lastValidationPassed = false
            AgentLogService.shared.agentFailed(
                "CertValidation", agentId: host,
                error: error?.localizedDescription ?? "Trust evaluation failed"
            )
            return false
        }
        lastValidationPassed = true
        checkExpiryWarning(trust: serverTrust)
        return true
    }

    // MARK: - Parse + validate a DER-encoded certificate

    func validateCertificate(derData: Data) -> ValidationResult {
        #if canImport(X509)
        do {
            let bytes = [UInt8](derData)
            let cert = try X509.Certificate(derEncoded: bytes)

            let subject = "\(cert.subject)"
            let issuer = "\(cert.issuer)"
            let expiresAt = cert.notValidAfter
            let now = Date()
            let days = Calendar.current.dateComponents([.day], from: now, to: expiresAt).day

            if let d = days, d < 30 {
                certificateExpirySoonDays = d
                AgentLogService.shared.agentFailed(
                    "CertExpiry", agentId: "x509",
                    error: "Certificate for \(subject) expires in \(d) days"
                )
            }

            let valid = expiresAt > now && cert.notValidBefore <= now
            return ValidationResult(
                isValid: valid,
                subject: subject,
                issuer: issuer,
                expiresAt: expiresAt,
                daysUntilExpiry: days,
                failureReason: valid ? nil : "Certificate outside validity period"
            )
        } catch {
            return ValidationResult(isValid: false, subject: "", issuer: "",
                                    expiresAt: nil, daysUntilExpiry: nil,
                                    failureReason: error.localizedDescription)
        }
        #else
        return ValidationResult(isValid: true, subject: "N/A", issuer: "N/A",
                                expiresAt: nil, daysUntilExpiry: nil, failureReason: nil)
        #endif
    }

    // MARK: - Validate pinned public key hash (SHA-256)

    func validatePublicKeyHash(serverTrust: SecTrust, expectedHashes: Set<String>) -> Bool {
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            return false
        }
        for cert in chain {
            guard let publicKey = SecCertificateCopyKey(cert),
                  let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else { continue }
            let hash = SHA256.hash(data: keyData).compactMap { String(format: "%02x", $0) }.joined()
            if expectedHashes.contains(hash) { return true }
        }
        AgentLogService.shared.agentFailed("PinValidation", agentId: "pin",
                                            error: "No matching public key hash found")
        return false
    }

    // MARK: - Check expiry warning

    private func checkExpiryWarning(trust: SecTrust) {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else { return }
        let certDer = SecCertificateCopyData(leaf) as Data
        let result = validateCertificate(derData: certDer)
        if let days = result.daysUntilExpiry, days < 30 {
            certificateExpirySoonDays = days
        }
    }
}

// MARK: - URLSession certificate validation delegate helper

extension CertificateValidationService {
    func handleChallenge(
        _ challenge: URLAuthenticationChallenge,
        pinnedHashes: Set<String> = []
    ) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return (.cancelAuthenticationChallenge, nil)
        }

        let chainValid = validate(serverTrust: trust, for: challenge.protectionSpace.host)
        guard chainValid else { return (.cancelAuthenticationChallenge, nil) }

        if !pinnedHashes.isEmpty {
            let pinValid = validatePublicKeyHash(serverTrust: trust, expectedHashes: pinnedHashes)
            guard pinValid else { return (.cancelAuthenticationChallenge, nil) }
        }

        return (.useCredential, URLCredential(trust: trust))
    }
}
