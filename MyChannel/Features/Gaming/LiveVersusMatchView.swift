//
//  LiveVersusMatchView.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🔴 LIVE VS MATCH - Watch the battle unfold! 🔥
//

import SwiftUI

struct LiveVersusMatchView: View {
    let match: VersusMatch
    @StateObject private var matchService = VersusMatchService.shared
    @State private var liveStats = VersusMatch.MatchStats(
        challengerViews: 0, opponentViews: 0,
        challengerLikes: 0, opponentLikes: 0,
        challengerComments: 0, opponentComments: 0,
        challengerDonations: 0, opponentDonations: 0,
        peakViewers: 0, totalViewers: 0
    )
    @State private var timeRemaining: TimeInterval = 0
    
    private func safeInt(_ value: Double, fallback: Int = 0) -> Int {
        guard value.isFinite else { return fallback }
        return Int(value.rounded())
    }

    /// Prize pool and winner take-home via MoneyMath (integer cents) — never Double * 0.9.
    private var prizePoolGrossCents: Int {
        MoneyMath.cents(fromDollars: match.wagerAmount) * 2
    }

    private var winnerPayoutCents: Int {
        MoneyMath.winnerPayoutCents(grossCents: prizePoolGrossCents)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Live Badge
                liveBadge
                
                // VS Header
                vsHeader
                
                // Live Stats
                statsSection
                
                // Progress Bars
                progressBars
                
                // Time Remaining
                timerSection
                
                // Wager Info
                wagerInfo
            }
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("LIVE MATCH")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Initialise countdown from actual start time
            if let startedAt = match.startedAt {
                let elapsed = Date().timeIntervalSince(startedAt)
                timeRemaining = max(0, match.rules.duration - elapsed)
            } else {
                timeRemaining = match.rules.duration
            }
            // Tick every second until match ends or view disappears
            while timeRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                timeRemaining = max(0, timeRemaining - 1)
            }
        }
        .task {
            // Poll Firestore for live stats every 10 seconds
            while !Task.isCancelled {
                if let latest = await matchService.fetchMatch(matchId: match.id),
                   let stats = latest.finalStats {
                    liveStats = stats
                }
                try? await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
    }
    
    // MARK: - Live Badge
    
    private var liveBadge: some View {
        HStack {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
            
            Text("LIVE")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(20)
        .padding(.top, 20)
    }
    
    // MARK: - VS Header
    
    private var vsHeader: some View {
        HStack(spacing: 40) {
            // Challenger
            VStack(spacing: 12) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                    )
                
                Text("Challenger")
                    .font(.system(size: 16, weight: .bold))
                
                Text("@user1")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // VS
            Text("VS")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.red)
            
            // Opponent
            VStack(spacing: 12) {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                    )
                
                Text("Opponent")
                    .font(.system(size: 16, weight: .bold))
                
                Text("@user2")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 32)
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        VStack(spacing: 20) {
            StatRow(
                title: "Views",
                challengerValue: liveStats.challengerViews,
                opponentValue: liveStats.opponentViews
            )
            
            StatRow(
                title: "Likes",
                challengerValue: liveStats.challengerLikes,
                opponentValue: liveStats.opponentLikes
            )
            
            StatRow(
                title: "Comments",
                challengerValue: liveStats.challengerComments,
                opponentValue: liveStats.opponentComments
            )
            
            DonationRow(
                title: "Donations",
                challengerValue: liveStats.challengerDonations,
                opponentValue: liveStats.opponentDonations
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    // MARK: - Progress Bars
    
    private var progressBars: some View {
        VStack(spacing: 16) {
            Text("Live Score")
                .font(.system(size: 18, weight: .bold))
            
            // GeometryReader replaces deprecated UIScreen.main.bounds
            GeometryReader { geo in
                let total = liveStats.challengerViews + liveStats.opponentViews
                let cFrac: CGFloat = total > 0
                    ? CGFloat(liveStats.challengerViews) / CGFloat(total)
                    : 0.5
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * cFrac)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: geo.size.width * (1 - cFrac))
                }
                .frame(height: 40)
                .cornerRadius(8)
            }
            .frame(height: 40)
            
            HStack {
                Text("\(Int(challengerPercentage))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("\(Int(opponentPercentage))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var challengerPercentage: Double {
        let total = liveStats.challengerViews + liveStats.opponentViews
        guard total > 0 else { return 50 }
        return Double(liveStats.challengerViews) / Double(total) * 100
    }
    
    private var opponentPercentage: Double {
        let total = liveStats.challengerViews + liveStats.opponentViews
        guard total > 0 else { return 50 }
        return Double(liveStats.opponentViews) / Double(total) * 100
    }
    
    // MARK: - Timer
    
    private var timerSection: some View {
        VStack(spacing: 12) {
            Text("Time Remaining")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            Text(formatTime(timeRemaining))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(AppTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.Colors.surface)
        .cornerRadius(16)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - Wager Info
    
    private var wagerInfo: some View {
        VStack(spacing: 16) {
            Text("Prize Pool")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            
            Text("$\(MoneyMath.dollars(fromCents: prizePoolGrossCents).formatted(.number.precision(.fractionLength(0...2))))")
                .font(.system(size: 48, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Winner takes home $\(MoneyMath.dollars(fromCents: winnerPayoutCents).formatted(.number.precision(.fractionLength(0...2))))")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            LinearGradient(
                colors: [.orange.opacity(0.1), .red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 40)
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

struct StatRow: View {
    let title: String
    let challengerValue: Int
    let opponentValue: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            HStack {
                Text("\(challengerValue)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Spacer()
                    .frame(width: 60)
                
                Text("\(opponentValue)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
    }
}

struct DonationRow: View {
    let title: String
    let challengerValue: Double
    let opponentValue: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            HStack {
                Text("$\(Int(challengerValue))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Spacer()
                    .frame(width: 60)
                
                Text("$\(Int(opponentValue))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        LiveVersusMatchView(match: VersusMatch(
            id: "1",
            challengerId: "user1",
            opponentId: "user2",
            matchType: .headToHead,
            wagerAmount: 100,
            category: .views,
            rules: VersusMatch.MatchRules(
                duration: 3600,
                category: .views,
                winCondition: .mostViews
            ),
            status: .live,
            createdAt: Date(),
            scheduledDate: Date()
        ))
    }
}

