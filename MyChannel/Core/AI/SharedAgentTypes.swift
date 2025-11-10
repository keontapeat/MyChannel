//
//  SharedAgentTypes.swift
//  MyChannel
//
//  Shared types used across all AGI agents
//

import Foundation

// MARK: - Agent Metrics

struct AgentMetrics: Codable {
    var startTime: Date?
    var lastSuccessTime: Date?
    var lastErrorTime: Date?
    var totalRuns: Int = 0
    var successCount: Int = 0
    var errorCount: Int = 0
    var revenue: Double = 0
    var impressions: Int = 0
    var avgResponseTime: TimeInterval = 0
    var lastError: String?
    
    static let empty = AgentMetrics()
}

// MARK: - Agent Status

enum AgentStatus: Equatable {
    case idle
    case running
    case paused
    case stopped
    case error(String)
}

// MARK: - Trend

struct Trend: Codable, Identifiable {
    let id: String
    let keyword: String
    let category: String
    var momentum: Double
    var predictedViews: Int
    let detectedAt: Date
    
    init(id: String = UUID().uuidString, keyword: String, category: String, momentum: Double, predictedViews: Int, detectedAt: Date = Date()) {
        self.id = id
        self.keyword = keyword
        self.category = category
        self.momentum = momentum
        self.predictedViews = predictedViews
        self.detectedAt = detectedAt
    }
}

// MARK: - Thumbnail Test

struct ThumbnailTest: Identifiable {
    let id: String
    let videoId: String
    let thumbnails: [String] // URLs
    var impressions: [Int]
    var clicks: [Int]
    let createdAt: Date
    var status: TestStatus
    
    enum TestStatus: String, Codable {
        case active
        case completed
        case cancelled
    }
    
    var clickThroughRates: [Double] {
        zip(clicks, impressions).map { clicks, impressions in
            impressions > 0 ? Double(clicks) / Double(impressions) : 0
        }
    }
    
    var winnerIndex: Int? {
        guard status == .completed else { return nil }
        return clickThroughRates.enumerated().max(by: { $0.element < $1.element })?.offset
    }
    
    init(id: String = UUID().uuidString, videoId: String, thumbnails: [String], impressions: [Int] = [], clicks: [Int] = [], createdAt: Date = Date(), status: TestStatus = .active) {
        self.id = id
        self.videoId = videoId
        self.thumbnails = thumbnails
        self.impressions = impressions.isEmpty ? Array(repeating: 0, count: thumbnails.count) : impressions
        self.clicks = clicks.isEmpty ? Array(repeating: 0, count: thumbnails.count) : clicks
        self.createdAt = createdAt
        self.status = status
    }
}

// MARK: - Moderation Types

struct ModerationItem: Identifiable, Codable {
    let id: String
    let contentType: String
    let content: String
    let severity: ModerationResult.Severity
    
    init(id: String = UUID().uuidString, contentType: String, content: String, severity: ModerationResult.Severity) {
        self.id = id
        self.contentType = contentType
        self.content = content
        self.severity = severity
    }
}

struct ModerationResult: Codable {
    let isApproved: Bool
    let confidence: Double
    let flaggedContent: [String]
    let severity: Severity
    let reason: String?
    
    enum Severity: String, Codable {
        case none
        case low
        case medium
        case high
        case critical
    }
}

struct Report: Identifiable, Codable {
    let id: String
    let contentId: String
    let contentType: String
    let reason: String
    let reportCount: Int
    let reportedAt: Date
    
    init(id: String = UUID().uuidString, contentId: String, contentType: String, reason: String, reportCount: Int, reportedAt: Date = Date()) {
        self.id = id
        self.contentId = contentId
        self.contentType = contentType
        self.reason = reason
        self.reportCount = reportCount
        self.reportedAt = reportedAt
    }
}

// MARK: - Video Metadata (for AI agents)

struct VideoMetadata: Codable {
    let videoId: String
    let title: String
    let description: String
    let tags: [String]
    let category: String
    let thumbnailURL: String?
    let duration: TimeInterval
    let uploadDate: Date
    
    init(videoId: String, title: String, description: String, tags: [String], category: String, thumbnailURL: String? = nil, duration: TimeInterval, uploadDate: Date = Date()) {
        self.videoId = videoId
        self.title = title
        self.description = description
        self.tags = tags
        self.category = category
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.uploadDate = uploadDate
    }
}

// MARK: - Performance Alert

struct PerformanceAlert: Identifiable {
    let id: String
    let type: AlertType
    let message: String
    let severity: Severity
    let timestamp: Date
    
    enum AlertType: String {
        case cpuHigh
        case memoryHigh
        case networkSlow
        case frameRateLow
        case batteryDrainHigh
        case slowUserAction
        case databaseSlow
        case cacheMiss
    }
    
    enum Severity: String {
        case low
        case medium
        case high
        case critical
    }
    
    init(id: String = UUID().uuidString, type: AlertType, message: String, severity: Severity, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.message = message
        self.severity = severity
        self.timestamp = timestamp
    }
}

// MARK: - Support Response

struct SupportResponse: Codable {
    let requestId: String
    let response: String
    let confidence: Double
    let suggestedActions: [String]
    let escalateToHuman: Bool
    
    init(requestId: String, response: String, confidence: Double, suggestedActions: [String] = [], escalateToHuman: Bool = false) {
        self.requestId = requestId
        self.response = response
        self.confidence = confidence
        self.suggestedActions = suggestedActions
        self.escalateToHuman = escalateToHuman
    }
}

