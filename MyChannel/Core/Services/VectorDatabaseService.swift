//
//  VectorDatabaseService.swift
//  MyChannel
//
//  🧠 PINECONE VECTOR DATABASE - SEMANTIC VIDEO SEARCH!
//  Find videos by MEANING, not just keywords (YouTube doesn't have this!)
//  FREE TIER: 1M vectors forever!
//

import Foundation

class VectorDatabaseService {
    static let shared = VectorDatabaseService()
    
    // 🔥 PINECONE CONFIGURATION (FREE TIER!)
    private let pineconeAPIKey = AppSecrets.pineconeAPIKey ?? "YOUR_PINECONE_API_KEY"
    private let pineconeEnvironment = "us-west1-gcp-free" // Free tier
    private let indexName = "mychannel-videos"
    private let dimension = 1536 // OpenAI embedding dimension
    
    private var embeddingCache: [String: [Float]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.mychannel.vector.cache", qos: .userInitiated)
    
    // MARK: - 🎯 VIDEO EMBEDDING
    
    struct VideoEmbedding: Codable {
        let videoID: String
        let vector: [Float] // 1536-dimensional vector
        let metadata: VideoMetadata
        
        struct VideoMetadata: Codable {
            let title: String
            let description: String
            let tags: [String]
            let category: String
            let creatorID: String
            let viewCount: Int
            let uploadDate: Date
        }
    }
    
    // MARK: - 📊 INDEX VIDEO
    
    /// Create embedding and index video for semantic search
    func indexVideo(_ video: Video) async throws {
        print("🧠 [Vector] Indexing video: \(video.title)")
        
        // 1️⃣ CREATE TEXT REPRESENTATION
        let text = createSearchableText(from: video)
        
        // 2️⃣ GENERATE EMBEDDING using OpenAI
        let vector = try await generateEmbedding(for: text)
        
        // 3️⃣ CREATE METADATA
        let metadata = VideoEmbedding.VideoMetadata(
            title: video.title,
            description: video.description,
            tags: video.tags,
            category: video.category.rawValue,
            creatorID: video.creator.id,
            viewCount: video.viewCount,
            uploadDate: video.createdAt
        )
        
        // 4️⃣ UPLOAD TO PINECONE
        let embedding = VideoEmbedding(
            videoID: video.id,
            vector: vector,
            metadata: metadata
        )
        
        try await uploadToPinecone(embedding)
        
        print("✅ [Vector] Indexed video: \(video.id)")
    }
    
    // MARK: - 🔍 SEMANTIC SEARCH
    
    struct SearchResult {
        let video: Video
        let similarity: Float // 0.0 to 1.0
        let rank: Int
    }
    
    /// Search videos by meaning, not just keywords!
    func semanticSearch(
        query: String,
        limit: Int = 20,
        filters: SearchFilters? = nil
    ) async throws -> [SearchResult] {
        
        print("🔍 [Vector] Searching: \(query)")
        
        // 1️⃣ GENERATE QUERY EMBEDDING
        let queryVector = try await generateEmbedding(for: query)
        
        // 2️⃣ QUERY PINECONE
        let results = try await queryPinecone(
            vector: queryVector,
            limit: limit,
            filters: filters
        )
        
        // 3️⃣ CONVERT TO SEARCH RESULTS
        let searchResults = results.enumerated().map { (index, match) in
            SearchResult(
                video: match.video,
                similarity: match.score,
                rank: index + 1
            )
        }
        
        print("✅ [Vector] Found \(searchResults.count) results")
        return searchResults
    }
    
    struct SearchFilters: Codable {
        let category: String?
        let creatorID: String?
        let minViews: Int?
        let dateRange: DateRange?
        
        struct DateRange: Codable {
            let from: Date
            let to: Date
        }
    }
    
    // MARK: - 🎯 FIND SIMILAR VIDEOS
    
    /// Find videos similar to a given video (YouTube's "Up Next"!)
    func findSimilarVideos(
        to videoID: String,
        limit: Int = 10
    ) async throws -> [Video] {
        
        print("🎯 [Vector] Finding similar to: \(videoID)")
        
        // 1️⃣ GET VIDEO VECTOR
        guard let videoVector = try await getVideoVector(videoID) else {
            throw VectorError.videoNotFound
        }
        
        // 2️⃣ QUERY FOR SIMILAR
        let results = try await queryPinecone(
            vector: videoVector,
            limit: limit + 1, // +1 to exclude self
            filters: nil
        )
        
        // 3️⃣ EXCLUDE ORIGINAL VIDEO
        let similarVideos = results
            .filter { $0.video.id != videoID }
            .prefix(limit)
            .map { $0.video }
        
        print("✅ [Vector] Found \(similarVideos.count) similar videos")
        return Array(similarVideos)
    }
    
    // MARK: - 🤖 AI-POWERED RECOMMENDATIONS
    
    /// Get personalized recommendations based on user's watch history
    func getPersonalizedRecommendations(
        for userID: String,
        watchHistory: [String], // Video IDs
        limit: Int = 20
    ) async throws -> [Video] {
        
        print("🤖 [Vector] Getting recommendations for user: \(userID)")
        
        // 1️⃣ GET VECTORS FOR WATCHED VIDEOS
        var watchedVectors: [[Float]] = []
        for videoID in watchHistory.prefix(10) { // Last 10 videos
            if let vector = try await getVideoVector(videoID) {
                watchedVectors.append(vector)
            }
        }
        
        guard !watchedVectors.isEmpty else {
            throw VectorError.noWatchHistory
        }
        
        // 2️⃣ AVERAGE THE VECTORS (user's "taste profile")
        let avgVector = averageVectors(watchedVectors)
        
        // 3️⃣ QUERY FOR SIMILAR
        let results = try await queryPinecone(
            vector: avgVector,
            limit: limit * 2, // Get extra to filter out watched
            filters: nil
        )
        
        // 4️⃣ FILTER OUT ALREADY WATCHED
        let recommendations = results
            .filter { !watchHistory.contains($0.video.id) }
            .prefix(limit)
            .map { $0.video }
        
        print("✅ [Vector] Generated \(recommendations.count) recommendations")
        return Array(recommendations)
    }
    
    // MARK: - 🗑️ DELETE VIDEO
    
    func deleteVideo(_ videoID: String) async throws {
        try await deleteFromPinecone(videoID)
        print("🗑️ [Vector] Deleted video: \(videoID)")
    }
    
    // MARK: - 🔧 HELPER METHODS
    
    private func createSearchableText(from video: Video) -> String {
        var text = video.title + " "
        text += video.description + " "
        // Add more if available: tags, category, etc.
        return text
    }
    
    private func generateEmbedding(for text: String) async throws -> [Float] {
        // Check cache first
        let cacheKey = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = cacheQueue.sync(execute: { embeddingCache[cacheKey] }) {
            print("✅ [Vector] Embedding cache hit")
            return cached
        }
        
        // Generate new embedding using OpenAI
        guard !text.isEmpty else {
            throw VectorError.embeddingFailed
        }
        
        do {
            let embedding = try await generateOpenAIEmbedding(text: text)
            
            // Cache the result
            cacheQueue.async(flags: .barrier) { [weak self] in
                self?.embeddingCache[cacheKey] = embedding
                
                // Keep cache size reasonable (max 1000 entries)
                if let cache = self?.embeddingCache, cache.count > 1000 {
                    // Remove oldest entry (first key)
                    if let firstKey = cache.keys.first {
                        self?.embeddingCache.removeValue(forKey: firstKey)
                    }
                }
            }
            
            return embedding
        } catch {
            print("❌ [Vector] Embedding generation failed: \(error)")
            throw VectorError.embeddingFailed
        }
    }
    
    private func generateOpenAIEmbedding(text: String) async throws -> [Float] {
        // Use OpenAI text-embedding-3-small model (cheap and fast!)
        let apiKey = AppSecrets.openAIAPIKey
        guard !apiKey.isEmpty else {
            throw VectorError.pineconeError("OpenAI API key not configured")
        }
        
        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "input": text,
            "model": "text-embedding-3-small", // 1536 dimensions, super cheap
            "encoding_format": "float"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // ⚡ PERFORMANCE: Use NetworkOptimizer for request deduplication
        let data = try await NetworkOptimizer.shared.optimizedRequest(
            for: request,
            priority: .high
        )
        
        // Note: NetworkOptimizer already validates HTTP status codes
        
        struct EmbeddingResponse: Codable {
            struct EmbeddingData: Codable {
                let embedding: [Float]
            }
            let data: [EmbeddingData]
        }
        
        let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        guard let embedding = embeddingResponse.data.first?.embedding else {
            throw VectorError.embeddingFailed
        }
        
        return embedding
    }
    
    private func averageVectors(_ vectors: [[Float]]) -> [Float] {
        guard !vectors.isEmpty else { return [] }
        
        let count = Float(vectors.count)
        var result = Array(repeating: Float(0.0), count: dimension)
        
        for vector in vectors {
            for (i, value) in vector.enumerated() {
                result[i] += value / count
            }
        }
        
        return result
    }
    
    // MARK: - 🌐 PINECONE API CALLS
    
    struct PineconeMatch {
        let video: Video
        let score: Float
    }
    
    private func pineconeRequest(path: String, method: String = "POST", body: [String: Any]? = nil) async throws -> Data {
        let host = "https://\(indexName)-\(pineconeEnvironment).svc.pinecone.io"
        guard !pineconeAPIKey.hasPrefix("YOUR"),
              let url = URL(string: "\(host)\(path)") else {
            throw VectorError.pineconeError("Pinecone not configured — add PINECONE_API_KEY to AppSecrets")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(pineconeAPIKey, forHTTPHeaderField: "Api-Key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    private func uploadToPinecone(_ embedding: VideoEmbedding) async throws {
        let vectorData: [String: Any] = [
            "id": embedding.videoID,
            "values": embedding.vector,
            "metadata": [
                "title": embedding.metadata.title,
                "category": embedding.metadata.category,
                "creatorID": embedding.metadata.creatorID,
                "viewCount": embedding.metadata.viewCount,
            ]
        ]
        _ = try await pineconeRequest(path: "/vectors/upsert", body: ["vectors": [vectorData]])
        print("⬆️ [Pinecone] Uploaded: \(embedding.videoID)")
    }
    
    private func queryPinecone(vector: [Float], limit: Int, filters: SearchFilters?) async throws -> [PineconeMatch] {
        var body: [String: Any] = ["vector": vector, "topK": limit, "includeMetadata": true]
        if let cat = filters?.category { body["filter"] = ["category": ["$eq": cat]] }
        let data = try await pineconeRequest(path: "/query", body: body)
        struct PineconeResponse: Decodable {
            struct Match: Decodable { let id: String; let score: Float }
            let matches: [Match]
        }
        guard let resp = try? JSONDecoder().decode(PineconeResponse.self, from: data) else { return [] }
        return resp.matches.compactMap { m -> PineconeMatch? in
            // Construct a minimal Video placeholder — callers resolve full data from Firestore
            let placeholder = Video(
                id: m.id, title: "", description: "", thumbnailURL: "", videoURL: "",
                duration: 0, viewCount: 0, likeCount: 0, commentCount: 0,
                createdAt: Date(), creator: User(
                    id: "", username: "", displayName: "", email: "",
                    profileImageURL: "", subscriberCount: 0, videoCount: 0,
                    isVerified: false, createdAt: Date()
                ),
                category: .entertainment, tags: [], isPublic: true, ageRestricted: false
            )
            return PineconeMatch(video: placeholder, score: m.score)
        }
    }
    
    private func getVideoVector(_ videoID: String) async throws -> [Float]? {
        let data = try await pineconeRequest(path: "/vectors/fetch?ids=\(videoID)", method: "GET")
        struct FetchResponse: Decodable {
            struct VectorRecord: Decodable { let values: [Float] }
            let vectors: [String: VectorRecord]
        }
        return (try? JSONDecoder().decode(FetchResponse.self, from: data))?.vectors[videoID]?.values
    }
    
    private func deleteFromPinecone(_ videoID: String) async throws {
        _ = try await pineconeRequest(path: "/vectors/delete", body: ["ids": [videoID]])
        print("🗑️ [Pinecone] Deleted: \(videoID)")
    }
    
    func getStats() async throws -> VectorStats {
        let data = try await pineconeRequest(path: "/describe_index_stats", method: "POST", body: [:])
        struct Stats: Decodable { let totalVectorCount: Int?; let indexFullness: Double? }
        let stats = try? JSONDecoder().decode(Stats.self, from: data)
        return VectorStats(
            totalVectors: stats?.totalVectorCount ?? 0,
            indexSize: 0,
            dimension: dimension,
            queries: 0
        )
    }
    
    // MARK: - ❌ ERRORS
    
    enum VectorError: LocalizedError {
        case videoNotFound
        case noWatchHistory
        case embeddingFailed
        case pineconeError(String)
        
        var errorDescription: String? {
            switch self {
            case .videoNotFound: return "Video not found in vector database"
            case .noWatchHistory: return "User has no watch history"
            case .embeddingFailed: return "Failed to generate embedding"
            case .pineconeError(let msg): return "Pinecone error: \(msg)"
            }
        }
    }
}

// MARK: - 📊 VECTOR STATS

struct VectorStats {
    let totalVectors: Int
    let indexSize: Int
    let dimension: Int
    let queries: Int
}

// MARK: - 📱 USAGE EXAMPLES

/*
 
 🧠 SEMANTIC SEARCH (Better than YouTube!):
 
 let vectorDB = VectorDatabaseService.shared
 
 // Index a video
 try await vectorDB.indexVideo(video)
 
 // Semantic search (finds by meaning!)
 let results = try await vectorDB.semanticSearch(
     query: "funny cat videos",
     limit: 20
 )
 
 for result in results {
     print("\(result.rank). \(result.video.title) - \(Int(result.similarity * 100))% match")
 }
 
 // Find similar videos (Up Next!)
 let similar = try await vectorDB.findSimilarVideos(
     to: currentVideoID,
     limit: 10
 )
 
 // Personalized recommendations
 let recommendations = try await vectorDB.getPersonalizedRecommendations(
     for: userID,
     watchHistory: userWatchHistory,
     limit: 20
 )
 
 🎯 EXAMPLES OF SEMANTIC SEARCH:
 
 Query: "how to cook pasta"
 Finds: "Italian spaghetti recipe", "making carbonara", "pasta cooking tips"
 
 Query: "workout motivation"
 Finds: "gym training", "fitness inspiration", "exercise motivation"
 
 = YOUTUBE CAN'T DO THIS! They only match keywords! 🔥
 
 */

