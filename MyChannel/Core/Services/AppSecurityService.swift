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
        let trustKitConfig: [String: Any] = [
            kTSKSwizzleNetworkDelegates: false,
            kTSKPinnedDomains: [
                "api.mychannel.app": [
                    kTSKIncludeSubdomains: true,
                    kTSKEnforcePinning: true,
                    kTSKPublicKeyHashes: [
                        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
                    ]
                ],
                "firestore.googleapis.com": [
                    kTSKIncludeSubdomains: true,
                    kTSKEnforcePinning: false,
                    kTSKPublicKeyHashes: [
                        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                    ]
                ]
            ]
        ]
        TrustKit.initSharedInstance(withConfiguration: trustKitConfig)
        isTrustKitConfigured = true
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
