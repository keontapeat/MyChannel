//
//  AIRealtimeTopSectionsView.swift
//  MyChannel
//
//  🔥 AI-POWERED REAL-TIME TOP SECTIONS
//  Updates LIVE every 30 seconds with triple AI scoring!
//

import SwiftUI

// MARK: - AI Real-Time Top Creators Section
struct AIRealtimeTopCreatorsSection: View {
    @StateObject private var rankingService = AIRealtimeRankingService.shared
    var onSelect: (AIRealtimeRankingService.RankedCreator) -> Void = { _ in }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with LIVE indicator
            HStack(spacing: 8) {
                Text("🔥 Top Creators")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primary)
                
                if rankingService.isLive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .shadow(color: .red, radius: 4)
                        
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Text("Updated \(timeAgo(rankingService.lastUpdate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            if rankingService.topCreators.isEmpty {
                ProgressView()
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(rankingService.topCreators.prefix(10).enumerated()), id: \.offset) { idx, creator in
                            Button {
                                HapticManager.shared.impact(style: .medium)
                                onSelect(creator)
                            } label: {
                                AICreatorRankCard(
                                    rank: idx + 1,
                                    creator: creator
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 12)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }
}

// MARK: - AI Creator Rank Card
private struct AICreatorRankCard: View {
    let rank: Int
    let creator: AIRealtimeRankingService.RankedCreator
    
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            // Avatar with rank badge
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .bottomTrailing) {
                    // Main avatar
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: rankBorderGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 80, height: 80)
                        
                        if let avatarURL = creator.avatar, !avatarURL.isEmpty {
                            if avatarURL.hasPrefix("http") {
                                AppAsyncImage(url: URL(string: avatarURL)) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Circle().fill(Color(.systemGray5))
                                }
                                .frame(width: 74, height: 74)
                                .clipShape(Circle())
                            } else {
                                // Local asset
                                Image(avatarURL)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 74, height: 74)
                                    .clipShape(Circle())
                            }
                        } else {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 74, height: 74)
                        }
                    }
                    
                    // Trending badge
                    if let badge = creator.trendingBadge {
                        Text(badge)
                            .font(.system(size: 16))
                            .padding(4)
                            .background(Circle().fill(.black.opacity(0.7)))
                    }
                }
                
                // Rank number
                Text("#\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(rankColor))
                    .shadow(color: rankColor.opacity(0.5), radius: 4)
            }
            
            // Creator info
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(creator.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .frame(width: 130)
                
                Text("@\(creator.username)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 130)
            }
            
            // AI Scores Grid
            VStack(spacing: 6) {
                // Row 1: Virality + Quality
                HStack(spacing: 6) {
                    ScorePill(
                        label: "🔥",
                        value: Int(creator.viralityScore),
                        color: .red
                    )
                    
                    ScorePill(
                        label: "💎",
                        value: Int(creator.contentQualityScore),
                        color: .cyan
                    )
                }
                
                // Row 2: Velocity + Growth
                HStack(spacing: 6) {
                    ScorePill(
                        label: "📈",
                        value: Int(creator.trendingVelocity),
                        color: .green
                    )
                    
                    ScorePill(
                        label: "⚡️",
                        value: Int(creator.predictedGrowth),
                        color: .orange
                    )
                }
            }
            
            // Stats
            VStack(spacing: 3) {
                Text("\(formatCount(creator.subscribers)) subs")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("\(formatCount(creator.views)) views")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            // Rank change indicator
            if creator.rankChange != 0 {
                HStack(spacing: 3) {
                    Image(systemName: creator.rankChange > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption2)
                        .foregroundColor(creator.rankChange > 0 ? .green : .red)
                    
                    Text("\(abs(creator.rankChange))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(creator.rankChange > 0 ? .green : .red)
                }
            }
        }
        .padding(12)
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(rankBorderColor, lineWidth: rank <= 3 ? 2 : 1)
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
        default: return AppTheme.Colors.primary
        }
    }
    
    private var rankBorderColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
        default: return Color(.systemGray4)
        }
    }
    
    private var rankBorderGradient: [Color] {
        switch rank {
        case 1: return [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.95, blue: 0.5)] // Gold gradient
        case 2: return [Color(red: 0.75, green: 0.75, blue: 0.75), Color(red: 0.9, green: 0.9, blue: 0.9)] // Silver gradient
        case 3: return [Color(red: 0.80, green: 0.50, blue: 0.20), Color(red: 0.9, green: 0.7, blue: 0.5)] // Bronze gradient
        default: return [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.6)]
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Score Pill
private struct ScorePill: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
            Text("\(value)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }
}

// MARK: - VIRAL NOW Section (What's Blowing Up RIGHT NOW!)
struct ViralNowSection: View {
    @StateObject private var rankingService = AIRealtimeRankingService.shared
    var onSelect: (AIRealtimeRankingService.RankedVideo) -> Void = { _ in }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text("🔥 VIRAL NOW")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.red)
                
                Text("What's Blowing Up!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            if rankingService.viralNow.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Finding viral content...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(rankingService.viralNow.prefix(10).enumerated()), id: \.offset) { idx, video in
                            Button {
                                HapticManager.shared.impact(style: .heavy)
                                onSelect(video)
                            } label: {
                                ViralVideoCard(
                                    rank: idx + 1,
                                    video: video
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.05), Color.orange.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

// MARK: - Viral Video Card
private struct ViralVideoCard: View {
    let rank: Int
    let video: AIRealtimeRankingService.RankedVideo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with fire effect
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(width: 200, height: 112)
                    .overlay(
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red.opacity(0.3))
                    )
                
                // Rank badge
                HStack(spacing: 4) {
                    Text("#\(rank)")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white)
                    
                    Text("🔥")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.red))
                .shadow(color: .red.opacity(0.5), radius: 4)
                .padding(6)
            }
            
            // Title
            Text(video.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(width: 200, alignment: .leading)
            
            // Creator
            HStack(spacing: 6) {
                if let avatar = video.creatorAvatar, !avatar.isEmpty {
                    if avatar.hasPrefix("http") {
                        AppAsyncImage(url: URL(string: avatar)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color(.systemGray5))
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                    } else {
                        Image(avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 20, height: 20)
                            .clipShape(Circle())
                    }
                }
                
                Text(video.creatorName)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)
            
            // Viral stats
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Virality")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(Int(video.viralityScore))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Velocity")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(Int(video.engagementVelocity))/min")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                Spacer()
            }
            .frame(width: 200)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .red.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.red, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
}

#Preview {
    VStack {
        AIRealtimeTopCreatorsSection()
        ViralNowSection()
    }
}

