//
//  KeychainManager.swift
//  MyChannel
//
//  Created by AI Assistant on 11/2/25.
//  Secure API Key Storage - App Store Compliant
//

import Foundation
import Security

/// **SECURE API KEY STORAGE** 🔐
/// Stores sensitive API keys in iOS Keychain instead of Info.plist
/// App Store Requirement: API keys must not be extractable from binary
/// Note: Not @MainActor because Keychain operations are synchronous and thread-safe
final class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.mychannel.apikeys"
    
    private init() {}
    
    // MARK: - Save/Retrieve API Keys
    
    /// Save API key securely to Keychain
    func save(_ key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("❌ [Keychain] Failed to encode value")
            return false
        }
        
        // Delete existing key first
        delete(key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ [Keychain] Saved key: \(key)")
            return true
        } else {
            print("❌ [Keychain] Failed to save key \(key): \(status)")
            return false
        }
    }
    
    /// Retrieve API key from Keychain
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                print("⚠️ [Keychain] Failed to retrieve \(key): \(status)")
            }
            return nil
        }
        
        return value
    }
    
    /// Delete API key from Keychain
    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    /// Delete all keys (for testing)
    func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - API Key Constants

extension KeychainManager {
    enum APIKey: String {
        case anthropic = "anthropic_api_key"
        case openai = "openai_api_key"
        case googleCloud = "google_cloud_api_key"
        case googleCloudProject = "google_cloud_project_id"
        case tmdb = "tmdb_api_key"
        case channelBoostToken = "channelboost_token"
        case channelBoostURL = "channelboost_base_url"
        
        var value: String {
            // Try Keychain first
            if let keychainValue = KeychainManager.shared.get(self.rawValue) {
                return keychainValue
            }
            
            // Fallback to environment variables (build time only)
            if let envValue = ProcessInfo.processInfo.environment[self.rawValue.uppercased()] {
                return envValue
            }
            
            // Last resort: Check Info.plist (will be removed after migration)
            if let plistValue = Bundle.main.object(forInfoDictionaryKey: self.rawValue.uppercased()) as? String,
               !plistValue.isEmpty,
               !plistValue.hasPrefix("$") {
                return plistValue
            }
            
            print("⚠️ [KeychainManager] Missing API key: \(self.rawValue)")
            return ""
        }
    }
}

// MARK: - Migration Helper

extension KeychainManager {
    /// Migrate API keys from Info.plist to Keychain (run once on first launch)
    func migrateFromInfoPlist() {
        print("🔄 [Keychain] Starting API key migration...")
        
        let keys: [(APIKey, String)] = [
            (.anthropic, "ANTHROPIC_API_KEY"),
            (.openai, "OPENAI_API_KEY"),
            (.googleCloud, "GOOGLE_CLOUD_API_KEY"),
            (.googleCloudProject, "GOOGLE_CLOUD_PROJECT_ID"),
            (.tmdb, "TMDB_API_KEY"),
            (.channelBoostToken, "CHANNELBOOST_TOKEN"),
            (.channelBoostURL, "CHANNELBOOST_BASE_URL")
        ]
        
        var migratedCount = 0
        
        for (apiKey, plistKey) in keys {
            // Check if already in Keychain
            if get(apiKey.rawValue) != nil {
                continue
            }
            
            // Try to get from Info.plist
            if let plistValue = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String,
               !plistValue.isEmpty,
               !plistValue.hasPrefix("$") {
                
                if save(apiKey.rawValue, value: plistValue) {
                    migratedCount += 1
                    print("✅ [Keychain] Migrated: \(apiKey.rawValue)")
                }
            }
        }
        
        if migratedCount > 0 {
            print("✅ [Keychain] Migration complete: \(migratedCount) keys migrated")
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: "keychain_migration_complete")
        } else {
            print("ℹ️ [Keychain] No keys to migrate (already done or using env vars)")
        }
    }
}

