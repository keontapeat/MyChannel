//
//  DataPersistenceService.swift
//  MyChannel
//
//  BULLETPROOF DATA PERSISTENCE - Never lose user data again!
//  Dual-layer: UserDefaults (local) + Firestore (cloud)
//  Auto-retry, transaction logs, integrity checks
//

import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class DataPersistenceService: ObservableObject {
    static let shared = DataPersistenceService()
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [PersistenceError] = []
    
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    // Transaction log for debugging failed saves
    private var transactionLog: [TransactionLogEntry] = []
    private let maxLogSize = 100
    
    private init() {
        setupPeriodicSync()
        setupDataIntegrityChecks()
    }
    
    // MARK: - Transaction Logging
    
    struct TransactionLogEntry: Codable {
        let id: String
        let operation: String
        let dataType: String
        let timestamp: Date
        let success: Bool
        let error: String?
        
        init(operation: String, dataType: String, success: Bool, error: String? = nil) {
            self.id = UUID().uuidString
            self.operation = operation
            self.dataType = dataType
            self.timestamp = Date()
            self.success = success
            self.error = error
        }
    }
    
    private func logTransaction(_ entry: TransactionLogEntry) {
        transactionLog.append(entry)
        
        // Keep log size under control
        if transactionLog.count > maxLogSize {
            transactionLog.removeFirst(transactionLog.count - maxLogSize)
        }
        
        // Save log to UserDefaults
        if let encoded = try? encoder.encode(transactionLog) {
            userDefaults.set(encoded, forKey: "transaction_log")
        }
        
        // Print for debugging
        if !entry.success {
            print("🚨 TRANSACTION FAILED: \(entry.operation) - \(entry.dataType) - \(entry.error ?? "Unknown error")")
        }
    }
    
    // MARK: - Dual-Layer Save (Local + Cloud)
    
    /// Save data with automatic retry and fallback
    func saveDualLayer<T: Codable>(_ data: T, key: String, collectionPath: String? = nil, docId: String? = nil) async throws {
        var lastError: Error?
        
        // Try up to 3 times with exponential backoff
        for attempt in 1...3 {
            do {
                // 1. Save locally first (instant)
                try saveToUserDefaults(data, key: key)
                
                // 2. Save to cloud (with retry)
                if let collectionPath = collectionPath, let docId = docId {
                    #if canImport(FirebaseFirestore)
                    try await saveToFirestore(data, collectionPath: collectionPath, docId: docId)
                    #endif
                }
                
                // Success!
                logTransaction(TransactionLogEntry(operation: "saveDualLayer", dataType: key, success: true))
                return
                
            } catch {
                lastError = error
                logTransaction(TransactionLogEntry(operation: "saveDualLayer", dataType: key, success: false, error: error.localizedDescription))
                
                if attempt < 3 {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    print("⚠️ Retry attempt \(attempt + 1) for \(key)")
                }
            }
        }
        
        // All retries failed
        syncErrors.append(PersistenceError(key: key, error: lastError?.localizedDescription ?? "Unknown error", timestamp: Date()))
        throw lastError ?? NSError(domain: "DataPersistence", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save after 3 attempts"])
    }
    
    /// Load data with fallback (cloud → local → default)
    func loadDualLayer<T: Codable>(_ type: T.Type, key: String, collectionPath: String? = nil, docId: String? = nil) async throws -> T? {
        // Try Firestore first (most up-to-date)
        if let collectionPath = collectionPath, let docId = docId {
            #if canImport(FirebaseFirestore)
            if let cloudData = try? await loadFromFirestore(type, collectionPath: collectionPath, docId: docId) {
                // Update local cache
                try? saveToUserDefaults(cloudData, key: key)
                return cloudData
            }
            #endif
        }
        
        // Fallback to local
        return try? loadFromUserDefaults(type, key: key)
    }
    
    // MARK: - UserDefaults Operations
    
    private func saveToUserDefaults<T: Codable>(_ data: T, key: String) throws {
        let encoded = try encoder.encode(data)
        userDefaults.set(encoded, forKey: key)
        userDefaults.synchronize() // Force immediate write
    }
    
    private func loadFromUserDefaults<T: Codable>(_ type: T.Type, key: String) throws -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Firestore Operations
    
    #if canImport(FirebaseFirestore)
    private func saveToFirestore<T: Codable>(_ data: T, collectionPath: String, docId: String) async throws {
        let encoded = try encoder.encode(data)
        let dict = try JSONSerialization.jsonObject(with: encoded, options: []) as? [String: Any] ?? [:]
        
        try await db.collection(collectionPath).document(docId).setData(dict, merge: true)
    }
    
    private func loadFromFirestore<T: Codable>(_ type: T.Type, collectionPath: String, docId: String) async throws -> T? {
        let doc = try await db.collection(collectionPath).document(docId).getDocument()
        
        guard let data = doc.data() else {
            return nil
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
        return try decoder.decode(T.self, from: jsonData)
    }
    #endif
    
    // MARK: - Periodic Sync
    
    private func setupPeriodicSync() {
        // Sync every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncAllData()
            }
        }
    }
    
    private func syncAllData() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        print("🔄 Starting periodic data sync...")
        
        // Sync user collections (watch later, liked, etc.)
        if let userId = AuthenticationManager.shared.currentUser?.id {
            do {
                // Get local data
                if let localData: [String: Any] = userDefaults.dictionary(forKey: "userData_\(userId)") {
                    // Sync to Firestore
                    #if canImport(FirebaseFirestore)
                    try await db.collection("userCollections").document(userId).setData(localData, merge: true)
                    #endif
                }
                
                lastSyncDate = Date()
                print("✅ Sync completed successfully")
            } catch {
                print("🚨 Sync failed: \(error)")
                syncErrors.append(PersistenceError(key: "periodic_sync", error: error.localizedDescription, timestamp: Date()))
            }
        }
        
        isSyncing = false
    }
    
    // MARK: - Data Integrity Checks
    
    private func setupDataIntegrityChecks() {
        // Run integrity check on app launch
        Task {
            await checkDataIntegrity()
        }
    }
    
    private func checkDataIntegrity() async {
        print("🔍 Running data integrity check...")
        
        // Check if critical data is present
        let criticalKeys = [
            "hasLaunchedBefore",
            "appState_preferences",
            "appState_settings"
        ]
        
        var missingKeys: [String] = []
        for key in criticalKeys {
            if userDefaults.object(forKey: key) == nil {
                missingKeys.append(key)
            }
        }
        
        if !missingKeys.isEmpty {
            print("⚠️ Missing critical data: \(missingKeys)")
            // Attempt to restore from cloud
            await restoreMissingData(keys: missingKeys)
        } else {
            print("✅ Data integrity check passed")
        }
    }
    
    private func restoreMissingData(keys: [String]) async {
        // Try to restore from Firestore
        guard let userId = AuthenticationManager.shared.currentUser?.id else { return }
        
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("userCollections").document(userId).getDocument()
            if let data = doc.data() {
                for key in keys {
                    if let value = data[key] {
                        userDefaults.set(value, forKey: key)
                        print("✅ Restored \(key) from cloud")
                    }
                }
            }
        } catch {
            print("🚨 Failed to restore data: \(error)")
        }
        #endif
    }
    
    // MARK: - Backup System
    
    func createBackup() async throws {
        print("💾 Creating full data backup...")
        
        guard let userId = AuthenticationManager.shared.currentUser?.id else {
            throw NSError(domain: "DataPersistence", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        // Collect all user data
        var backup: [String: Any] = [:]
        
        // Get all keys for this user
        for (key, value) in userDefaults.dictionaryRepresentation() {
            if key.contains(userId) || key.hasPrefix("userData") || key.hasPrefix("user_") {
                backup[key] = value
            }
        }
        
        backup["backup_timestamp"] = Date().timeIntervalSince1970
        backup["backup_version"] = "1.0"
        
        // Save to Firestore backups collection
        #if canImport(FirebaseFirestore)
        let backupId = "backup_\(Int(Date().timeIntervalSince1970))"
        try await db.collection("backups").document(userId).collection("snapshots").document(backupId).setData(backup)
        
        print("✅ Backup created: \(backupId)")
        #endif
        
        logTransaction(TransactionLogEntry(operation: "createBackup", dataType: "full", success: true))
    }
    
    func restoreFromBackup(backupId: String) async throws {
        print("📥 Restoring from backup: \(backupId)")
        
        guard let userId = AuthenticationManager.shared.currentUser?.id else {
            throw NSError(domain: "DataPersistence", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])
        }
        
        #if canImport(FirebaseFirestore)
        let doc = try await db.collection("backups").document(userId).collection("snapshots").document(backupId).getDocument()
        
        guard let backup = doc.data() else {
            throw NSError(domain: "DataPersistence", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backup not found"])
        }
        
        // Restore all data
        for (key, value) in backup {
            if key != "backup_timestamp" && key != "backup_version" {
                userDefaults.set(value, forKey: key)
            }
        }
        
        userDefaults.synchronize()
        print("✅ Data restored from backup")
        #endif
        
        logTransaction(TransactionLogEntry(operation: "restoreBackup", dataType: "full", success: true))
    }
    
    // MARK: - Error Tracking
    
    struct PersistenceError: Identifiable {
        let id = UUID()
        let key: String
        let error: String
        let timestamp: Date
    }
    
    func clearErrors() {
        syncErrors.removeAll()
    }
    
    func getRecentErrors(limit: Int = 10) -> [PersistenceError] {
        return Array(syncErrors.suffix(limit))
    }
    
    func getTransactionLog(limit: Int = 20) -> [TransactionLogEntry] {
        return Array(transactionLog.suffix(limit))
    }
}

