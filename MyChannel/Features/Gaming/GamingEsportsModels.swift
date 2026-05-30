// ⚡ PERFORMANCE: Extracted from GamingEsportsView.swift — independent compilation unit.
// Data models + AnimatedStatText compile separately from the 1540-line main view.
import SwiftUI

// MARK: - Supporting Types

enum GamingTab: String, CaseIterable, Identifiable {
    case tournaments
    case vsMatches
    case bracket
    case leaderboard
    case myEarnings
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .tournaments: return "Tournaments"
        case .vsMatches: return "VS Matches"
        case .bracket: return "3D Bracket"
        case .leaderboard: return "Leaderboard"
        case .myEarnings: return "My Earnings"
        }
    }
    
    var iconName: String {
        switch self {
        case .tournaments: return "trophy.fill"
        case .vsMatches: return "person.2.fill"
        case .bracket: return "square.grid.3x1.below.line.grid.1x2"
        case .leaderboard: return "chart.bar.fill"
        case .myEarnings: return "dollarsign.circle.fill"
        }
    }
}

enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case allTime
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .daily: return "Today"
        case .weekly: return "This Week"
        case .monthly: return "This Month"
        case .allTime: return "All Time"
        }
    }
}

struct GamingEsportsTournament: Identifiable {
    let id: String
    let name: String
    let gameName: String
    let prizePool: Double
    let entryFee: Double
    let format: String
    let currentPlayers: Int
    let maxPlayers: Int
    let startDate: Date
    let isLive: Bool
    
    var formattedPrizePool: String {
        "$\(Int(prizePool).formatted())"
    }
    
    var formattedEntryFee: String {
        "$\(Int(entryFee))"
    }
    
    var timeRemaining: String {
        let interval = startDate.timeIntervalSinceNow
        if interval < 0 { return "Started" }
        
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
    
    var isFull: Bool {
        currentPlayers >= maxPlayers
    }
}

struct VSMatch: Identifiable {
    let id: String
    let challenger: User
    let opponent: User?
    let category: String
    let wagerAmount: Double
    let createdAt: Date
    var verificationStatus: MatchVerificationStatus = .none
    var needsProofSubmission: Bool = false
    
    var formattedWager: String {
        "$\(Int(wagerAmount).formatted())"
    }
}

enum MatchVerificationStatus {
    case none
    case pending
    case verified
    case disputed
}

struct LeaderboardUser: Identifiable {
    let id: String
    let displayName: String
    let totalEarnings: Double
    let wins: Int
    let matches: Int
    
    var formattedEarnings: String {
        "$\(Int(totalEarnings).formatted())"
    }
}

struct EarningsTransaction: Identifiable {
    let id: String
    let description: String
    let amount: Double
    let date: Date
    let type: TransactionType
    
    enum TransactionType {
        case win, loss, deposit, withdrawal
    }
    
    var isPositive: Bool {
        type == .win || type == .deposit
    }
    
    var formattedAmount: String {
        let prefix = isPositive ? "+" : "-"
        return "\(prefix)$\(Int(abs(amount)).formatted())"
    }
    
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Color extension removed - use Color+Hex.swift file instead

// MARK: - 🔥 PREMIUM: Animated Stat Text with Count-Up Animation
struct AnimatedStatText: View {
    let value: Double
    let prefix: String
    let font: Font
    let color: Color
    
    @State private var displayedValue: Double = 0
    @State private var hasAnimated = false
    
    init(value: Double, prefix: String = "", font: Font = .body, color: Color = .primary) {
        self.value = value
        self.prefix = prefix
        self.font = font
        self.color = color
    }
    
    var body: some View {
        Text("\(prefix)\(Int(displayedValue).formatted())")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayedValue)
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                animateCount()
            }
            .onChange(of: value) { newValue in
                // Smoothly animate to new value
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    displayedValue = newValue
                }
            }
    }
    
    private func animateCount() {
        // 🔥 PREMIUM: Smooth count-up animation with easing
        let steps = min(Int(value), 25)
        guard steps > 0 else {
            displayedValue = value
            return
        }
        
        let animationDuration = 0.6
        let stepDuration = animationDuration / Double(steps)
        
        Task { @MainActor in
            for step in 0...steps {
                let progress = Double(step) / Double(steps)
                let easedProgress = 1 - pow(1 - progress, 3)
                let newValue = value * easedProgress
                withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                    displayedValue = newValue
                }
                if step < steps {
                    try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                }
            }
        }
    }
}

#Preview {
    GamingEsportsView()
}

