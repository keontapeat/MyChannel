//
//  TrendingView.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI

struct TrendingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var trendingVideos: [Video] = []
    @State private var selectedTimeframe: TrendingTimeframe = .today
    @State private var isLoading = true
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
                // Clean header
                header
                
                // Minimal tab selector
                tabSelector
                
                // Video list
                if isLoading {
                    loadingView
                } else {
                    videoList
                }
            }
            .background(colorScheme == .dark ? Color.black : Color.white)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await loadFriendChannelVideos()
        }
    }
    
    // MARK: - Clean Header
    private var header: some View {
        HStack {
            Button {
                HapticManager.shared.impact(style: .light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 40, height: 40)
            }
            
            Spacer()
            
            Text("Trending")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Spacer()
            
            // Balance
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Tab Selector (YouTube Style)
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(TrendingTimeframe.allCases, id: \.self) { timeframe in
                    tabButton(timeframe)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    private func tabButton(_ timeframe: TrendingTimeframe) -> some View {
        Button {
            HapticManager.shared.impact(style: .light)
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimeframe = timeframe
            }
        } label: {
            VStack(spacing: 8) {
                Text(timeframe.displayName)
                    .font(.system(size: 14, weight: selectedTimeframe == timeframe ? .semibold : .regular))
                    .foregroundColor(selectedTimeframe == timeframe 
                        ? (colorScheme == .dark ? .white : .black)
                        : (colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6)))
                
                // Underline indicator
                Rectangle()
                    .fill(selectedTimeframe == timeframe 
                        ? (colorScheme == .dark ? .white : .black)
                        : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(colorScheme == .dark ? .white : .black)
            Spacer()
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
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                            .padding(.leading, 72)
                    }
                }
            }
            .padding(.top, 8)
        }
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
                }
            }
        }
    }
}

// MARK: - Clean Trending Row (YouTube Style)
struct CleanTrendingRow: View {
    let video: Video
    let rank: Int
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            NotificationCenter.default.post(name: NSNotification.Name("OpenVideoDetail"), object: video)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Large rank number
                Text("\(rank)")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                    .frame(width: 32, alignment: .center)
                    .padding(.top, 4)
                
                // Thumbnail
                thumbnailView
                
                // Video info
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 4) {
                        Text(video.creator.displayName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                        
                        if video.creator.isVerified {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                        }
                    }
                    
                    Text("\(video.formattedViewCount) views · \(video.timeAgo)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                }
                
                Spacer(minLength: 0)
                
                // More button
                Button {
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.6))
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isPressed 
                ? (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                : Color.clear)
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
        .accessibilityLabel("\(video.title) by \(video.creator.displayName), rank \(rank)")
    }
    
    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: video.thumbnailURL)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                @unknown default:
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                }
            }
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
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
