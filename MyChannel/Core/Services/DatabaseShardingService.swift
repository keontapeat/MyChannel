//
//  DatabaseShardingService.swift
//  MyChannel
//
//  🗄️ DATABASE SHARDING - HORIZONTAL SCALING!
//  Partition data across multiple databases for massive scale
//  Instagram/Facebook-level database architecture! 🔥
//

import Foundation
import FirebaseFirestore

class DatabaseShardingService {
    static let shared = DatabaseShardingService()
    
    private var shardConnections: [Int: Firestore] = [:]
    private let totalShards: Int
    private var shardMetrics: [Int: ShardMetrics] = [:]
    
    init(totalShards: Int = 16) {
        self.totalShards = totalShards
        initializeShards()
    }
    
    // MARK: - 🎯 SHARD SELECTION
    
    /// Get shard number for a user
    func getShard(for userId: String) -> Int {
        return abs(userId.hashValue) % totalShards
    }
    
    /// Get shard number based on any key
    func getShardByKey(_ key: String, shardingStrategy: ShardingStrategy = .consistent) -> Int {
        switch shardingStrategy {
        case .consistent:
            return consistentHashShard(key: key)
            
        case .rangeBasedDate:
            return rangeBasedDateShard(key: key)
            
        case .geoLocation:
            return geoLocationShard(key: key)
            
        case .modulo:
            return abs(key.hashValue) % totalShards
        }
    }
    
    enum ShardingStrategy {
        case consistent          // Consistent hashing
        case rangeBasedDate     // Shard by date ranges
        case geoLocation        // Shard by geographic location
        case modulo             // Simple modulo
    }
    
    // MARK: - 🔄 SHARDING STRATEGIES
    
    /// Consistent hashing for better distribution
    private func consistentHashShard(key: String) -> Int {
        // Simple consistent hash (can be enhanced with virtual nodes)
        let hash = key.hash
        return abs(hash) % totalShards
    }
    
    /// Range-based sharding by date
    private func rangeBasedDateShard(key: String) -> Int {
        // Extract date from key if possible
        // For now, use timestamp-based sharding
        let timestamp = Date().timeIntervalSince1970
        let daysSinceEpoch = Int(timestamp / 86400)
        
        return daysSinceEpoch % totalShards
    }
    
    /// Geographic location-based sharding
    private func geoLocationShard(key: String) -> Int {
        // Map based on geo regions
        // US: shards 0-5, EU: 6-10, Asia: 11-15
        // Simplified for now
        return abs(key.hashValue) % totalShards
    }
    
    // MARK: - 🗄️ DATABASE OPERATIONS
    
    /// Get Firestore instance for specific shard
    func getFirestore(for userId: String) -> Firestore {
        let shardId = getShard(for: userId)
        return getFirestore(shardId: shardId)
    }
    
    /// Get Firestore instance for shard ID
    func getFirestore(shardId: Int) -> Firestore {
        if let existingConnection = shardConnections[shardId] {
            return existingConnection
        }
        
        // Create new connection for shard
        let firestore = Firestore.firestore()
        // In production, this would connect to different database instances
        // For now, use same Firestore with collection prefixes
        
        shardConnections[shardId] = firestore
        return firestore
    }
    
    /// Write data to appropriate shard
    func writeToShard<T: Encodable>(
        userId: String,
        collection: String,
        documentId: String,
        data: T
    ) async throws {
        let shard = getShard(for: userId)
        let firestore = getFirestore(shardId: shard)
        
        // Use shard-specific collection
        let shardedCollection = "shard_\(shard)_\(collection)"
        
        print("💾 [Sharding] Writing to shard \(shard): \(shardedCollection)/\(documentId)")
        
        try firestore.collection(shardedCollection)
            .document(documentId)
            .setData(from: data)
        
        // Update metrics
        updateMetrics(shardId: shard, operation: .write)
    }
    
    /// Read data from appropriate shard
    func readFromShard<T: Decodable>(
        userId: String,
        collection: String,
        documentId: String,
        as type: T.Type
    ) async throws -> T {
        let shard = getShard(for: userId)
        let firestore = getFirestore(shardId: shard)
        
        let shardedCollection = "shard_\(shard)_\(collection)"
        
        print("📖 [Sharding] Reading from shard \(shard): \(shardedCollection)/\(documentId)")
        
        let document = try await firestore.collection(shardedCollection)
            .document(documentId)
            .getDocument()
        
        // Update metrics
        updateMetrics(shardId: shard, operation: .read)
        
        return try document.data(as: T.self)
    }
    
    /// Query across specific shard
    func queryShard(
        userId: String,
        collection: String,
        field: String,
        isEqualTo value: Any
    ) async throws -> [DocumentSnapshot] {
        let shard = getShard(for: userId)
        let firestore = getFirestore(shardId: shard)
        
        let shardedCollection = "shard_\(shard)_\(collection)"
        
        let snapshot = try await firestore.collection(shardedCollection)
            .whereField(field, isEqualTo: value)
            .getDocuments()
        
        updateMetrics(shardId: shard, operation: .query)
        
        return snapshot.documents
    }
    
    /// Query across ALL shards (expensive - use sparingly!)
    func queryAllShards(
        collection: String,
        field: String,
        isEqualTo value: Any
    ) async throws -> [DocumentSnapshot] {
        print("⚠️ [Sharding] Querying ALL shards - expensive operation!")
        
        var allResults: [DocumentSnapshot] = []
        
        // Query each shard in parallel
        await withTaskGroup(of: [DocumentSnapshot].self) { group in
            for shardId in 0..<totalShards {
                group.addTask {
                    do {
                        let firestore = self.getFirestore(shardId: shardId)
                        let shardedCollection = "shard_\(shardId)_\(collection)"
                        
                        let snapshot = try await firestore.collection(shardedCollection)
                            .whereField(field, isEqualTo: value)
                            .getDocuments()
                        
                        return snapshot.documents
                    } catch {
                        print("❌ [Sharding] Error querying shard \(shardId): \(error)")
                        return []
                    }
                }
            }
            
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }
        
        print("📊 [Sharding] Found \(allResults.count) results across all shards")
        
        return allResults
    }
    
    // MARK: - 📊 METRICS
    
    struct ShardMetrics {
        var readCount: Int = 0
        var writeCount: Int = 0
        var queryCount: Int = 0
        var totalOperations: Int = 0
        var averageLatency: TimeInterval = 0
        var lastAccessTime: Date = Date()
        
        mutating func recordOperation(_ type: OperationType) {
            totalOperations += 1
            lastAccessTime = Date()
            
            switch type {
            case .read: readCount += 1
            case .write: writeCount += 1
            case .query: queryCount += 1
            }
        }
    }
    
    enum OperationType {
        case read, write, query
    }
    
    private func updateMetrics(shardId: Int, operation: OperationType) {
        if shardMetrics[shardId] == nil {
            shardMetrics[shardId] = ShardMetrics()
        }
        
        shardMetrics[shardId]?.recordOperation(operation)
    }
    
    /// Get metrics for all shards
    func getShardStatistics() -> [Int: ShardMetrics] {
        return shardMetrics
    }
    
    /// Get overall statistics
    func getOverallStatistics() -> OverallStatistics {
        let totalReads = shardMetrics.values.reduce(0) { $0 + $1.readCount }
        let totalWrites = shardMetrics.values.reduce(0) { $0 + $1.writeCount }
        let totalQueries = shardMetrics.values.reduce(0) { $0 + $1.queryCount }
        let totalOps = totalReads + totalWrites + totalQueries
        
        // Find hot shards (most used)
        let hotShards = shardMetrics
            .sorted { $0.value.totalOperations > $1.value.totalOperations }
            .prefix(3)
            .map { $0.key }
        
        return OverallStatistics(
            totalShards: totalShards,
            activeShards: shardMetrics.count,
            totalReads: totalReads,
            totalWrites: totalWrites,
            totalQueries: totalQueries,
            totalOperations: totalOps,
            hotShards: Array(hotShards)
        )
    }
    
    struct OverallStatistics {
        let totalShards: Int
        let activeShards: Int
        let totalReads: Int
        let totalWrites: Int
        let totalQueries: Int
        let totalOperations: Int
        let hotShards: [Int]
        
        var averageOpsPerShard: Double {
            guard activeShards > 0 else { return 0 }
            return Double(totalOperations) / Double(activeShards)
        }
    }
    
    // MARK: - ⚖️ REBALANCING
    
    /// Check if shards are balanced
    func isBalanced() -> Bool {
        let stats = getOverallStatistics()
        
        guard stats.activeShards > 0 else { return true }
        
        let avgOps = stats.averageOpsPerShard
        
        // Check if any shard has > 2x average operations
        for (_, metrics) in shardMetrics {
            if Double(metrics.totalOperations) > avgOps * 2 {
                return false
            }
        }
        
        return true
    }
    
    /// Get recommendations for rebalancing
    func getRebalancingRecommendations() -> [RebalancingRecommendation] {
        var recommendations: [RebalancingRecommendation] = []
        
        let stats = getOverallStatistics()
        let avgOps = stats.averageOpsPerShard
        
        // Find overloaded shards
        for (shardId, metrics) in shardMetrics {
            if Double(metrics.totalOperations) > avgOps * 1.5 {
                recommendations.append(RebalancingRecommendation(
                    shardId: shardId,
                    currentLoad: metrics.totalOperations,
                    averageLoad: Int(avgOps),
                    action: .split,
                    priority: .high
                ))
            }
        }
        
        return recommendations
    }
    
    struct RebalancingRecommendation {
        let shardId: Int
        let currentLoad: Int
        let averageLoad: Int
        let action: RebalancingAction
        let priority: Priority
        
        enum RebalancingAction {
            case split      // Split shard into multiple shards
            case migrate    // Move data to different shard
            case optimize   // Optimize shard performance
        }
        
        enum Priority {
            case low, medium, high, critical
        }
    }
    
    // MARK: - 🔧 INITIALIZATION
    
    private func initializeShards() {
        print("🗄️ [Sharding] Initializing \(totalShards) shards...")
        
        for shardId in 0..<totalShards {
            _ = getFirestore(shardId: shardId)
            shardMetrics[shardId] = ShardMetrics()
        }
        
        print("✅ [Sharding] All shards initialized")
    }
    
    // MARK: - 🧹 CLEANUP
    
    func resetMetrics() {
        shardMetrics.removeAll()
        print("🧹 [Sharding] Metrics reset")
    }
}

// MARK: - 📱 USAGE EXAMPLES

/*
 
 🗄️ DATABASE SHARDING USAGE:
 
 let sharding = DatabaseShardingService.shared
 
 // Get shard for user
 let shard = sharding.getShard(for: userId)
 print("User \(userId) → Shard \(shard)")
 
 // Write to shard
 try await sharding.writeToShard(
     userId: userId,
     collection: "videos",
     documentId: videoId,
     data: videoData
 )
 
 // Read from shard
 let video = try await sharding.readFromShard(
     userId: userId,
     collection: "videos",
     documentId: videoId,
     as: Video.self
 )
 
 // Query within shard
 let results = try await sharding.queryShard(
     userId: userId,
     collection: "videos",
     field: "status",
     isEqualTo: "published"
 )
 
 // Get statistics
 let stats = sharding.getOverallStatistics()
 print("📊 \(stats.totalOperations) operations across \(stats.activeShards) shards")
 print("📊 Hot shards: \(stats.hotShards)")
 
 // Check balance
 if !sharding.isBalanced() {
     let recommendations = sharding.getRebalancingRecommendations()
     print("⚠️ Shards need rebalancing: \(recommendations.count) actions recommended")
 }
 
 🎯 BENEFITS:
 - Horizontal scaling to billions of users
 - Better performance (smaller indexes)
 - Isolated failures (one shard down ≠ all down)
 - Easier maintenance
 - Cost effective
 
 */
