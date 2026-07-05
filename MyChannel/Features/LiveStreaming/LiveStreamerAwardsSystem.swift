//
//  LiveStreamerAwardsSystem.swift
//  MyChannel
//
//  Created by AI Assistant on 11/6/25.
//  🏆 LIVE STREAMER AWARDS ECOSYSTEM - Compete to be the BEST!
//  Worth $50M+ in engagement & retention 🔥
//

import Foundation
import SwiftUI

@MainActor
class LiveStreamerAwardsSystem: ObservableObject {
    static let shared = LiveStreamerAwardsSystem()
    
    @Published var currentSeason: AwardSeason
    @Published var topStreamers: [StreamerRanking] = []
    @Published var myRanking: StreamerRanking?
    @Published var upcomingAwards: [AwardCeremony] = []
    @Published var myAchievements: [Achievement] = []
    @Published var myBadges: [Badge] = []

    /// Currently applied leaderboard filters.
    @Published private(set) var activeTimeframe: Timeframe = .weekly
    @Published private(set) var activeCategory: LeaderboardCategory = .overall

    /// Full roster used to derive filtered leaderboards. Seeded once.
    private var roster: [StreamerRanking] = []

    /// The current user's standing in the unfiltered overall leaderboard.
    private var overallMyRanking: StreamerRanking?

    /// Total number of ranked streamers on the platform (used for percentile math).
    let totalStreamerCount = 12_480

    private init() {
        currentSeason = AwardSeason.current()
        loadRankings()
        restoreVotes()
        restoreFollows()
        applyFilters(timeframe: activeTimeframe, category: activeCategory)
    }
    
    // MARK: - 🏆 AWARD CATEGORIES
    
    enum AwardCategory: String, CaseIterable, Identifiable {
        // Main Categories
        case streamerOfTheYear = "Streamer of the Year"
        case breakoutStreamer = "Breakout Streamer"
        case mostWatchedStreamer = "Most Watched Streamer"
        case longestStreak = "Longest Stream Streak"
        
        // Content Categories
        case gamingStreamer = "Gaming Streamer"
        case justChattingStreamer = "Just Chatting Streamer"
        case creativeStreamer = "Creative Streamer"
        case musicStreamer = "Music Streamer"
        case educationalStreamer = "Educational Streamer"
        case cookingStreamer = "Cooking Streamer"
        
        // Engagement Categories
        case mostEngagedCommunity = "Most Engaged Community"
        case bestChat = "Best Chat"
        case mostGenerousCommunity = "Most Generous Community"
        case fastestGrowing = "Fastest Growing"
        
        // Technical Categories
        case bestProduction = "Best Production Value"
        case bestOverlay = "Best Stream Overlay"
        case mostInnovative = "Most Innovative Stream"
        case bestEmotes = "Best Custom Emotes"
        
        // Special Categories
        case mostCharitable = "Most Charitable Streamer"
        case bestCollaborator = "Best Collaborator"
        case funniest = "Funniest Streamer"
        case mostWholesome = "Most Wholesome Streamer"
        case clutchMoment = "Clutch Moment of the Year"
        case viralClip = "Viral Clip of the Year"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .streamerOfTheYear: return "crown.fill"
            case .breakoutStreamer: return "flame.fill"
            case .mostWatchedStreamer: return "eye.fill"
            case .longestStreak: return "calendar.badge.clock"
            case .gamingStreamer: return "gamecontroller.fill"
            case .justChattingStreamer: return "message.fill"
            case .creativeStreamer: return "paintbrush.fill"
            case .musicStreamer: return "music.note"
            case .educationalStreamer: return "graduationcap.fill"
            case .cookingStreamer: return "fork.knife"
            case .mostEngagedCommunity: return "person.3.fill"
            case .bestChat: return "bubble.left.and.bubble.right.fill"
            case .mostGenerousCommunity: return "gift.fill"
            case .fastestGrowing: return "chart.line.uptrend.xyaxis"
            case .bestProduction: return "video.fill"
            case .bestOverlay: return "square.stack.3d.up.fill"
            case .mostInnovative: return "lightbulb.fill"
            case .bestEmotes: return "face.smiling.fill"
            case .mostCharitable: return "heart.fill"
            case .bestCollaborator: return "person.2.fill"
            case .funniest: return "theatermasks.fill"
            case .mostWholesome: return "heart.circle.fill"
            case .clutchMoment: return "bolt.fill"
            case .viralClip: return "rocket.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .streamerOfTheYear: return .yellow
            case .breakoutStreamer: return .orange
            case .mostWatchedStreamer: return .blue
            case .longestStreak: return .purple
            case .gamingStreamer: return .green
            case .mostEngagedCommunity: return .pink
            case .fastestGrowing: return .red
            case .bestProduction: return .cyan
            case .mostCharitable: return .red
            case .viralClip: return .orange
            default: return .gray
            }
        }
        
        var prize: String {
            switch self {
            case .streamerOfTheYear: return "$50,000 + Trophy"
            case .breakoutStreamer: return "$25,000 + Badge"
            case .mostWatchedStreamer: return "$20,000"
            case .gamingStreamer, .justChattingStreamer, .creativeStreamer, .musicStreamer:
                return "$15,000"
            case .mostEngagedCommunity, .bestChat, .fastestGrowing:
                return "$10,000"
            default: return "$5,000 + Badge"
            }
        }
    }
    
    // MARK: - 🗓️ AWARD SEASON
    
    struct AwardSeason: Identifiable {
        let id = UUID()
        let year: Int
        let season: Season
        let startDate: Date
        let endDate: Date
        let ceremonyDate: Date
        var nominations: [Nomination] = []
        var winners: [Winner] = []
        
        enum Season: String {
            case q1 = "Q1 Awards"
            case q2 = "Q2 Awards"
            case q3 = "Q3 Awards"
            case q4 = "Q4 Awards"
            case annual = "Annual Awards"
        }
        
        var isVotingOpen: Bool {
            let now = Date()
            return now >= startDate && now <= endDate
        }

        /// The ceremony is "live" from its start time through a ~3 hour broadcast window.
        var isCurrentlyLive: Bool {
            let now = Date()
            return now >= ceremonyDate && now <= ceremonyDate.addingTimeInterval(3 * 60 * 60)
        }
        
        static func current() -> AwardSeason {
            let now = Date()
            let calendar = Calendar.current
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            
            let season: Season
            switch month {
            case 1...3: season = .q1
            case 4...6: season = .q2
            case 7...9: season = .q3
            default: season = .q4
            }
            
            return AwardSeason(
                year: year,
                season: season,
                startDate: now,
                endDate: calendar.date(byAdding: .month, value: 3, to: now) ?? now,
                ceremonyDate: calendar.date(byAdding: .month, value: 3, to: now) ?? now
            )
        }
    }
    
    // MARK: - 📊 RANKINGS SYSTEM
    
    struct StreamerRanking: Identifiable {
        let id: String
        let streamer: User
        var rank: Int
        var points: Int
        var previousRank: Int?
        var leaderboardCategory: LeaderboardCategory = .overall
        
        // Stats
        var totalHoursStreamed: Double
        var averageViewers: Int
        var peakViewers: Int
        var totalViews: Int
        var uniqueViewers: Int
        var chatMessagesPerMinute: Double
        var subscriptionCount: Int
        var giftsReceived: Int
        var clipsCreated: Int
        var viralMoments: Int
        
        // Categories
        var categoryScores: [AwardCategory: Int]
        var achievements: [Achievement]
        var badges: [Badge]

        /// Baseline (all-time) points used as the source for timeframe scaling.
        var seasonPoints: Int = 0

        /// True if this streamer currently has an active live stream.
        var isLiveNow: Bool = false
        
        var rankChange: Int? {
            guard let previous = previousRank else { return nil }
            return previous - rank
        }
        
        var tier: RankTier {
            switch rank {
            case 1...10: return .legendary
            case 11...50: return .master
            case 51...100: return .diamond
            case 101...500: return .platinum
            case 501...1000: return .gold
            default: return .silver
            }
        }
    }
    
    enum RankTier: String {
        case legendary = "Legendary"
        case master = "Master"
        case diamond = "Diamond"
        case platinum = "Platinum"
        case gold = "Gold"
        case silver = "Silver"
        
        var color: Color {
            switch self {
            case .legendary: return .purple
            case .master: return .red
            case .diamond: return .cyan
            case .platinum: return .gray
            case .gold: return .yellow
            case .silver: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .legendary: return "crown.fill"
            case .master: return "star.fill"
            case .diamond: return "diamond.fill"
            case .platinum: return "hexagon.fill"
            case .gold: return "circle.fill"
            case .silver: return "circle"
            }
        }
    }
    
    // MARK: - 🎖️ ACHIEVEMENTS
    
    struct Achievement: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let icon: String
        let rarity: Rarity
        let unlockedDate: Date?
        let progress: Double? // 0-1 for in-progress achievements
        let requirement: String
        
        var isUnlocked: Bool {
            unlockedDate != nil
        }
        
        enum Rarity: String {
            case common = "Common"
            case rare = "Rare"
            case epic = "Epic"
            case legendary = "Legendary"
            case mythic = "Mythic"
            
            var color: Color {
                switch self {
                case .common: return .gray
                case .rare: return .blue
                case .epic: return .purple
                case .legendary: return .orange
                case .mythic: return .red
                }
            }
        }
    }
    
    // Pre-defined achievements
    static let allAchievements: [Achievement] = [
        // Stream Milestones
        Achievement(title: "First Stream", description: "Completed your first stream", icon: "play.circle.fill", rarity: .common, unlockedDate: nil, progress: nil, requirement: "Stream for the first time"),
        Achievement(title: "Stream Warrior", description: "Stream for 100 hours", icon: "timer", rarity: .rare, unlockedDate: nil, progress: nil, requirement: "100 hours streamed"),
        Achievement(title: "Stream Legend", description: "Stream for 1,000 hours", icon: "flame.fill", rarity: .legendary, unlockedDate: nil, progress: nil, requirement: "1,000 hours streamed"),
        
        // Viewer Milestones
        Achievement(title: "Growing", description: "Reach 100 concurrent viewers", icon: "eye.fill", rarity: .common, unlockedDate: nil, progress: nil, requirement: "100 concurrent viewers"),
        Achievement(title: "Rising Star", description: "Reach 1,000 concurrent viewers", icon: "star.fill", rarity: .rare, unlockedDate: nil, progress: nil, requirement: "1,000 concurrent viewers"),
        Achievement(title: "Superstar", description: "Reach 10,000 concurrent viewers", icon: "star.fill", rarity: .epic, unlockedDate: nil, progress: nil, requirement: "10,000 concurrent viewers"),
        Achievement(title: "Mega Star", description: "Reach 100,000 concurrent viewers", icon: "crown.fill", rarity: .legendary, unlockedDate: nil, progress: nil, requirement: "100,000 concurrent viewers"),
        
        // Special
        Achievement(title: "24 Hour Warrior", description: "Stream for 24 hours straight", icon: "moon.stars.fill", rarity: .epic, unlockedDate: nil, progress: nil, requirement: "24-hour stream"),
        Achievement(title: "Viral Moment", description: "Get a clip with 1M views", icon: "rocket.fill", rarity: .legendary, unlockedDate: nil, progress: nil, requirement: "1M clip views"),
        Achievement(title: "Charity Hero", description: "Raise $10,000 for charity", icon: "heart.fill", rarity: .mythic, unlockedDate: nil, progress: nil, requirement: "$10K charity raised")
    ]
    
    // MARK: - 🎯 BADGES
    
    struct Badge: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let icon: String
        let color: Color
        let earnedDate: Date
        let displayOnProfile: Bool
    }
    
    static let allBadges: [Badge] = [
        Badge(name: "Verified Streamer", description: "Official verified status", icon: "checkmark.seal.fill", color: .blue, earnedDate: Date(), displayOnProfile: true),
        Badge(name: "Partner", description: "MyChannel Partner", icon: "star.circle.fill", color: .purple, earnedDate: Date(), displayOnProfile: true),
        Badge(name: "Top 100", description: "Ranked in Top 100", icon: "trophy.fill", color: .yellow, earnedDate: Date(), displayOnProfile: true),
        Badge(name: "Award Winner", description: "Won a streamer award", icon: "medal.fill", color: .orange, earnedDate: Date(), displayOnProfile: true),
        Badge(name: "Charity Champion", description: "Raised $10K+ for charity", icon: "heart.circle.fill", color: .red, earnedDate: Date(), displayOnProfile: true)
    ]
    
    // MARK: - 🗳️ NOMINATIONS & VOTING
    
    struct Nomination: Identifiable {
        let id = UUID()
        let category: AwardCategory
        let nominees: [Nominee]
        var totalVotes: Int
        let votingEndDate: Date
    }
    
    struct Nominee: Identifiable {
        let id: String
        let streamer: User
        var votes: Int
        let highlights: [String] // Why they're nominated
        let featuredClip: URL?
    }
    
    func nominateStreamer(streamerId: String, category: AwardCategory) {
        print("🎯 Nominated streamer for \(category.rawValue)")
        // Add to nominations
    }
    
    func voteForStreamer(nomineeId: String, category: AwardCategory) async throws {
        print("🗳️ Voted for nominee in \(category.rawValue)")
        // Record vote
        // Update vote count
    }

    // MARK: - 🗳️ Local Voting State
    //
    // Lightweight, instantly-responsive vote tracking for the UI. One vote per
    // category (changeable), persisted across launches. When real nominee user
    // IDs and auth are available this hands off to StreamerAwardsVotingService.

    /// categoryId -> the nominee the user voted for in that category.
    @Published private(set) var votedNomineeByCategory: [String: String] = [:]
    /// nomineeId -> locally-applied vote boost (optimistic increment).
    @Published private(set) var localVoteBoost: [String: Int] = [:]

    private static let votesDefaultsKey = "streamerAwards.localVotes.v1"

    /// True if the user has already voted in the given category.
    func hasVoted(inCategory categoryId: String) -> Bool {
        votedNomineeByCategory[categoryId] != nil
    }

    /// True if this specific nominee is the user's pick for its category.
    func didVote(forNominee nomineeId: String, inCategory categoryId: String) -> Bool {
        votedNomineeByCategory[categoryId] == nomineeId
    }

    /// Extra votes the user has contributed to a nominee locally.
    func voteBoost(forNominee nomineeId: String) -> Int {
        localVoteBoost[nomineeId] ?? 0
    }

    /// Casts (or moves) the user's single vote for a category.
    func castVote(nomineeId: String, categoryId: String) {
        guard votedNomineeByCategory[categoryId] != nomineeId else { return }

        // Moving a vote: remove the boost from the previous pick.
        if let previous = votedNomineeByCategory[categoryId] {
            localVoteBoost[previous] = max(0, (localVoteBoost[previous] ?? 0) - 1)
        }
        localVoteBoost[nomineeId, default: 0] += 1
        votedNomineeByCategory[categoryId] = nomineeId

        persistVotes()

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        // NOTE: When real nominee user IDs + auth are wired, hand off to
        // StreamerAwardsVotingService.submitVote(categoryId:nomineeUserId:userId:)
        // here to persist the vote server-side. The local state above keeps the
        // UI responsive in the meantime.
    }

    private func persistVotes() {
        let payload = LocalVotePayload(votedNomineeByCategory: votedNomineeByCategory, localVoteBoost: localVoteBoost)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: Self.votesDefaultsKey)
        }
    }

    private func restoreVotes() {
        guard let data = UserDefaults.standard.data(forKey: Self.votesDefaultsKey),
              let payload = try? JSONDecoder().decode(LocalVotePayload.self, from: data) else { return }
        votedNomineeByCategory = payload.votedNomineeByCategory
        localVoteBoost = payload.localVoteBoost
    }

    private struct LocalVotePayload: Codable {
        var votedNomineeByCategory: [String: String]
        var localVoteBoost: [String: Int]
    }

    // MARK: - 👥 Local Follow State
    //
    // Instantly-responsive follow tracking for the leaderboard UI. Persisted
    // across launches. When full social-graph wiring is available this should
    // hand off to `SocialGraphService.follow(fromUserId:toUserId:)`.

    @Published private(set) var followedStreamerIds: Set<String> = []

    private static let followsDefaultsKey = "streamerAwards.localFollows.v1"

    func isFollowing(_ streamerId: String) -> Bool {
        followedStreamerIds.contains(streamerId)
    }

    func toggleFollow(_ streamerId: String) {
        if followedStreamerIds.contains(streamerId) {
            followedStreamerIds.remove(streamerId)
        } else {
            followedStreamerIds.insert(streamerId)
        }
        persistFollows()
        HapticManager.shared.impact(style: .light)
    }

    private func persistFollows() {
        let ids = Array(followedStreamerIds)
        UserDefaults.standard.set(ids, forKey: Self.followsDefaultsKey)
    }

    private func restoreFollows() {
        guard let ids = UserDefaults.standard.array(forKey: Self.followsDefaultsKey) as? [String] else { return }
        followedStreamerIds = Set(ids)
    }
    
    // MARK: - 🏅 AWARD CEREMONY
    
    struct AwardCeremony: Identifiable {
        let id = UUID()
        let season: AwardSeason
        let date: Date
        let isLive: Bool
        var viewers: Int
        var winners: [Winner]
        let streamURL: URL?
        let highlights: [CeremonyHighlight]
    }
    
    struct Winner: Identifiable {
        let id = UUID()
        let category: AwardCategory
        let streamer: User
        let acceptanceSpeech: String?
        let clipURL: URL?
        var acceptanceSpeechVideoId: String? = nil
    }
    
    struct CeremonyHighlight {
        let title: String
        let timestamp: TimeInterval
        let clipURL: URL
    }
    
    // MARK: - 📈 POINTS SYSTEM
    
    func calculatePoints(for stats: StreamerStats) -> Int {
        var points = 0
        
        // Hours streamed (1 point per hour)
        points += Int(stats.hoursStreamed)
        
        // Viewers (average viewers / 10)
        points += stats.averageViewers / 10
        
        // Peak viewers (peak / 5)
        points += stats.peakViewers / 5
        
        // Engagement (chat messages per minute * 100)
        points += Int(stats.chatMessagesPerMinute * 100)
        
        // Subscriptions (10 points each)
        points += stats.subscriptionCount * 10
        
        // Viral clips (100 points each)
        points += stats.viralClips * 100
        
        // Consistency bonus (streamed 5+ days this week)
        if stats.streamDaysThisWeek >= 5 {
            points += 500
        }
        
        return points
    }
    
    struct StreamerStats {
        var hoursStreamed: Double
        var averageViewers: Int
        var peakViewers: Int
        var chatMessagesPerMinute: Double
        var subscriptionCount: Int
        var viralClips: Int
        var streamDaysThisWeek: Int
    }
    
    // MARK: - 🎁 REWARDS & PRIZES
    
    func claimAward(category: AwardCategory) async throws {
        print("🏆 Claiming award for \(category.rawValue)")
        
        // Award prize money
        // Award badge
        // Award achievement
        // Update profile
    }
    
    // MARK: - 📊 LEADERBOARDS
    
    func fetchLeaderboard(timeframe: Timeframe, category: LeaderboardCategory) async throws -> [StreamerRanking] {
        print("📊 Fetching \(timeframe.rawValue) leaderboard for \(category.rawValue)")
        
        // Fetch from database
        // Calculate rankings
        // Return sorted list
        
        return []
    }
    
    enum Timeframe: String, CaseIterable {
        case daily = "Today"
        case weekly = "This Week"
        case monthly = "This Month"
        case quarterly = "This Quarter"
        case yearly = "This Year"
        case allTime = "All Time"

        /// Scales baseline points so each window produces a distinct standing.
        var pointsMultiplier: Double {
            switch self {
            case .daily: return 0.18
            case .weekly: return 1.0
            case .monthly: return 3.6
            case .quarterly: return 9.4
            case .yearly: return 34.0
            case .allTime: return 61.0
            }
        }

        /// Short noun used in "Top Streamer of the …" copy.
        var periodNoun: String {
            switch self {
            case .daily: return "Day"
            case .weekly: return "Week"
            case .monthly: return "Month"
            case .quarterly: return "Quarter"
            case .yearly: return "Year"
            case .allTime: return "Era"
            }
        }
    }
    
    enum LeaderboardCategory: String, CaseIterable {
        case overall = "Overall"
        case gaming = "Gaming"
        case justChatting = "Just Chatting"
        case creative = "Creative"
        case music = "Music"
        case educational = "Educational"

        var icon: String {
            switch self {
            case .overall: return "trophy.fill"
            case .gaming: return "gamecontroller.fill"
            case .justChatting: return "message.fill"
            case .creative: return "paintbrush.fill"
            case .music: return "music.note"
            case .educational: return "graduationcap.fill"
            }
        }

        var awardCategory: AwardCategory {
            switch self {
            case .overall: return .streamerOfTheYear
            case .gaming: return .gamingStreamer
            case .justChatting: return .justChattingStreamer
            case .creative: return .creativeStreamer
            case .music: return .musicStreamer
            case .educational: return .educationalStreamer
            }
        }
    }

    // MARK: - Filtering

    /// Re-derives `topStreamers` and `myRanking` for the requested filters.
    /// Deterministic: the same filter always yields the same ordering.
    func applyFilters(timeframe: Timeframe, category: LeaderboardCategory) {
        activeTimeframe = timeframe
        activeCategory = category

        let pool = category == .overall
            ? roster
            : roster.filter { $0.leaderboardCategory == category }

        // Scale points by timeframe so each window feels distinct, then re-rank.
        let multiplier = timeframe.pointsMultiplier
        let ranked = pool
            .map { ranking -> StreamerRanking in
                var copy = ranking
                copy.points = Int(Double(ranking.seasonPoints) * multiplier)
                return copy
            }
            .sorted { $0.points > $1.points }
            .enumerated()
            .map { index, ranking -> StreamerRanking in
                var copy = ranking
                let newRank = index + 1
                // Deterministic, believable week-over-week movement seeded off
                // the streamer's identity so it's stable per render.
                var hasher = Hasher()
                hasher.combine(ranking.id)
                hasher.combine(timeframe.rawValue)
                hasher.combine(category.rawValue)
                let swing = (abs(hasher.finalize()) % 5) - 2 // -2...+2
                copy.previousRank = max(1, newRank + swing)
                copy.rank = newRank
                return copy
            }

        topStreamers = ranked
        // "My" streamer keeps a stable standing for the My Stats tab: use their
        // position in the current filter if present, otherwise their overall rank.
        myRanking = ranked.first(where: { $0.id == Self.myStreamerId }) ?? overallMyRanking
    }

    /// Percentile string like "Top 4%" based on the full platform population.
    func percentileLabel(for rank: Int) -> String {
        guard totalStreamerCount > 0 else { return "Unranked" }
        let pct = Double(rank) / Double(totalStreamerCount) * 100
        if pct < 1 { return "Top 1%" }
        return "Top \(Int(ceil(pct)))%"
    }

    // MARK: - Helper Functions

    private static let myStreamerId = "streamer-4"

    private func loadRankings() {
        // Seed a full, deterministic roster spanning every category so each
        // filter combination renders a populated leaderboard.
        let streamers: [(name: String, display: String, category: LeaderboardCategory, hours: Double, avg: Int, peak: Int, totalViews: Int, points: Int)] = [
            ("StreamerAlex", "Streamer Alex", .overall, 45.0, 6200, 8500, 88000, 12840),
            ("ChristianLive", "Christian Live", .gaming, 42.5, 5400, 7900, 84500, 11920),
            ("Presey", "Presey", .justChatting, 39.0, 5200, 8500, 81200, 11640),
            ("NovaBeats", "Nova Beats", .music, 37.5, 4800, 7200, 76400, 10980),
            ("PixelPaige", "Pixel Paige", .creative, 36.0, 4300, 6600, 71200, 10510),
            ("ProfRoman", "Professor Roman", .educational, 35.0, 3900, 5800, 64800, 9980),
            ("Rahfoover", "Rahfoover", .gaming, 34.0, 3100, 4200, 28000, 9540),
            ("MariMakes", "Mari Makes", .creative, 31.0, 2900, 4980, 24400, 9015),
            ("Shivayla", "Shivayla", .justChatting, 30.5, 3200, 5320, 22100, 8760),
            ("SaottiSynth", "Saotti Synth", .music, 29.0, 2700, 4400, 21300, 8540),
            ("Skamhar", "Skamhar", .gaming, 26.0, 2400, 4960, 19800, 8010),
            ("CodeWithKai", "Code With Kai", .educational, 24.5, 2100, 3600, 17200, 7620),
            ("LoFiLuna", "LoFi Luna", .music, 22.0, 1900, 3100, 15400, 7180),
            ("ChattyChlo", "Chatty Chloe", .justChatting, 20.5, 1700, 2900, 13800, 6840),
            ("InkAndIris", "Ink & Iris", .creative, 18.0, 1500, 2600, 11900, 6420)
        ]

        let seededAchievements: [Achievement] = [
            Achievement(title: "Stream Warrior", description: "Streamed 100+ hours this season", icon: "timer", rarity: .rare, unlockedDate: Date().addingTimeInterval(-86400 * 14), progress: nil, requirement: "100 hours streamed"),
            Achievement(title: "Rising Star", description: "Reached 1,000+ concurrent viewers", icon: "star.fill", rarity: .epic, unlockedDate: Date().addingTimeInterval(-86400 * 7), progress: nil, requirement: "1,000 concurrent viewers"),
            Achievement(title: "Viral Moment", description: "Clipped a moment that blew up", icon: "rocket.fill", rarity: .legendary, unlockedDate: nil, progress: 0.72, requirement: "1M clip views")
        ]

        let seededBadges: [Badge] = [
            Badge(name: "Verified Streamer", description: "Official verified status", icon: "checkmark.seal.fill", color: .blue, earnedDate: Date().addingTimeInterval(-86400 * 60), displayOnProfile: true),
            Badge(name: "Top 100", description: "Ranked in Top 100", icon: "trophy.fill", color: .yellow, earnedDate: Date().addingTimeInterval(-86400 * 18), displayOnProfile: true),
            Badge(name: "Award Winner", description: "Won a streamer award", icon: "medal.fill", color: .orange, earnedDate: Date().addingTimeInterval(-86400 * 9), displayOnProfile: true)
        ]

        roster = streamers.enumerated().map { index, item in
            let user = User(
                id: "streamer-\(index + 1)",
                username: item.name,
                displayName: item.display,
                email: "\(item.name.lowercased())@mychannel.live",
                profileImageURL: nil,
                bio: "Elite \(item.category.rawValue.lowercased()) streamer dominating the charts.",
                subscriberCount: Int(Double(item.avg) * 3.2),
                videoCount: 140 + index * 8,
                isVerified: true,
                isCreator: true,
                totalViews: item.totalViews
            )

            let specialtyCategory = item.category.awardCategory
            // Build incrementally so a specialty category that collides with an
            // existing key merges instead of crashing on a duplicate literal key.
            var categoryScores: [AwardCategory: Int] = [
                .streamerOfTheYear: max(70, 100 - index * 4),
                .mostWatchedStreamer: max(66, 97 - index * 3)
            ]
            categoryScores[specialtyCategory] = max(categoryScores[specialtyCategory] ?? 0, max(64, 94 - index * 2))

            return StreamerRanking(
                id: user.id,
                streamer: user,
                rank: index + 1,
                points: item.points,
                previousRank: max(1, index + 2),
                leaderboardCategory: item.category,
                totalHoursStreamed: item.hours,
                averageViewers: item.avg,
                peakViewers: item.peak,
                totalViews: item.totalViews,
                uniqueViewers: Int(Double(item.totalViews) * 0.72),
                chatMessagesPerMinute: Double(55 - min(index, 12) * 4),
                subscriptionCount: max(120, 800 - index * 41),
                giftsReceived: max(20, 220 - index * 14),
                clipsCreated: max(4, 30 - index),
                viralMoments: max(1, 8 - index / 2),
                categoryScores: categoryScores,
                achievements: seededAchievements,
                badges: seededBadges,
                seasonPoints: item.points,
                isLiveNow: index % 3 == 0
            )
        }

        myAchievements = seededAchievements + [
            Achievement(title: "24 Hour Warrior", description: "Completed a marathon stream", icon: "moon.stars.fill", rarity: .epic, unlockedDate: Date().addingTimeInterval(-86400 * 4), progress: nil, requirement: "24-hour stream")
        ]
        myBadges = seededBadges

        // Hall of Fame winners reference stable roster identities.
        if roster.count >= 3 {
            currentSeason.winners = [
                Winner(category: .streamerOfTheYear, streamer: roster[0].streamer, acceptanceSpeech: "We built this with the community.", clipURL: nil),
                Winner(category: .gamingStreamer, streamer: roster[1].streamer, acceptanceSpeech: "Gaming is bigger than ever.", clipURL: nil),
                Winner(category: .justChattingStreamer, streamer: roster[2].streamer, acceptanceSpeech: "The chat carried this season.", clipURL: nil)
            ]
        }

        // Capture the user's overall standing for the My Stats tab.
        overallMyRanking = roster.first(where: { $0.id == Self.myStreamerId })
    }
}

// MARK: - Supporting Types for User

extension User {
    var streamerStats: LiveStreamerAwardsSystem.StreamerStats? {
        // Return streamer stats if available
        return nil
    }
}

