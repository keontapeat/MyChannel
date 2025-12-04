//
//  FileGuardianService.swift
//  MyChannel
//
//  🛡️🔥 FILE GUARDIAN OPUS 4.5 SERVICE 🔥🛡️
//  Powered by Claude Opus 4.5 on Vertex AI
//
//  This service protects your project files from accidental deletion
//  by AI assistants and automated tools.
//

import Foundation

// MARK: - File Guardian Models

/// Risk levels for file operations
enum FileGuardianRiskLevel: String, Codable {
    case safe = "safe"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    case nuclear = "nuclear"
    
    var emoji: String {
        switch self {
        case .safe: return "✅"
        case .low: return "🟢"
        case .medium: return "🟡"
        case .high: return "🟠"
        case .critical: return "🔴"
        case .nuclear: return "☢️"
        }
    }
    
    var description: String {
        switch self {
        case .safe: return "Safe operation"
        case .low: return "Low risk"
        case .medium: return "Medium risk - proceed with caution"
        case .high: return "High risk - review carefully"
        case .critical: return "Critical - requires approval"
        case .nuclear: return "BLOCKED - operation forbidden"
        }
    }
}

/// Types of file operations
enum FileOperationType: String, Codable {
    case read = "read"
    case write = "write"
    case delete = "delete"
    case move = "move"
    case rename = "rename"
    case bulkDelete = "bulk_delete"
    case overwrite = "overwrite"
}

/// Request to analyze a file operation
struct FileGuardianRequest: Codable {
    let operation: String
    let filePath: String
    let source: String
    let context: String?
    
    enum CodingKeys: String, CodingKey {
        case operation
        case filePath = "file_path"
        case source
        case context
    }
}

/// Response from the File Guardian agent
struct FileGuardianResponse: Codable {
    let allowed: Bool
    let riskLevel: String
    let reason: String
    let alternativeAction: String?
    let recoveryCommand: String?
    let agent: String?
    let model: String?
    let timestamp: String?
    
    enum CodingKeys: String, CodingKey {
        case allowed
        case riskLevel = "risk_level"
        case reason
        case alternativeAction = "alternative_action"
        case recoveryCommand = "recovery_command"
        case agent
        case model
        case timestamp
    }
    
    var riskLevelEnum: FileGuardianRiskLevel {
        FileGuardianRiskLevel(rawValue: riskLevel) ?? .high
    }
}

/// File Guardian agent status
struct FileGuardianStatus: Codable {
    let agent: String
    let version: String
    let model: String
    let status: String
    let protectionLevel: String
    let analyzedOperations: Int
    let blockedOperations: Int
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case agent
        case version
        case model
        case status
        case protectionLevel = "protection_level"
        case analyzedOperations = "analyzed_operations"
        case blockedOperations = "blocked_operations"
        case message
    }
}

// MARK: - File Guardian Service

/// 🛡️ File Guardian Service - Protects files from accidental deletion
/// Powered by Claude Opus 4.5 on Google Cloud Vertex AI
@MainActor
final class FileGuardianService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = FileGuardianService()
    
    // MARK: - Properties
    @Published var isActive: Bool = true
    @Published var lastResponse: FileGuardianResponse?
    @Published var blockedCount: Int = 0
    @Published var status: FileGuardianStatus?
    
    private let baseURL = "https://us-central1-mychannel-ca26d.cloudfunctions.net/file-guardian-opus"
    private let session: URLSession
    
    // MARK: - Local Protection (Instant, no API needed)
    
    /// Files that can NEVER be deleted
    private let nuclearProtectedFiles: Set<String> = [
        "MyChannelApp.swift",
        "AppConfig.swift",
        "AppSecrets.swift",
        "AppTheme.swift",
        "project.pbxproj",
        "package.json",
        "next.config.ts",
        "firebase.json",
        "firestore.rules",
        ".cursorrules"
    ]
    
    /// Directories that can NEVER have files deleted
    private let nuclearProtectedDirectories: [String] = [
        "MyChannel/Core/",
        "MyChannel/Features/",
        "MyChannel/App/",
        "web-v2/app/",
        "web-v2/components/",
        "web-v2/lib/"
    ]
    
    /// File extensions that require extra protection
    private let protectedExtensions: Set<String> = [
        ".swift", ".ts", ".tsx", ".js", ".jsx",
        ".json", ".yaml", ".yml", ".plist",
        ".pbxproj", ".xcodeproj"
    ]
    
    // MARK: - Initialization
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        
        // Fetch initial status
        Task {
            await fetchStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check if a file operation should be allowed
    /// - Parameters:
    ///   - operation: Type of operation
    ///   - filePath: Path to the file
    ///   - source: Who/what is requesting the operation
    ///   - context: Additional context
    /// - Returns: Guardian response with decision
    func checkOperation(
        operation: FileOperationType,
        filePath: String,
        source: String = "ios_app",
        context: String? = nil
    ) async -> FileGuardianResponse {
        
        // Layer 1: Local instant protection (no API call needed)
        if let localBlock = checkLocalProtection(operation: operation, filePath: filePath) {
            blockedCount += 1
            lastResponse = localBlock
            return localBlock
        }
        
        // Layer 2: Call Opus 4.5 agent for intelligent analysis
        do {
            let response = try await callGuardianAPI(
                operation: operation,
                filePath: filePath,
                source: source,
                context: context
            )
            
            if !response.allowed {
                blockedCount += 1
            }
            
            lastResponse = response
            return response
            
        } catch {
            // On error, be conservative - block deletes
            let fallbackResponse = FileGuardianResponse(
                allowed: operation == .read,
                riskLevel: operation == .delete ? "critical" : "medium",
                reason: "Guardian API unavailable. Using safe fallback: blocking deletes.",
                alternativeAction: "Try again or proceed manually with caution.",
                recoveryCommand: "git restore \(filePath)",
                agent: "FileGuardianService",
                model: "local_fallback",
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
            
            if !fallbackResponse.allowed {
                blockedCount += 1
            }
            
            lastResponse = fallbackResponse
            return fallbackResponse
        }
    }
    
    /// Quick check if deletion should be blocked (instant, local)
    func shouldBlockDeletion(filePath: String) -> Bool {
        let fileName = (filePath as NSString).lastPathComponent
        
        // Check nuclear protected files
        if nuclearProtectedFiles.contains(fileName) {
            return true
        }
        
        // Check nuclear protected directories
        for dir in nuclearProtectedDirectories {
            if filePath.contains(dir) {
                return true
            }
        }
        
        // Check protected extensions
        let ext = (filePath as NSString).pathExtension
        if protectedExtensions.contains(".\(ext)") {
            // Check if it's in a source directory
            if filePath.contains("MyChannel/") || filePath.contains("web-v2/") {
                return true
            }
        }
        
        return false
    }
    
    /// Fetch guardian status from API
    func fetchStatus() async {
        guard let url = URL(string: baseURL) else { return }
        
        do {
            let (data, _) = try await session.data(from: url)
            status = try JSONDecoder().decode(FileGuardianStatus.self, from: data)
            isActive = true
        } catch {
            print("🛡️ [FileGuardian] Failed to fetch status: \(error)")
            isActive = false
        }
    }
    
    // MARK: - Private Methods
    
    /// Check local protection rules (instant, no API)
    private func checkLocalProtection(
        operation: FileOperationType,
        filePath: String
    ) -> FileGuardianResponse? {
        
        // Only check for dangerous operations
        guard operation == .delete || operation == .bulkDelete else {
            return nil
        }
        
        let fileName = (filePath as NSString).lastPathComponent
        
        // Check nuclear protected files
        if nuclearProtectedFiles.contains(fileName) {
            return FileGuardianResponse(
                allowed: false,
                riskLevel: "nuclear",
                reason: "🚫 NUCLEAR BLOCK: '\(fileName)' is a critical system file that cannot be deleted.",
                alternativeAction: "Use EDIT operations only. Never delete critical files.",
                recoveryCommand: "git restore \(filePath)",
                agent: "FileGuardianService",
                model: "local_protection",
                timestamp: ISO8601DateFormatter().string(from: Date())
            )
        }
        
        // Check nuclear protected directories
        for dir in nuclearProtectedDirectories {
            if filePath.contains(dir) {
                return FileGuardianResponse(
                    allowed: false,
                    riskLevel: "nuclear",
                    reason: "🚫 NUCLEAR BLOCK: Cannot delete files in protected directory '\(dir)'",
                    alternativeAction: "Files in this directory are essential. Use version control instead.",
                    recoveryCommand: "git restore \(filePath)",
                    agent: "FileGuardianService",
                    model: "local_protection",
                    timestamp: ISO8601DateFormatter().string(from: Date())
                )
            }
        }
        
        return nil
    }
    
    /// Call the Opus 4.5 Guardian API
    private func callGuardianAPI(
        operation: FileOperationType,
        filePath: String,
        source: String,
        context: String?
    ) async throws -> FileGuardianResponse {
        
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = FileGuardianRequest(
            operation: operation.rawValue,
            filePath: filePath,
            source: source,
            context: context
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // API returns 403 for blocked operations, which is expected
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 403 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(FileGuardianResponse.self, from: data)
    }
}

// MARK: - SwiftUI Preview Helper

#if DEBUG
extension FileGuardianService {
    static var preview: FileGuardianService {
        let service = FileGuardianService.shared
        service.status = FileGuardianStatus(
            agent: "FileGuardianOpus",
            version: "1.0.0",
            model: "claude-opus-4-5-20250514",
            status: "ACTIVE",
            protectionLevel: "NUCLEAR",
            analyzedOperations: 42,
            blockedOperations: 7,
            message: "🛡️🔥 FILE GUARDIAN OPUS 4.5 ACTIVE 🔥🛡️"
        )
        return service
    }
}
#endif




