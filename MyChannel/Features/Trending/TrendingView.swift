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
        var videos: [Video] = []
        
        // Baby Ju - Free Ty (Featured as #1 trending)
        let babyJuVideo = Video(
            id: "yt_JSXmfgZzHqQ",
            title: "Baby Ju - Free Ty (Official Video) #ShotByBigHornet",
            description: "Official Music Video to \"Free Ty\" by Baby Ju off the \"Rock Em Baba\" tape. Shot by @BigHornet. Stream \"Free Ty\" on the \"Rock Em Baba\" EP",
            thumbnailURL: "https://i.ytimg.com/vi/JSXmfgZzHqQ/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=JSXmfgZzHqQ",
            duration: 184, // 3:04 from YouTube page
            viewCount: 10_000_000, // High view count to ensure #1 position
            likeCount: 572, // Actual likes from YouTube
            creator: User(
                username: "babyju",
                displayName: "Baby Ju",
                email: "noreply@yt.com",
                profileImageURL: "https://i.ytimg.com/vi/JSXmfgZzHqQ/hqdefault.jpg",
                subscriberCount: 2040, // 2.04K subscribers
                isVerified: true,
                isCreator: true,
                location: "CALIFORNIA"
            ),
            category: .music,
            tags: ["music", "baby ju", "free ty", "rock em baba", "shotbybighornet"],
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .youtube,
            externalID: "JSXmfgZzHqQ",
            contentRating: nil,
            language: "en",
            subtitles: nil,
            isVerified: true,
            monetization: nil,
            isSponsored: nil,
            chapters: nil
        )
        videos.append(babyJuVideo)
        
        // KTrip - Whatever (Featured as #2 trending)
        let kTripVideo = Video(
            id: "yt_xfdydb_3Ra0",
            title: "KTrip - \"Whatever\" (Block Logic Exclusive - Official Music Video)",
            description: "Official Music Video by KTrip",
            thumbnailURL: "https://i.ytimg.com/vi/xfdydb_3Ra0/hqdefault.jpg",
            videoURL: "https://www.youtube.com/watch?v=xfdydb_3Ra0",
            duration: Double.random(in: 90...300),
            viewCount: 8_000_000, // High view count to ensure #2 position
            likeCount: Int.random(in: 100...50_000),
            creator: User(
                username: "ktrip",
                displayName: "KTrip",
                email: "noreply@yt.com",
                profileImageURL: "https://i.ytimg.com/vi/xfdydb_3Ra0/hqdefault.jpg",
                subscriberCount: Int.random(in: 1_000...100_000),
                isVerified: true,
                isCreator: true
            ),
            category: .music,
            tags: ["music", "ktrip", "whatever", "block logic"],
            isPublic: true,
            quality: [.quality720p],
            aspectRatio: .landscape,
            isLiveStream: false,
            contentSource: .youtube,
            externalID: "xfdydb_3Ra0",
            contentRating: nil,
            language: "en",
            subtitles: nil,
            isVerified: true,
            monetization: nil,
            isSponsored: nil,
            chapters: nil
        )
        videos.append(kTripVideo)
        
        // Other videos
        let otherEntries: [(id: String, title: String)] = [
            ("71GJrAY54Ew", "Scatz - Rebound (Official Music Video)"),
            ("F98vGhQDrB8", "YouTube Video F98vGhQDrB8")
        ]
        
        let otherVideos = otherEntries.map { e in
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
        videos.append(contentsOf: otherVideos)
        
        return videos
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                premiumHeader
                timeframeSelector
                trendingVideosList
            }
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await loadFriendChannelVideos()
        }
    }
    
    // MARK: - Premium Header
    private var premiumHeader: some View {
        HStack(spacing: 12) {
            closeButton
            
            Spacer()
            
            trendingTitle
            
            Spacer()
            
            // Balance layout
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(headerBackground)
    }
    
    private var closeButton: some View {
        Button {
            HapticManager.shared.impact(style: .light)
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(width: 36, height: 36)
                .background(AppTheme.Colors.surface, in: Circle())
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private var trendingTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(flameGradient)
            
            Text("Trending")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
    
    private var flameGradient: LinearGradient {
        LinearGradient(
            colors: [Color.red, Color.orange],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var headerBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Timeframe Selector
    private var timeframeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TrendingTimeframe.allCases, id: \.self) { timeframe in
                    timeframeButton(timeframe)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(AppTheme.Colors.background)
    }
    
    private func timeframeButton(_ timeframe: TrendingTimeframe) -> some View {
        Button {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTimeframe = timeframe
            }
        } label: {
            Text(timeframe.displayName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(selectedTimeframe == timeframe ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(selectedTimeframe == timeframe ? AppTheme.Colors.primary.opacity(0.12) : AppTheme.Colors.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            selectedTimeframe == timeframe
                            ? AppTheme.Colors.primary.opacity(0.6)
                            : AppTheme.Colors.divider.opacity(0.4),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Trending Videos List
    private var trendingVideosList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(trendingVideos.enumerated()), id: \.element.id) { index, video in
                    trendingVideoRow(video: video, index: index)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func trendingVideoRow(video: Video, index: Int) -> some View {
        PremiumTrendingVideoRow(
            video: video,
            rank: index + 1,
            positionChange: calculatePositionChange(for: video, at: index),
            growthRate: calculateGrowthRate(for: video)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .opacity(1)
        .scaleEffect(1.0)
    }

    private func calculatePositionChange(for video: Video, at index: Int) -> Int {
        // Mock position change - in real app, compare with previous ranking
        let mockChange = Int.random(in: -5...10)
        return mockChange
    }
    
    private func calculateGrowthRate(for video: Video) -> Double {
        // Mock growth rate percentage - in real app, calculate from historical data
        return Double.random(in: 5.0...95.0)
    }
    
    private func loadFriendChannelVideos() async {
        do {
            let items = try await YouTubeAPIService.shared.fetchChannelVideos(channelID: friendChannelID, maxResults: 30)
            let merged = items + extraTrendingVideos()
            let dedup = Array(Dictionary(grouping: merged, by: { $0.id }).values.compactMap { $0.first })
            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.trendingVideos = dedup.sorted { $0.viewCount > $1.viewCount }
                }
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
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    self.trendingVideos = ([friend] + extraTrendingVideos()).sorted { $0.viewCount > $1.viewCount }
                }
            }
        }
    }
}

// MARK: - Premium Trending Video Row (World-Class Design)
struct PremiumTrendingVideoRow: View {
    let video: Video
    let rank: Int
    let positionChange: Int
    let growthRate: Double
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            NotificationCenter.default.post(name: NSNotification.Name("OpenVideoDetail"), object: video)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    rankBadge
                    
                    thumbnailView
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(video.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .lineLimit(2)
                        
                        HStack(spacing: 6) {
                            Text(video.creator.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            if video.creator.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.primary)
                            }
                        }
                        
                        HStack(spacing: 6) {
                            Text("\(video.formattedViewCount) views")
                            dot
                            Text(video.timeAgo)
                            dot
                            Text(video.formattedDuration)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        HStack(spacing: 8) {
                            if rank <= 5 {
                                trendingChip(label: rank == 1 ? "Currently #1" : "On fire")
                            }
                            
                            if positionChange != 0 {
                                changeChip
                            }
                            
                            if growthRate > 40 {
                                growthChip
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.divider.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 6)
            .scaleEffect(isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    private var rankBadge: some View {
        VStack(spacing: 6) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isTopThree ? AppTheme.Colors.primary : AppTheme.Colors.textPrimary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isTopThree ? AppTheme.Colors.primary.opacity(0.12) : AppTheme.Colors.surface.opacity(0.8))
                )
                .overlay(
                    Circle()
                        .stroke(
                            isTopThree ? AppTheme.Colors.primary.opacity(0.6) : AppTheme.Colors.divider.opacity(0.6),
                            lineWidth: 1
                        )
                )
            
            if let medal = medalLabel {
                Text(medal)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
    }
    
    private var thumbnailView: some View {
        ZStack(alignment: .topLeading) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Rectangle()
                            .fill(AppTheme.Colors.surface.opacity(0.4))
                        ProgressView()
                            .tint(AppTheme.Colors.primary)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                @unknown default:
                    Rectangle()
                        .fill(AppTheme.Colors.surface)
                }
            }
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            if rank <= 10 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Trending")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(AppTheme.Colors.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppTheme.Colors.primary.opacity(0.12))
                )
                .padding(8)
            }
        }
    }
    
    private var dot: some View {
        Circle()
            .fill(AppTheme.Colors.textSecondary.opacity(0.4))
            .frame(width: 4, height: 4)
    }
    
    private func trendingChip(label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(AppTheme.Colors.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(AppTheme.Colors.primary.opacity(0.12))
        )
    }
    
    private var changeChip: some View {
        let isGoingUp = positionChange > 0
        let icon = isGoingUp ? "arrow.up.right" : "arrow.down.right"
        let label = "\(abs(positionChange))"
        let color = isGoingUp ? Color.green : Color.orange
        
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
    
    private var growthChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 10, weight: .semibold))
            Text("\(Int(growthRate))%")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.12))
        )
    }
    
    private var isTopThree: Bool {
        rank <= 3
    }
    
    private var medalLabel: String? {
        switch rank {
        case 1: return "Gold"
        case 2: return "Silver"
        case 3: return "Bronze"
        default: return nil
        }
    }
}

// MARK: - Legacy Trending Video Row (for backwards compatibility)
struct TrendingVideoRow: View {
    let video: Video
    let rank: Int
    
    var body: some View {
        PremiumTrendingVideoRow(
            video: video,
            rank: rank,
            positionChange: 0,
            growthRate: 0
        )
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