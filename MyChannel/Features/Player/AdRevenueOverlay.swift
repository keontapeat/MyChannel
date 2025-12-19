//
//  AdRevenueOverlay.swift
//  MyChannel
//
//  🔥💰 LIVE EARNINGS OVERLAY - WATCH YOUR MONEY GROW! 💰🔥
//
//  Shows creators their earnings in REAL-TIME as viewers watch!
//  Every impression = instant visible revenue!
//

import SwiftUI
import Combine

// MARK: - 🔥 LIVE EARNINGS OVERLAY (For Creators)

struct AdRevenueOverlay: View {
    let video: Video
    let isCreatorViewing: Bool
    
    @StateObject private var revenueTracker = RealTimeRevenueTracker.shared
    @State private var showingDetailedEarnings = false
    @State private var lastEarning: Double = 0
    @State private var showEarningPulse = false
    @State private var sessionEarnings: Double = 0
    @State private var sessionImpressions: Int = 0
    
    private let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        return formatter
    }()
    
    var body: some View {
        // Only show to the video creator
        if isCreatorViewing && (video.monetization?.isMonetized ?? false) {
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        showingDetailedEarnings.toggle()
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        earningsButton
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 12)
                .padding(.top, 60) // Below status bar and nav
                
                Spacer()
            }
            .sheet(isPresented: $showingDetailedEarnings) {
                DetailedEarningsSheet(
                    video: video,
                    sessionEarnings: sessionEarnings,
                    sessionImpressions: sessionImpressions
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .adRevenueEarned)) { notification in
                handleEarning(notification)
            }
        }
    }
    
    // MARK: - Earnings Button
    
    private var earningsButton: some View {
        HStack(spacing: 6) {
            // Money icon with pulse animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .scaleEffect(showEarningPulse ? 1.5 : 1.0)
                    .opacity(showEarningPulse ? 0 : 1)
                    .animation(.easeOut(duration: 0.5), value: showEarningPulse)
                
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                // Session earnings
                HStack(spacing: 4) {
                    Text("+")
                        .font(.system(size: 10, weight: .bold))
                    Text(formatSessionEarnings())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                }
                .foregroundColor(.green)
                
                // Today's total
                Text("Today: \(revenueTracker.formattedTodayEarnings)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.7))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
                )
        )
        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helpers
    
    private func formatSessionEarnings() -> String {
        if sessionEarnings >= 1 {
            return String(format: "$%.2f", sessionEarnings)
        } else {
            return String(format: "$%.4f", sessionEarnings)
        }
    }
    
    private func handleEarning(_ notification: Notification) {
        guard let result = notification.object as? ServedAdResult else { return }
        
        // Update session earnings
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            sessionEarnings += result.creatorRevenue
            sessionImpressions += 1
            lastEarning = result.creatorRevenue
            showEarningPulse = true
        }
        
        // Reset pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showEarningPulse = false
        }
        
        // Haptic feedback
        HapticManager.shared.impact(style: .medium)
    }
}

// MARK: - 🔥 DETAILED EARNINGS SHEET

struct DetailedEarningsSheet: View {
    let video: Video
    let sessionEarnings: Double
    let sessionImpressions: Int
    
    @StateObject private var revenueTracker = RealTimeRevenueTracker.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Session Stats
                    sessionStatsCard
                    
                    // Video Stats
                    videoStatsCard
                    
                    // Overall Stats
                    overallStatsCard
                    
                    // Recent Earnings
                    recentEarningsCard
                    
                    // CPM Info
                    cpmInfoCard
                    
                    // Optimization Tips
                    optimizationTips
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("💰 Live Earnings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Session Stats Card
    
    private var sessionStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Session")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text(String(format: "%.4f", sessionEarnings))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(sessionImpressions)")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("impressions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Live indicator
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(Color.green.opacity(0.5))
                            .frame(width: 16, height: 16)
                            .scaleEffect(1.5)
                            .opacity(0.5)
                            .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                    )
                
                Text("LIVE - Earnings update in real-time")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Video Stats Card
    
    private var videoStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Video")
                .font(.headline)
            
            HStack(spacing: 16) {
                RevenueStatBox(
                    title: "Total Revenue",
                    value: String(format: "$%.2f", video.monetization?.totalRevenue ?? 0),
                    icon: "dollarsign.circle",
                    color: .green
                )
                
                RevenueStatBox(
                    title: "Impressions",
                    value: "\(video.viewCount)",
                    icon: "eye",
                    color: .blue
                )
                
                RevenueStatBox(
                    title: "CPM",
                    value: String(format: "$%.2f", revenueTracker.currentCPM),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Overall Stats Card
    
    private var overallStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Earnings")
                .font(.headline)
            
            VStack(spacing: 12) {
                EarningsRow(label: "Today", amount: revenueTracker.todayEarnings, color: .green)
                EarningsRow(label: "This Week", amount: revenueTracker.thisWeekEarnings, color: .blue)
                EarningsRow(label: "This Month", amount: revenueTracker.thisMonthEarnings, color: .purple)
                
                Divider()
                
                EarningsRow(label: "Lifetime", amount: revenueTracker.lifetimeEarnings, color: .orange, isBold: true)
            }
            
            // Pending payout
            HStack {
                Text("Available for withdrawal:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(revenueTracker.formattedPendingPayout)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Recent Earnings Card
    
    private var recentEarningsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Earnings")
                .font(.headline)
            
            if revenueTracker.recentEarnings.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Earnings will appear here as viewers watch")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(revenueTracker.recentEarnings.prefix(5)) { event in
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Ad impression")
                                .font(.subheadline)
                            Text(event.network)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(event.formattedAmount)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            Text(event.timeAgo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if event.id != revenueTracker.recentEarnings.prefix(5).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - CPM Info Card
    
    private var cpmInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("How You Earn")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                RevenueInfoRow(icon: "dollarsign.circle", text: "You get 90% of ad revenue (vs YouTube's 55%)")
                RevenueInfoRow(icon: "bolt.circle", text: "No subscriber requirements - earn from day 1")
                RevenueInfoRow(icon: "clock.circle", text: "24-hour payouts (vs YouTube's 30+ days)")
                RevenueInfoRow(icon: "chart.line.uptrend.xyaxis.circle", text: "Average CPM: \(revenueTracker.formattedCPM)")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Optimization Tips
    
    private var optimizationTips: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Maximize Earnings")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                RevenueTipRow(tip: "Videos 10+ min can have mid-roll ads (2x revenue)")
                RevenueTipRow(tip: "Gaming & Tech have highest CPMs ($20-30)")
                RevenueTipRow(tip: "Upload at peak hours (6-9 PM) for more views")
                RevenueTipRow(tip: "Higher retention = more mid-roll ad opportunities")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - 🔥 SUPPORTING VIEWS

struct RevenueStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct EarningsRow: View {
    let label: String
    let amount: Double
    let color: Color
    var isBold: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(isBold ? .headline : .subheadline)
                .foregroundColor(isBold ? .primary : .secondary)
            Spacer()
            Text(formatAmount())
                .font(isBold ? .headline : .subheadline)
                .fontWeight(isBold ? .bold : .semibold)
                .foregroundColor(color)
        }
    }
    
    private func formatAmount() -> String {
        if amount >= 1000 {
            return String(format: "$%.2fK", amount / 1000)
        } else {
            return String(format: "$%.2f", amount)
        }
    }
}

struct RevenueInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct RevenueTipRow: View {
    let tip: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("•")
                .foregroundColor(.yellow)
            Text(tip)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 🔥 MINI EARNINGS BADGE (For Video Thumbnail)

struct MiniEarningsBadge: View {
    let earnings: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.green)
            
            Text(formatEarnings())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.7))
        .cornerRadius(4)
    }
    
    private func formatEarnings() -> String {
        if earnings >= 1000 {
            return String(format: "$%.1fK", earnings / 1000)
        } else if earnings >= 1 {
            return String(format: "$%.2f", earnings)
        } else {
            return String(format: "$%.2f", earnings)
        }
    }
}

// MARK: - Preview

#Preview("Ad Revenue Overlay") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        AdRevenueOverlay(
            video: Video.sampleVideos[0],
            isCreatorViewing: true
        )
    }
}

#Preview("Detailed Earnings Sheet") {
    DetailedEarningsSheet(
        video: Video.sampleVideos[0],
        sessionEarnings: 0.0234,
        sessionImpressions: 3
    )
}


