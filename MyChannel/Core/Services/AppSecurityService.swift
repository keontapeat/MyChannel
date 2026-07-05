#if canImport(IOSSecuritySuite)
import IOSSecuritySuite
#endif
#if canImport(TrustKit)
import TrustKit
#endif
import DeviceCheck
import Foundation

/// App security hardening: jailbreak detection, certificate pinning, App Attest.
@MainActor
final class AppSecurityService: ObservableObject {
    static let shared = AppSecurityService()

    @Published var isJailbroken = false
    @Published var isReverseEngineered = false
    @Published var isTrustKitConfigured = false

    private init() {}

    // MARK: - Configure on launch

    func configure() {
        checkDeviceIntegrity()
        configureTrustKit()
    }

    // MARK: - Jailbreak + Tampering Detection

    func checkDeviceIntegrity() {
        #if canImport(IOSSecuritySuite)
        isJailbroken = IOSSecuritySuite.amIJailbroken()
        isReverseEngineered = IOSSecuritySuite.amIReverseEngineered()

        if isJailbroken {
            print("⚠️ [Security] Jailbroken device detected")
            PostHogAnalyticsService.shared.track("security_jailbreak_detected", properties: [:])
        }
        if isReverseEngineered {
            print("⚠️ [Security] Reverse engineering detected")
        }
        #endif
    }

    // MARK: - Certificate Pinning (TrustKit)

    func configureTrustKit() {
        #if canImport(TrustKit) && !DEBUG
        // ⚠️ Certificate pinning is DISABLED until real SPKI pin hashes are configured.
        //
        // The previous configuration used PLACEHOLDER hashes ("AAAA…=", "BBBB…=") with
        // only ONE pin per domain. That caused two production-only failures:
        //   1. TrustKit throws "less than 2 pins (no backup pins)" at launch → the app
        //      crashed immediately on launch in Release builds (App Store rejection 2.1).
        //   2. Even without the crash, `kTSKEnforcePinning: true` with a fake hash blocks
        //      every TLS connection to api.mychannel.app → the app cannot reach its API.
        //
        // Pinning with wrong hashes is strictly worse than no pinning. The app remains
        // secure via HTTPS/ATS, Firebase Auth, and JWT request signing.
        //
        // TO RE-ENABLE SAFELY:
        //   1. Capture the REAL SubjectPublicKeyInfo (SPKI) SHA-256 hashes for the leaf/CA
        //      of each domain, PLUS a backup pin (e.g. a second CA or a future cert).
        //      `openssl s_client -connect api.mychannel.app:443 | openssl x509 -pubkey ...`
        //   2. Provide >= 2 valid base64 hashes per pinned domain.
        //   3. Test on a real device in Release before submitting.
        // Until then we MUST NOT call TrustKit.initSharedInstance with placeholder pins.
        print("ℹ️ [Security] Certificate pinning disabled (no valid SPKI pins configured)")
        isTrustKitConfigured = false
        #endif
    }

    // MARK: - App Attest (Apple DeviceCheck)

    func generateAttestationKey() async -> String? {
        guard DCAppAttestService.shared.isSupported else { return nil }
        do {
            let keyId = try await DCAppAttestService.shared.generateKey()
            return keyId
        } catch {
            print("⚠️ [AppAttest] Key generation failed: \(error.localizedDescription)")
            return nil
        }
    }

    func attestKey(_ keyId: String, challenge: Data) async -> Data? {
        do {
            let clientDataHash = Data(challenge)
            let attestation = try await DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash)
            return attestation
        } catch {
            print("⚠️ [AppAttest] Attestation failed: \(error.localizedDescription)")
            return nil
        }
    }

    func generateAssertion(keyId: String, requestData: Data) async -> Data? {
        do {
            return try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: requestData)
        } catch {
            print("⚠️ [AppAttest] Assertion failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Runtime checks

    var shouldBlockExecution: Bool {
        #if canImport(IOSSecuritySuite)
        return IOSSecuritySuite.amIJailbroken() && IOSSecuritySuite.amIReverseEngineered()
        #else
        return false
        #endif
    }
}
