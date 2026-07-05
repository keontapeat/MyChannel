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
    @State private var isLoading = true
    @State private var lastUpdated: Date = Date()
    @State private var livePulse: Bool = false
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
            duration: 184,
            viewCount: 10_000_000,
            likeCount: 572,
            creator: User(
                username: "babyju",
                displayName: "Baby Ju",
                email: "noreply@yt.com",
                profileImageURL: "https://i.ytimg.com/vi/JSXmfgZzHqQ/hqdefault.jpg",
                subscriberCount: 2040,
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
            viewCount: 8_000_000,
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
            ("71GJrAY54Ew", "Scatz - Rebound (Official Music Video)")
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
                // Header with live pulse
                header
                
                // Tab selector
                tabSelector
                
                // Video list
                if isLoading {
                    loadingView
                } else {
                    videoList
                }
            }
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await loadFriendChannelVideos()
            startLivePulse()
        }
    }
    
    // MARK: - Header (YouTube-style with live pulse)
    private var header: some View {
        HStack {
            Button {
                HapticManager.shared.impact(style: .light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 40, height: 40)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(colors: [AppTheme.Colors.warning, AppTheme.Colors.error], startPoint: .top, endPoint: .bottom)
                    )
                
                Text("Trending")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            Spacer()
            
            // Live indicator — pulsing dot + "UPDATING"
            HStack(spacing: 5) {
                Circle()
                    .fill(AppTheme.Colors.live)
                    .frame(width: 7, height: 7)
                    .scaleEffect(livePulse ? 1.3 : 0.85)
                    .opacity(livePulse ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: livePulse)
                
                Text("LIVE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.Colors.live)
                    .tracking(0.5)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.Colors.live.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel("Live, updated \(Int(Date().timeIntervalSince(lastUpdated))) seconds ago")
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
    }
    
    // MARK: - Tab Selector (YouTube Style, pill-highlighted)
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(TrendingTimeframe.allCases, id: \.self) { timeframe in
                    tabButton(timeframe)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
    
    private func tabButton(_ timeframe: TrendingTimeframe) -> some View {
        let isSelected = selectedTimeframe == timeframe
        return Button {
            HapticManager.shared.impact(style: .light)
            withAnimation(AppTheme.AnimationPresets.spring) {
                selectedTimeframe = timeframe
            }
        } label: {
            Text(timeframe.displayName)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textSecondary)
                .padding(.horizontal, AppTheme.Spacing.smd)
                .padding(.vertical, AppTheme.Spacing.xs + 2)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [AppTheme.Colors.error, AppTheme.Colors.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            AppTheme.Colors.surface
                        }
                    }
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Loading View (shimmer skeleton rows, feels live rather than a static spinner)
    private var loadingView: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.sm) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(alignment: .top, spacing: AppTheme.Spacing.smd) {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 160, height: 90)
                            .shimmer(active: true)
                        
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xxs)
                                .fill(AppTheme.Colors.surface)
                                .frame(height: 14)
                                .shimmer(active: true)
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xxs)
                                .fill(AppTheme.Colors.surface)
                                .frame(width: 140, height: 12)
                                .shimmer(active: true)
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xxs)
                                .fill(AppTheme.Colors.surface)
                                .frame(width: 90, height: 12)
                                .shimmer(active: true)
                        }
                        .padding(.top, 4)
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
            .padding(.top, AppTheme.Spacing.sm)
        }
    }
    
    // MARK: - Video List
    private var videoList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(trendingVideos.enumerated()), id: \.element.id) { index, video in
                    CleanTrendingRow(video: video, rank: index + 1)
                    
                    // Subtle divider
                    if index < trendingVideos.count - 1 {
                        Divider()
                            .background(AppTheme.Colors.divider)
                            .padding(.leading, 72)
                    }
                }
            }
            .padding(.top, AppTheme.Spacing.sm)
        }
        .refreshable {
            HapticManager.shared.impact(style: .light)
            await loadFriendChannelVideos()
        }
    }
    
    private func startLivePulse() {
        livePulse = true
    }
    
    private func loadFriendChannelVideos() async {
        do {
            let items = try await YouTubeAPIService.shared.fetchChannelVideos(channelID: friendChannelID, maxResults: 30)
            let merged = items + extraTrendingVideos()
            let dedup = Array(Dictionary(grouping: merged, by: { $0.id }).values.compactMap { $0.first })
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.trendingVideos = dedup.sorted { $0.viewCount > $1.viewCount }
                    self.isLoading = false
                    self.lastUpdated = Date()
                }
            }
        } catch {
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
                withAnimation(.easeOut(duration: 0.3)) {
                    self.trendingVideos = ([friend] + extraTrendingVideos()).sorted { $0.viewCount > $1.viewCount }
                    self.isLoading = false
                    self.lastUpdated = Date()
                }
            }
        }
    }
}

// MARK: - Clean Trending Row (YouTube-live style)
struct CleanTrendingRow: View {
    let video: Video
    let rank: Int
    @State private var isPressed = false
    @State private var displayedViewCount: Int = 0
    
    /// Top 3 get a lit-up flame badge instead of a plain number — signals "hot right now".
    private var isHot: Bool { rank <= 3 }
    
    private var rankGradient: LinearGradient {
        switch rank {
        case 1: return LinearGradient(colors: [Color(hexString: "FFD700"), Color(hexString: "FF7A00")], startPoint: .top, endPoint: .bottom)
        case 2: return LinearGradient(colors: [Color(hexString: "E0E0E0"), Color(hexString: "9AA0A6")], startPoint: .top, endPoint: .bottom)
        case 3: return LinearGradient(colors: [Color(hexString: "E5A15A"), Color(hexString: "B5651D")], startPoint: .top, endPoint: .bottom)
        default: return LinearGradient(colors: [AppTheme.Colors.textTertiary, AppTheme.Colors.textTertiary], startPoint: .top, endPoint: .bottom)
        }
    }
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            NotificationCenter.default.post(name: NSNotification.Name("OpenVideoDetail"), object: video)
        } label: {
            HStack(alignment: .top, spacing: AppTheme.Spacing.smd) {
                rankBadge
                
                thumbnailView
                
                // Video info
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Text(video.creator.displayName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        
                        if video.creator.isVerified {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.Colors.verificationBlue)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text("\(displayedViewCount.formattedCompact) views")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .contentTransition(.numericText())
                        
                        Text("· \(video.timeAgo)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textTertiary)
                        
                        if isHot {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9))
                                Text("HOT")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(AppTheme.Colors.error)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppTheme.Colors.errorLight)
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer(minLength: 0)
                
                // More button
                Button {
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.smd)
            .background(isPressed ? AppTheme.Colors.surface : Color.clear)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            animateViewCount()
        }
        .accessibilityLabel("\(video.title) by \(video.creator.displayName), rank \(rank)\(isHot ? ", trending hot" : "")")
    }
    
    // MARK: - Rank Badge
    private var rankBadge: some View {
        ZStack {
            if isHot {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(rankGradient)
                    .overlay(
                        Text("\(rank)")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .offset(y: 3)
                    )
            } else {
                Text("\(rank)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(rankGradient)
            }
        }
        .frame(width: 28, alignment: .center)
        .padding(.top, 6)
    }
    
    // MARK: - Animated View Count (ticks up like a live counter)
    private func animateViewCount() {
        guard displayedViewCount == 0, video.viewCount > 0 else {
            displayedViewCount = video.viewCount
            return
        }
        let target = video.viewCount
        let startValue = max(0, target - Int.random(in: 1...max(1, target / 200 + 1)))
        displayedViewCount = startValue
        withAnimation(.easeOut(duration: 1.0)) {
            displayedViewCount = target
        }
    }
    
    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            CachedAsyncImage(
                url: URL(string: video.thumbnailURL),
                content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                },
                placeholder: {
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                        .fill(AppTheme.Colors.surface)
                        .shimmer(active: true)
                }
            )
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm, style: .continuous))
            .overlay(
                // Subtle glow ring on top-3 to feel "live" and premium
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm, style: .continuous)
                    .strokeBorder(isHot ? rankGradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom), lineWidth: isHot ? 1.5 : 0)
            )
            
            // Duration badge
            Text(video.formattedDuration)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(6)
        }
    }
}

private extension Int {
    /// Compact YouTube-style view count formatting (1.2M, 8.4K, etc).
    var formattedCompact: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        } else {
            return "\(self)"
        }
    }
}

// MARK: - Legacy Support
struct PremiumTrendingVideoRow: View {
    let video: Video
    let rank: Int
    let positionChange: Int
    let growthRate: Double
    
    var body: some View {
        CleanTrendingRow(video: video, rank: rank)
    }
}

struct TrendingVideoRow: View {
    let video: Video
    let rank: Int
    
    var body: some View {
        CleanTrendingRow(video: video, rank: rank)
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
        case .today: return "Now"
        case .thisWeek: return "This week"
        case .thisMonth: return "This month"
        case .allTime: return "All time"
        }
    }
}

#Preview {
    TrendingView()
}
