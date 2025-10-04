import Foundation
import Security
import CommonCrypto

final class SSLPinningDelegate: NSObject, URLSessionDelegate {
    private let pins: [String]
    private let allowInDebug: Bool

    init(pins: [String], allowInDebug: Bool) {
        self.pins = pins
        self.allowInDebug = allowInDebug
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        #if DEBUG
        if allowInDebug {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        #endif

        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        SecTrustSetPolicies(trust, policy)

        var result = SecTrustResultType.invalid
        guard SecTrustEvaluate(trust, &result) == errSecSuccess else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let cert = SecTrustGetCertificateAtIndex(trust, 0),
              let spkiData = spki(from: cert) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let hash = sha256(spkiData)
        if pins.contains(hash) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func spki(from cert: SecCertificate) -> Data? {
        if #available(iOS 12.0, *) {
            if let key = SecCertificateCopyKey(cert),
               let data = SecKeyCopyExternalRepresentation(key, nil) as Data? {
                return data
            }
        }
        return SecCertificateCopyData(cert) as Data
    }

    private func sha256(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { raw in
            _ = CC_SHA256(raw.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
    }
}
