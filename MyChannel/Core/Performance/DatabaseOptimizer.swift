//
//  DatabaseOptimizer.swift
//  MyChannel
//
//  Database performance optimization for Firestore and local storage
//

import Foundation
import Combine
import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Database Optimizer
class DatabaseOptimizer: ObservableObject {
    static let shared = DatabaseOptimizer()
    
    @Published var queryPerformance: QueryPerformanceMetrics = QueryPerformanceMetrics()
    
    private var queryCache = NSCache<NSString, CachedQueryResult>()
    private var batchOperations: [BatchOperation] = []
    private let batchTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listeners: [String: ListenerRegistration] = [:]
    #endif
    
    private init() {
        setupQueryCache()
        setupBatchProcessing()
        optimizeFirestoreSettings()
    }
    
    // MARK: - Firestore Optimization
    private func optimizeFirestoreSettings() {
        #if canImport(FirebaseFirestore)
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = 100 * 1024 * 1024 // 100MB cache
        db.settings = settings
        #endif
    }
    
    // MARK: - Query Cache Setup
    private func setupQueryCache() {
        queryCache.countLimit = 100
        queryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Optimized Query Methods
    func optimizedQuery<T: Codable>(
        collection: String,
        filters: [QueryFilter] = [],
        orderBy: String? = nil,
        limit: Int? = nil,
        cacheFirst: Bool = true,
        type: T.Type
    ) async throws -> [T] {
        
        let cacheKey = generateCacheKey(collection: collection, filters: filters, orderBy: orderBy, limit: limit)
        
        // Check cache first if requested
        if cacheFirst, let cached = getCachedResult(for: cacheKey) {
            if !cached.isExpired {
                return try cached.decode(as: type)
            }
        }
        
        #if canImport(FirebaseFirestore)
        let startTime = Date()
        
        var query: Query = db.collection(collection)
        
        // Apply filters efficiently
        for filter in filters {
            query = applyFilter(query, filter: filter)
        }
        
        // Apply ordering
        if let orderBy = orderBy {
            query = query.order(by: orderBy, descending: true)
        }
        
        // Apply limit
        if let limit = limit {
            query = query.limit(to: limit)
        }
        
        let snapshot = try await query.getDocuments(source: .default)
        let queryTime = Date().timeIntervalSince(startTime)
        
        // Update performance metrics
        updateQueryMetrics(queryTime: queryTime, documentCount: snapshot.documents.count)
        
        let results: [T] = try snapshot.documents.compactMap { doc in
            try doc.data(as: type)
        }
        
        // Cache the results
        cacheResult(results, for: cacheKey)
        
        return results
        #else
        return []
        #endif
    }
    
    #if canImport(FirebaseFirestore)
    private func applyFilter(_ query: Query, filter: QueryFilter) -> Query {
        switch filter.operation {
        case .equals:
            return query.whereField(filter.field, isEqualTo: filter.value)
        case .greaterThan:
            return query.whereField(filter.field, isGreaterThan: filter.value)
        case .lessThan:
            return query.whereField(filter.field, isLessThan: filter.value)
        case .arrayContains:
            return query.whereField(filter.field, arrayContains: filter.value)
        case .isIn:
            return query.whereField(filter.field, in: filter.value as! [Any])
        }
    }
    #endif
    
    // MARK: - Batch Operations
    private func setupBatchProcessing() {
        batchTimer
            .sink { [weak self] _ in
                self?.processBatchOperations()
            }
            .store(in: &cancellables)
    }
    
    func addToBatch(_ operation: BatchOperation) {
        batchOperations.append(operation)
        
        // Process immediately if batch is full
        if batchOperations.count >= 500 { // Firestore batch limit
            processBatchOperations()
        }
    }
    
    private func processBatchOperations() {
        guard !batchOperations.isEmpty else { return }
        
        #if canImport(FirebaseFirestore)
        let batch = db.batch()
        let operations = Array(batchOperations.prefix(500))
        batchOperations.removeFirst(min(500, batchOperations.count))
        
        for operation in operations {
            switch operation.type {
            case .create:
                let ref = db.collection(operation.collection).document(operation.documentId)
                batch.setData(operation.data, forDocument: ref)
            case .update:
                let ref = db.collection(operation.collection).document(operation.documentId)
                batch.updateData(operation.data, forDocument: ref)
            case .delete:
                let ref = db.collection(operation.collection).document(operation.documentId)
                batch.deleteDocument(ref)
            }
        }
        
        Task {
            do {
                try await batch.commit()
                print("✅ Batch operation completed: \(operations.count) operations")
            } catch {
                print("❌ Batch operation failed: \(error)")
                // Re-add failed operations to retry
                self.batchOperations.append(contentsOf: operations)
            }
        }
        #endif
    }
    
    // MARK: - Real-time Listeners Optimization
    func optimizedListener<T: Codable>(
        collection: String,
        filters: [QueryFilter] = [],
        type: T.Type,
        onChange: @escaping ([T]) -> Void
    ) -> String {
        
        let listenerId = UUID().uuidString
        
        #if canImport(FirebaseFirestore)
        var query: Query = db.collection(collection)
        
        for filter in filters {
            query = applyFilter(query, filter: filter)
        }
        
        let listener = query.addSnapshotListener { snapshot, error in
            guard let snapshot = snapshot else {
                print("❌ Listener error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            // Only process changes, not full snapshots
            let changes = snapshot.documentChanges.filter { change in
                change.type == .added || change.type == .modified
            }
            
            if !changes.isEmpty {
                do {
                    let results: [T] = try snapshot.documents.compactMap { doc in
                        try doc.data(as: type)
                    }
                    onChange(results)
                } catch {
                    print("❌ Listener decode error: \(error)")
                }
            }
        }
        
        listeners[listenerId] = listener
        #endif
        
        return listenerId
    }
    
    func removeListener(_ listenerId: String) {
        #if canImport(FirebaseFirestore)
        listeners[listenerId]?.remove()
        listeners.removeValue(forKey: listenerId)
        #endif
    }
    
    // MARK: - Cache Management
    private func generateCacheKey(
        collection: String,
        filters: [QueryFilter],
        orderBy: String?,
        limit: Int?
    ) -> String {
        var key = collection
        
        for filter in filters {
            key += "_\(filter.field)_\(filter.operation)_\(filter.value)"
        }
        
        if let orderBy = orderBy {
            key += "_order_\(orderBy)"
        }
        
        if let limit = limit {
            key += "_limit_\(limit)"
        }
        
        return key
    }
    
    private func getCachedResult(for key: String) -> CachedQueryResult? {
        return queryCache.object(forKey: NSString(string: key))
    }
    
    private func cacheResult<T: Codable>(_ results: [T], for key: String) {
        do {
            let data = try JSONEncoder().encode(results)
            let cached = CachedQueryResult(data: data, timestamp: Date())
            queryCache.setObject(cached, forKey: NSString(string: key))
        } catch {
            print("❌ Failed to cache query result: \(error)")
        }
    }
    
    // MARK: - Performance Metrics
    private func updateQueryMetrics(queryTime: TimeInterval, documentCount: Int) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.queryPerformance.averageQueryTime = (self.queryPerformance.averageQueryTime + queryTime) / 2
            self.queryPerformance.totalQueries += 1
            self.queryPerformance.documentsRetrieved += documentCount
            
            if queryTime > 2.0 {
                print("⚠️ Slow query detected: \(queryTime)s for \(documentCount) documents")
            }
        }
    }
    
    // MARK: - Cleanup
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        #if canImport(FirebaseFirestore)
        listeners.values.forEach { $0.remove() }
        #endif
    }
}

// MARK: - Supporting Types
struct QueryFilter {
    let field: String
    let operation: FilterOperation
    let value: Any
}

enum FilterOperation {
    case equals
    case greaterThan
    case lessThan
    case arrayContains
    case isIn
}

struct BatchOperation {
    let type: BatchOperationType
    let collection: String
    let documentId: String
    let data: [String: Any]
}

enum BatchOperationType {
    case create, update, delete
}

class CachedQueryResult {
    let data: Data
    let timestamp: Date
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    init(data: Data, timestamp: Date) {
        self.data = data
        self.timestamp = timestamp
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > cacheTimeout
    }
    
    func decode<T: Codable>(as type: T.Type) throws -> [T] {
        return try JSONDecoder().decode([T].self, from: data)
    }
}

struct QueryPerformanceMetrics {
    var averageQueryTime: TimeInterval = 0
    var totalQueries: Int = 0
    var documentsRetrieved: Int = 0
    var cacheHitRate: Double = 0
}

// MARK: - Local Storage Optimizer
class LocalStorageOptimizer {
    static let shared = LocalStorageOptimizer()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    // MARK: - UserDefaults Optimization
    func optimizedSet<T: Codable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults.set(data, forKey: key)
        } catch {
            print("❌ Failed to encode value for key \(key): \(error)")
        }
    }
    
    func optimizedGet<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("❌ Failed to decode value for key \(key): \(error)")
            return nil
        }
    }
    
    // MARK: - File System Optimization
    func cleanupTemporaryFiles() {
        let tempDir = fileManager.temporaryDirectory
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            
            for url in contents {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    let age = Date().timeIntervalSince(creationDate)
                    
                    // Delete files older than 1 day
                    if age > 86400 {
                        try fileManager.removeItem(at: url)
                    }
                }
            }
        } catch {
            print("❌ Failed to cleanup temporary files: \(error)")
        }
    }
    
    func getCacheSize() -> Int64 {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey])
            
            return contents.reduce(0) { total, url in
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    let size = attributes[.size] as? Int64 ?? 0
                    return total + size
                } catch {
                    return total
                }
            }
        } catch {
            return 0
        }
    }
}

// MARK: - Database Performance View Modifier
struct DatabasePerformanceModifier: ViewModifier {
    @StateObject private var optimizer = DatabaseOptimizer.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Start performance monitoring
            }
            .onDisappear {
                // Clean up listeners
            }
    }
}

extension View {
    func optimizeDatabase() -> some View {
        modifier(DatabasePerformanceModifier())
    }
}
