#if canImport(KeychainSwift)
import KeychainSwift
#endif
import Foundation

/// Secure Keychain Storage
/// Type-safe wrappers around KeychainAccess for auth tokens, API keys, user secrets.
final class SecureKeychainService {
    static let shared = SecureKeychainService()

    private let serviceID = "live.mychannel.app"

    #if canImport(KeychainSwift)
    private lazy var keychain: KeychainSwift = {
        let k = KeychainSwift(keyPrefix: serviceID + ".")
        k.synchronizable = false
        return k
    }()
    #endif

    private init() {}

    func set(_ value: String, forKey key: String) {
        #if canImport(KeychainSwift)
        keychain.set(value, forKey: key)
        #else
        UserDefaults.standard.set(value, forKey: "keychain_\(key)")
        #endif
    }

    func get(_ key: String) -> String? {
        #if canImport(KeychainSwift)
        return keychain.get(key)
        #else
        return UserDefaults.standard.string(forKey: "keychain_\(key)")
        #endif
    }

    func remove(_ key: String) {
        #if canImport(KeychainSwift)
        keychain.delete(key)
        #else
        UserDefaults.standard.removeObject(forKey: "keychain_\(key)")
        #endif
    }

    func removeAll() {
        #if canImport(KeychainSwift)
        keychain.clear()
        #endif
    }

    // MARK: - Convenience Keys
    var authToken: String? {
        get { get("auth_token") }
        set { newValue == nil ? remove("auth_token") : set(newValue!, forKey: "auth_token") }
    }

    var stripePublishableKey: String? {
        get { get("stripe_pk") }
        set { newValue == nil ? remove("stripe_pk") : set(newValue!, forKey: "stripe_pk") }
    }

    var revenueCatAPIKey: String? {
        get { get("revenuecat_key") }
        set { newValue == nil ? remove("revenuecat_key") : set(newValue!, forKey: "revenuecat_key") }
    }
}
