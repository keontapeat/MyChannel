// ⚡ PERFORMANCE: Extracted from OwnerCommandCenterView.swift to its own compilation unit.
// Plain data models with no UI — zero SwiftUI type-checker cost here.
// Separate file = compiles in parallel, never triggers OwnerCommandCenterView recompile.
import SwiftUI

// MARK: - Command Center Theme
//
// Ops-console palette. No decorative rainbow (cyan/purple/yellow/pink) — a single
// neutral graphite surface system with three semantic status colors only:
// good (green), warning (amber), critical (red). Everything else is grayscale.
struct CCTheme {
    // Surfaces
    static let ink = Color(red: 0.035, green: 0.038, blue: 0.043)      // near-black header/base
    static let panel = Color(uiColor: UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor(red: 0.945, green: 0.948, blue: 0.953, alpha: 1)
    }))
    static let panelBorder = Color(uiColor: UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.06)
    }))

    // Text
    static let textPrimary = Color(uiColor: UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 0.93, alpha: 1)
            : UIColor(white: 0.08, alpha: 1)
    }))
    static let textSecondary = Color(uiColor: UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 0.58, alpha: 1)
            : UIColor(white: 0.42, alpha: 1)
    }))

    // Single restrained accent (steel gray-blue) — used sparingly for primary
    // figures that aren't a status signal (e.g. header stat values, headline numbers).
    static let accent = Color(red: 0.62, green: 0.67, blue: 0.72)

    // Semantic status — muted, not neon. This is the only place color should carry meaning.
    static let good = Color(red: 0.29, green: 0.60, blue: 0.42)
    static let warning = Color(red: 0.78, green: 0.58, blue: 0.24)
    static let critical = Color(red: 0.76, green: 0.30, blue: 0.30)
    static let neutral = Color(red: 0.55, green: 0.57, blue: 0.60)

    static func status(_ isGood: Bool) -> Color { isGood ? good : critical }
}

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
