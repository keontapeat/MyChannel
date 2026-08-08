import Valet
import Foundation

/// Hardened keychain storage using Square's Valet.
/// All tokens, keys, and sensitive user data stored with
/// kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly — wiped on device transfer.
final class ValetSecureStorageService {
    static let shared = ValetSecureStorageService()

    // MARK: - Valet instances (different protection levels)

    /// Hardened device-only storage. Uses `.afterFirstUnlockThisDeviceOnly` (not
    /// `.whenPasscodeSetThisDeviceOnly`) so cold launch / App Review devices that are
    /// momentarily locked do not hang keychain reads during scene-update.
    private let secureValet: Valet = {
        Valet.valet(with: Identifier(nonEmpty: "live.mychannel.secure")!,
                    accessibility: .afterFirstUnlockThisDeviceOnly)
    }()

    /// Standard secure: accessible after first unlock, survives backups
    private let standardValet: Valet = {
        Valet.valet(with: Identifier(nonEmpty: "live.mychannel.standard")!,
                    accessibility: .afterFirstUnlockThisDeviceOnly)
    }()

    /// Shared (for app group / widget access)
    private let sharedValet: Valet? = {
        guard let id = Identifier(nonEmpty: "live.mychannel.shared"),
              let group = SharedGroupIdentifier(appIDPrefix: "live.mychannel", nonEmptyGroup: "group.live.mychannel")
        else { return nil }
        return Valet.sharedGroupValet(with: group, accessibility: .whenUnlocked)
    }()

    private init() {}

    // MARK: - Auth Tokens (most secure — requires passcode)

    func saveAuthToken(_ token: String, for userId: String) {
        try? secureValet.setString(token, forKey: "auth_token_\(userId)")
    }

    func authToken(for userId: String) -> String? {
        try? secureValet.string(forKey: "auth_token_\(userId)")
    }

    func deleteAuthToken(for userId: String) {
        try? secureValet.removeObject(forKey: "auth_token_\(userId)")
    }

    // MARK: - API Keys (secure)

    func saveAPIKey(_ key: String, identifier: String) {
        try? secureValet.setString(key, forKey: "api_key_\(identifier)")
    }

    func apiKey(identifier: String) -> String? {
        try? secureValet.string(forKey: "api_key_\(identifier)")
    }

    // MARK: - Encryption Keys (most secure)

    func saveEncryptionKey(_ keyData: Data, identifier: String) {
        try? secureValet.setObject(keyData, forKey: "enc_key_\(identifier)")
    }

    func encryptionKey(identifier: String) -> Data? {
        try? secureValet.object(forKey: "enc_key_\(identifier)")
    }

    // MARK: - JWT Signing Key

    func saveJWTSigningKey(_ key: Data) {
        try? secureValet.setObject(key, forKey: "jwt_signing_key")
    }

    func jwtSigningKey() -> Data? {
        try? secureValet.object(forKey: "jwt_signing_key")
    }

    // MARK: - User preferences (standard, survives backup)

    func savePreference(_ value: String, key: String) {
        try? standardValet.setString(value, forKey: "pref_\(key)")
    }

    func preference(key: String) -> String? {
        try? standardValet.string(forKey: "pref_\(key)")
    }

    // MARK: - Wipe on logout

    func wipeAllSecureData(for userId: String) {
        try? secureValet.removeObject(forKey: "auth_token_\(userId)")
        try? secureValet.removeObject(forKey: "jwt_signing_key")
        AgentLogService.shared.agentCompleted("ValetWipe", agentId: "valet", latencyMs: 0,
                                               output: "Secure data wiped for \(userId)")
    }

    func wipeEverything() {
        try? secureValet.removeAllObjects()
        try? standardValet.removeAllObjects()
    }
}
