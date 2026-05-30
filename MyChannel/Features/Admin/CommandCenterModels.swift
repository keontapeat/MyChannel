// ⚡ PERFORMANCE: Extracted from OwnerCommandCenterView.swift to its own compilation unit.
// Plain data models with no UI — zero SwiftUI type-checker cost here.
// Separate file = compiles in parallel, never triggers OwnerCommandCenterView recompile.
import SwiftUI

// MARK: - Command Center Data Models

struct Department: Identifiable {
    let id = UUID()
    let name: String
    let status: String
    let metric: String
    let statusColor: Color
}

struct PlatformEvent: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let timestamp: Date
}

struct FraudAlert: Identifiable {
    let id: String
    let type: String
    let description: String
    let amount: String
    let userId: String
    let timestamp: Date
    var reviewed: Bool
}

struct ContentFlag: Identifiable {
    let id: String
    let videoTitle: String
    let creatorName: String
    let violationType: String
    let confidence: Int
    let timestamp: Date
    var reviewed: Bool
}

struct DailyReport: Identifiable {
    let id = UUID()
    let date: Date
    let healthScore: Double
    let newUsers: Int
    let revenue: String
    let summary: String
    let highlights: [String]
    let concerns: [String]
}

struct CountryStat: Identifiable {
    let id = UUID()
    let flag: String
    let name: String
    let users: Int
    let percent: Int
}

struct CreatorPulse: Identifiable {
    let id = UUID()
    let creatorName: String
    let status: String
    let viewsDelta: String
    let healthScore: Double
    let trendEmoji: String
    let isSpike: Bool
}

struct StrikeSnapshot: Identifiable {
    let id = UUID()
    let caseId: String
    let username: String
    let latestViolation: String
    let strikeCount: Int
    let aiRisk: Int
}

struct OwnerTask: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let createdAt: Date
}
