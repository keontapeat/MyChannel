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
                .foregroundColor(selectedTimeframe == timeframe ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(timeframeButtonBackground(isSelected: selectedTimeframe == timeframe))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(
                    color: selectedTimeframe == timeframe ? AppTheme.Colors.primary.opacity(0.3) : Color.clear,
                    radius: selectedTimeframe == timeframe ? 8 : 0,
                    x: 0,
                    y: 4
                )
        }
        .buttonStyle(.plain)
    }
    
    private func timeframeButtonBackground(isSelected: Bool) -> some View {
        Group {
            if isSelected {
                LinearGradient(
                    colors: [
                        AppTheme.Colors.primary,
                        AppTheme.Colors.primary.opacity(0.85)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                AppTheme.Colors.surface
            }
        }
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
    @State private var animatePulse = false
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            NotificationCenter.default.post(name: NSNotification.Name("OpenVideoDetail"), object: video)
        } label: {
            HStack(spacing: 16) {
                // Premium rank badge with gradient
                ZStack {
                    // Outer glow for top 3
                    if rank <= 3 {
                        Circle()
                            .fill(rankGradient)
                            .frame(width: 56, height: 56)
                            .blur(radius: 8)
                            .opacity(animatePulse ? 0.6 : 0.3)
                            .animation(
                                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                value: animatePulse
                            )
                    }
                    
                    // Main rank badge
                    ZStack {
                        Circle()
                            .fill(rankGradient)
                            .frame(width: 48, height: 48)
                        
                        // Rank number
                        Text("\(rank)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(rank <= 3 ? .white : AppTheme.Colors.textPrimary)
                    }
                    .shadow(color: rankShadowColor, radius: 8, x: 0, y: 4)
                    
                    // Top 3 crown icon
                    if rank <= 3 {
                        VStack {
                            Image(systemName: rank == 1 ? "crown.fill" : rank == 2 ? "star.fill" : "flame.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .offset(y: -28)
                        }
                    }
                }
                .onAppear {
                    if rank <= 3 {
                        animatePulse = true
                    }
                }
                
                // Enhanced video thumbnail with trending overlay
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                AppTheme.Colors.surface.opacity(0.6),
                                                AppTheme.Colors.surface.opacity(0.4)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
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
                    .frame(width: 140, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                rank <= 3 ? rankGradient : LinearGradient(
                                    colors: [Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: rank <= 3 ? 2 : 0
                            )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    
                    // Trending indicator badge
                    if rank <= 10 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("TRENDING")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.red.opacity(0.9),
                                            Color.orange.opacity(0.9)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .padding(6)
                    }
                }
                
                // Enhanced video info section
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(video.title)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Creator with verified badge
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
                    
                    // Metrics row with growth indicators
                    HStack(spacing: 12) {
                        // View count
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 10))
                            Text(video.formattedViewCount)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        // Position change indicator
                        if positionChange != 0 {
                            HStack(spacing: 3) {
                                Image(systemName: positionChange > 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 9, weight: .bold))
                                Text("\(abs(positionChange))")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(positionChange > 0 ? .green : .orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(
                                        (positionChange > 0 ? Color.green : Color.orange)
                                            .opacity(0.15)
                                    )
                            )
                        }
                        
                        // Growth rate indicator
                        if growthRate > 50 {
                            HStack(spacing: 3) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 9, weight: .bold))
                                Text("\(Int(growthRate))%")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                            )
                        }
                        
                        Spacer()
                        
                        // Time ago
                        Text(video.timeAgo)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.Colors.textSecondary.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isPressed
                            ? AppTheme.Colors.surface.opacity(0.5)
                            : AppTheme.Colors.surface
                    )
                    .shadow(
                        color: rank <= 3 ? rankShadowColor.opacity(0.2) : .black.opacity(0.08),
                        radius: rank <= 3 ? 12 : 8,
                        x: 0,
                        y: rank <= 3 ? 6 : 4
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        rank <= 3
                            ? LinearGradient(
                                colors: [
                                    rankGradientColor.opacity(0.3),
                                    rankGradientColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    AppTheme.Colors.divider.opacity(0.3),
                                    AppTheme.Colors.divider.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: rank <= 3 ? 1.5 : 0.5
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
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
    
    // MARK: - Premium Rank Badge Colors & Gradients
    
    private var rankGradient: LinearGradient {
        switch rank {
        case 1:
            // Gold champion gradient
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.84, blue: 0.0), // Gold
                    Color(red: 1.0, green: 0.75, blue: 0.0)  // Darker gold
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            // Silver gradient
            return LinearGradient(
                colors: [
                    Color(red: 0.75, green: 0.75, blue: 0.75), // Silver
                    Color(red: 0.6, green: 0.6, blue: 0.6)       // Darker silver
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            // Bronze gradient
            return LinearGradient(
                colors: [
                    Color(red: 0.8, green: 0.5, blue: 0.2), // Bronze
                    Color(red: 0.7, green: 0.4, blue: 0.15)  // Darker bronze
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            // Premium gradient for other ranks
            return LinearGradient(
                colors: [
                    AppTheme.Colors.primary,
                    AppTheme.Colors.primary.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var rankGradientColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return AppTheme.Colors.primary
        }
    }
    
    private var rankShadowColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.6)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75).opacity(0.6)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2).opacity(0.6)
        default: return AppTheme.Colors.primary.opacity(0.4)
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