//
//  TrendingView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct TrendingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var trendingVideos: [Video] = []
    @State private var selectedTimeframe: TrendingTimeframe = .today
    private let friendChannelID: String = "UCITAM_FKtyKEq40aHVXFTcQ"

    private func extraTrendingVideos() -> [Video] {
        let entries: [(id: String, title: String)] = [
            ("71GJrAY54Ew", "Scatz - Rebound (Official Music Video)"),
            ("F98vGhQDrB8", "YouTube Video F98vGhQDrB8")
        ]
        return entries.map { e in
            Video(
                id: "yt_\(e.id)",
                title: e.title,
                description: "Official video",
                thumbnailURL: "https://i.ytimg.com/vi/\(e.id)/hqdefault.jpg",
                videoURL: "https://www.youtube.com/watch?v=\(e.id)",
                duration: Double.random(in: 90...300),
                viewCount: Int.random(in: 3_000...2_000_000),
                likeCount: Int.random(in: 100...50_000),
                creator: User(username: "scatz", displayName: "Scatz", email: "noreply@yt.com", profileImageURL: "https://i.ytimg.com/vi/\(e.id)/hqdefault.jpg", isVerified: true, isCreator: true),
                category: .music,
                tags: ["music","friend","youtube"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .landscape,
                isLiveStream: false,
                contentSource: .youtube,
                externalID: e.id,
                contentRating: nil,
                language: "en",
                subtitles: nil,
                isVerified: true,
                monetization: nil,
                isSponsored: nil,
                chapters: nil
            )
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.Colors.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text("Trending")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    // spacer to balance layout
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(AppTheme.Colors.background)
                
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
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await loadFriendChannelVideos()
        }
    }

    private func loadFriendChannelVideos() async {
        do {
            let items = try await YouTubeAPIService.shared.fetchChannelVideos(channelID: friendChannelID, maxResults: 30)
            let merged = items + extraTrendingVideos()
            let dedup = Array(Dictionary(grouping: merged, by: { $0.id }).values.compactMap { $0.first })
            await MainActor.run {
                self.trendingVideos = dedup
            }
        } catch {
            // Fallback to a single known friend video if API key missing or call fails
            let vid = "71GJrAY54Ew"
            let friend = Video(
                id: "yt_\(vid)",
                title: "Scatz - Rebound ( Official Music Video ) Shot By @ImmortalVision",
                description: "Official music video. Shot by @ImmortalVision.",
                thumbnailURL: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg",
                videoURL: "https://www.youtube.com/watch?v=\(vid)",
                duration: 120,
                viewCount: 5000,
                likeCount: 200,
                creator: User(username: "scatz", displayName: "Scatz", email: "noreply@yt.com", profileImageURL: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg", isVerified: true, isCreator: true),
                category: .music,
                tags: ["music","friend","youtube"],
                isPublic: true,
                quality: [.quality720p],
                aspectRatio: .landscape,
                isLiveStream: false,
                contentSource: .youtube,
                externalID: vid,
                contentRating: nil,
                language: "en",
                subtitles: nil,
                isVerified: true,
                monetization: nil,
                isSponsored: nil,
                chapters: nil
            )
            await MainActor.run {
                self.trendingVideos = [friend] + extraTrendingVideos()
            }
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