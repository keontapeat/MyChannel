//
//  TrendingView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct TrendingView: View {
    @State private var trendingVideos: [Video] = Video.sampleVideos.filter { $0.viewCount > 100000 }
    @State private var selectedTimeframe: TrendingTimeframe = .today
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Timeframe selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(TrendingTimeframe.allCases, id: \.self) { timeframe in
                            Button(timeframe.displayName) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTimeframe = timeframe
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedTimeframe == timeframe ? AppTheme.Colors.primary : AppTheme.Colors.surface
                            )
                            .foregroundColor(
                                selectedTimeframe == timeframe ? .white : AppTheme.Colors.textPrimary
                            )
                            .cornerRadius(AppTheme.CornerRadius.md)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Trending videos list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(trendingVideos.enumerated()), id: \.element.id) { index, video in
                            TrendingVideoRow(video: video, rank: index + 1)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Trending")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Trending Video Row
struct TrendingVideoRow: View {
    let video: Video
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 36, height: 36)
                
                Text("\(rank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Video thumbnail
            AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
            }
            .frame(width: 120, height: 68)
            .cornerRadius(AppTheme.CornerRadius.sm)
            
            // Video info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(AppTheme.Typography.headline)
                    .lineLimit(2)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                HStack(spacing: 4) {
                    Text(video.creator.displayName)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    
                    if video.creator.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("\(video.formattedViewCount) views")
                    Text("•")
                    Text(video.timeAgo)
                }
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textTertiary)
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.md)
        .shadow(
            color: AppTheme.Colors.textPrimary.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.orange
        default: return AppTheme.Colors.primary
        }
    }
}

// MARK: - Supporting Models
enum TrendingTimeframe: String, CaseIterable {
    case today = "today"
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case allTime = "allTime"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .allTime: return "All Time"
        }
    }
}

#Preview {
    TrendingView()
}