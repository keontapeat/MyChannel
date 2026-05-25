//
//  AdvancedAuthService.swift
//  MyChannel
//
//  Phase 188: Advanced Auth & Passkeys.
//  Passkey login, biometric MFA, device trust.
//  Uses `mychannel-auth` Cloud Run.
//

import Foundation
import AuthenticationServices
import LocalAuthentication

// MARK: - Models

struct TrustedDevice: Codable, Identifiable {
    let id: String
    let name: String
    let model: String
    let lastUsed: Date
    let isCurrent: Bool
}

struct MFAMethod: Codable, Identifiable {
    let id: String
    let type: String
    let label: String
    let isEnabled: Bool
    let enrolledAt: Date
}

// MARK: - Service

@MainActor
final class AdvancedAuthService: ObservableObject {
    static let shared = AdvancedAuthService()
    private init() {}

    @Published private(set) var trustedDevices: [TrustedDevice] = []
    @Published private(set) var mfaMethods: [MFAMethod] = []
    @Published var isPasskeyAvailable: Bool = false

    func checkPasskeySupport() {
        guard AppConfig.Features.enableAdvancedAuth else { return }
        if #available(iOS 16.0, *) { isPasskeyAvailable = true }
    }

    func authenticateWithBiometrics() async throws -> Bool {
        guard AppConfig.Features.enableAdvancedAuth else { return true }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return false }
        return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to MyChannel")
    }

    func registerPasskey(uid: String) async throws {
        guard AppConfig.Features.enableAdvancedAuth else { return }
        struct Request: Encodable { let task: String; let uid: String }
        struct Raw: Decodable { let challenge: String?; let rp_id: String? }
        let _: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Request(task: "register_passkey", uid: uid)
        )
    }

    func loadTrustedDevices(uid: String) async throws {
        guard AppConfig.Features.enableAdvancedAuth else { return }
        struct Request: Encodable { let task: String; let uid: String }
        struct RawDevice: Decodable { let id: String; let name: String; let model: String; let last_used: String; let current: Bool }
        struct Raw: Decodable { let devices: [RawDevice]? }
        let r: Raw = try await CloudRunAgentRouter.post(
            .myChannelAuth, path: "/predict",
            body: Request(task: "trusted_devices", uid: uid)
        )
        trustedDevices = (r.devices ?? []).map {
            TrustedDevice(id: $0.id, name: $0.name, model: $0.model, lastUsed: Date(), isCurrent: $0.current)
        }
    }

    func revokeDevice(deviceId: String) async throws {
        guard AppConfig.Features.enableAdvancedAuth else { return }
        trustedDevices.removeAll { $0.id == deviceId }
    }
}
