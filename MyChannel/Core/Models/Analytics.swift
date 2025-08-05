//
//  Analytics.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Charts

// MARK: - Video Analytics Model
struct VideoAnalytics: Identifiable, Codable, Equatable {
    let id: String
    let videoId: String
    let views: Int
    let uniqueViews: Int
    let likes: Int
    let dislikes: Int
    let comments: Int
    let shares: Int
    let watchTime: TimeInterval // Total watch time in seconds
    let averageWatchTime: TimeInterval
    let clickThroughRate: Double // Percentage
    let engagementRate: Double // Percentage
    let revenue: Double
    let date: Date
    
    init(
        id: String = UUID().uuidString,
        videoId: String,
        views: Int = 0,
        uniqueViews: Int = 0,
        likes: Int = 0,
        dislikes: Int = 0,
        comments: Int = 0,
        shares: Int = 0,
        watchTime: TimeInterval = 0,
        averageWatchTime: TimeInterval = 0,
        clickThroughRate: Double = 0.0,
        engagementRate: Double = 0.0,
        revenue: Double = 0.0,
        date: Date = Date()
    ) {
        self.id = id
        self.videoId = videoId
        self.views = views
        self.uniqueViews = uniqueViews
        self.likes = likes
        self.dislikes = dislikes
        self.comments = comments
        self.shares = shares
        self.watchTime = watchTime
        self.averageWatchTime = averageWatchTime
        self.clickThroughRate = clickThroughRate
        self.engagementRate = engagementRate
        self.revenue = revenue
        self.date = date
    }
    
    var totalEngagements: Int {
        likes + dislikes + comments + shares
    }
    
    var watchTimeHours: Double {
        watchTime / 3600
    }
    
    // MARK: - Equatable
    static func == (lhs: VideoAnalytics, rhs: VideoAnalytics) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Analytics Period Enum
enum AnalyticsPeriod: String, CaseIterable, Codable {
    case last7Days = "last_7_days"
    case last30Days = "last_30_days"
    case lastMonth = "last_month"
    case last90Days = "last_90_days"
    case lastYear = "last_year"
    case allTime = "all_time"
    
    var displayName: String {
        switch self {
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .lastMonth: return "Last Month"
        case .last90Days: return "Last 90 Days"
        case .lastYear: return "Last Year"
        case .allTime: return "All Time"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .last7Days:
            return (calendar.date(byAdding: .day, value: -7, to: now) ?? now, now)
        case .last30Days:
            return (calendar.date(byAdding: .day, value: -30, to: now) ?? now, now)
        case .lastMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: calendar.date(byAdding: .month, value: -1, to: now) ?? now)?.start ?? now
            let endOfMonth = calendar.dateInterval(of: .month, for: calendar.date(byAdding: .month, value: -1, to: now) ?? now)?.end ?? now
            return (startOfMonth, endOfMonth)
        case .last90Days:
            return (calendar.date(byAdding: .day, value: -90, to: now) ?? now, now)
        case .lastYear:
            return (calendar.date(byAdding: .year, value: -1, to: now) ?? now, now)
        case .allTime:
            return (calendar.date(from: DateComponents(year: 2020, month: 1, day: 1)) ?? now, now)
        }
    }
}

// MARK: - Channel Analytics Model
struct ChannelAnalytics: Codable, Equatable {
    let totalViews: Int
    let totalSubscribers: Int
    let totalVideos: Int
    let totalWatchTime: TimeInterval
    let totalRevenue: Double
    let averageViewsPerVideo: Double
    let subscriberGrowthRate: Double
    let topPerformingVideos: [String] // Video IDs
    let viewsByCountry: [String: Int]
    let viewsByAge: [String: Int]
    let viewsByGender: [String: Int]
    let revenueBySource: [String: Double]
    let period: AnalyticsPeriod
    let lastUpdated: Date
    
    init(
        totalViews: Int = 0,
        totalSubscribers: Int = 0,
        totalVideos: Int = 0,
        totalWatchTime: TimeInterval = 0,
        totalRevenue: Double = 0.0,
        averageViewsPerVideo: Double = 0.0,
        subscriberGrowthRate: Double = 0.0,
        topPerformingVideos: [String] = [],
        viewsByCountry: [String: Int] = [:],
        viewsByAge: [String: Int] = [:],
        viewsByGender: [String: Int] = [:],
        revenueBySource: [String: Double] = [:],
        period: AnalyticsPeriod = .lastMonth,
        lastUpdated: Date = Date()
    ) {
        self.totalViews = totalViews
        self.totalSubscribers = totalSubscribers
        self.totalVideos = totalVideos
        self.totalWatchTime = totalWatchTime
        self.totalRevenue = totalRevenue
        self.averageViewsPerVideo = averageViewsPerVideo
        self.subscriberGrowthRate = subscriberGrowthRate
        self.topPerformingVideos = topPerformingVideos
        self.viewsByCountry = viewsByCountry
        self.viewsByAge = viewsByAge
        self.viewsByGender = viewsByGender
        self.revenueBySource = revenueBySource
        self.period = period
        self.lastUpdated = lastUpdated
    }
    
    var watchTimeHours: Double {
        totalWatchTime / 3600
    }
    
    var estimatedEarningsPerThousandViews: Double {
        guard totalViews > 0 else { return 0.0 }
        return (totalRevenue / Double(totalViews)) * 1000
    }
    
    // MARK: - Equatable
    static func == (lhs: ChannelAnalytics, rhs: ChannelAnalytics) -> Bool {
        lhs.totalViews == rhs.totalViews &&
        lhs.totalSubscribers == rhs.totalSubscribers &&
        lhs.period == rhs.period
    }
}

// MARK: - Analytics Chart Data
struct AnalyticsChartData: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let views: Int
    let subscribers: Int
    let revenue: Double
    let watchTime: TimeInterval
    
    var watchTimeHours: Double {
        watchTime / 3600
    }
}

// MARK: - Analytics Service Interface
protocol AnalyticsServiceProtocol {
    func getVideoAnalytics(videoId: String, period: AnalyticsPeriod) async throws -> VideoAnalytics
    func getChannelAnalytics(creatorId: String, period: AnalyticsPeriod) async throws -> ChannelAnalytics
    func getAnalyticsChartData(creatorId: String, period: AnalyticsPeriod) async throws -> [AnalyticsChartData]
    func getTopPerformingVideos(creatorId: String, limit: Int) async throws -> [VideoAnalytics]
    func trackVideoView(videoId: String, userId: String?, watchTime: TimeInterval) async throws
    func trackVideoEngagement(videoId: String, type: EngagementType, userId: String?) async throws
}

// MARK: - Engagement Type Enum
enum EngagementType: String, Codable {
    case like = "like"
    case dislike = "dislike"
    case comment = "comment"
    case share = "share"
    case subscribe = "subscribe"
}

// MARK: - Mock Analytics Service
class MockAnalyticsService: AnalyticsServiceProtocol, ObservableObject {
    @Published var isLoading = false
    
    func getVideoAnalytics(videoId: String, period: AnalyticsPeriod) async throws -> VideoAnalytics {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return VideoAnalytics(
            videoId: videoId,
            views: Int.random(in: 1000...100000),
            uniqueViews: Int.random(in: 800...80000),
            likes: Int.random(in: 50...5000),
            dislikes: Int.random(in: 5...500),
            comments: Int.random(in: 10...1000),
            shares: Int.random(in: 5...500),
            watchTime: TimeInterval.random(in: 5000...50000),
            averageWatchTime: TimeInterval.random(in: 120...600),
            clickThroughRate: Double.random(in: 2...15),
            engagementRate: Double.random(in: 3...12),
            revenue: Double.random(in: 10...1000)
        )
    }
    
    func getChannelAnalytics(creatorId: String, period: AnalyticsPeriod) async throws -> ChannelAnalytics {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 700_000_000) // 0.7 seconds
        
        return ChannelAnalytics(
            totalViews: Int.random(in: 10000...1000000),
            totalSubscribers: Int.random(in: 1000...100000),
            totalVideos: Int.random(in: 50...500),
            totalWatchTime: TimeInterval.random(in: 100000...1000000),
            totalRevenue: Double.random(in: 500...10000),
            averageViewsPerVideo: Double.random(in: 1000...5000),
            subscriberGrowthRate: Double.random(in: -5...25),
            topPerformingVideos: Array(Video.sampleVideos.prefix(5).map { $0.id }),
            viewsByCountry: [
                "United States": Int.random(in: 1000...5000),
                "Canada": Int.random(in: 500...2000),
                "United Kingdom": Int.random(in: 300...1500),
                "Australia": Int.random(in: 200...1000),
                "Germany": Int.random(in: 400...1800)
            ],
            viewsByAge: [
                "13-17": Int.random(in: 100...800),
                "18-24": Int.random(in: 500...2000),
                "25-34": Int.random(in: 800...3000),
                "35-44": Int.random(in: 400...1500),
                "45-54": Int.random(in: 200...800),
                "55+": Int.random(in: 100...500)
            ],
            viewsByGender: [
                "Male": Int.random(in: 2000...6000),
                "Female": Int.random(in: 1500...4000),
                "Other": Int.random(in: 100...500)
            ],
            revenueBySource: [
                "Ad Revenue": Double.random(in: 200...4000),
                "Channel Memberships": Double.random(in: 50...1000),
                "Super Chat": Double.random(in: 20...500),
                "Tips": Double.random(in: 10...300)
            ],
            period: period
        )
    }
    
    func getAnalyticsChartData(creatorId: String, period: AnalyticsPeriod) async throws -> [AnalyticsChartData] {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        let dateRange = period.dateRange
        let calendar = Calendar.current
        var chartData: [AnalyticsChartData] = []
        
        let days = calendar.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 30
        
        for i in 0..<min(days, 30) {
            if let date = calendar.date(byAdding: .day, value: i, to: dateRange.start) {
                chartData.append(
                    AnalyticsChartData(
                        date: date,
                        views: Int.random(in: 100...2000),
                        subscribers: Int.random(in: 10...100),
                        revenue: Double.random(in: 5...200),
                        watchTime: TimeInterval.random(in: 1000...10000)
                    )
                )
            }
        }
        
        return chartData.sorted { $0.date < $1.date }
    }
    
    func getTopPerformingVideos(creatorId: String, limit: Int) async throws -> [VideoAnalytics] {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        return Video.sampleVideos.prefix(limit).map { video in
            VideoAnalytics(
                videoId: video.id,
                views: video.viewCount,
                uniqueViews: Int(Double(video.viewCount) * 0.8),
                likes: video.likeCount,
                dislikes: video.dislikeCount,
                comments: video.commentCount,
                shares: Int.random(in: 10...500),
                watchTime: TimeInterval(video.viewCount) * Double.random(in: 60...300),
                averageWatchTime: TimeInterval.random(in: 120...600),
                clickThroughRate: Double.random(in: 2...15),
                engagementRate: Double.random(in: 3...12),
                revenue: video.monetization.totalRevenue
            )
        }
    }
    
    func trackVideoView(videoId: String, userId: String?, watchTime: TimeInterval) async throws {
        // Simulate tracking
        print("Tracked view for video \(videoId), watch time: \(watchTime)")
    }
    
    func trackVideoEngagement(videoId: String, type: EngagementType, userId: String?) async throws {
        // Simulate tracking
        print("Tracked \(type.rawValue) for video \(videoId)")
    }
}

// MARK: - Sample Data
extension VideoAnalytics {
    static let sampleAnalytics: [VideoAnalytics] = [
        VideoAnalytics(
            videoId: Video.sampleVideos[0].id,
            views: 45680,
            uniqueViews: 38400,
            likes: 3200,
            dislikes: 45,
            comments: 328,
            shares: 156,
            watchTime: 285430, // ~79 hours
            averageWatchTime: 375, // ~6 minutes
            clickThroughRate: 8.5,
            engagementRate: 7.2,
            revenue: 234.50
        ),
        VideoAnalytics(
            videoId: Video.sampleVideos[1].id,
            views: 128340,
            uniqueViews: 105600,
            likes: 8900,
            dislikes: 123,
            comments: 567,
            shares: 445,
            watchTime: 542180, // ~150 hours
            averageWatchTime: 254, // ~4 minutes
            clickThroughRate: 12.3,
            engagementRate: 9.8,
            revenue: 687.20
        )
    ]
}

struct Analytics_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Analytics Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Channel Overview
                VStack(alignment: .leading, spacing: 16) {
                    Text("Channel Overview")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        VStack {
                            Text("1.2M")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Total Views")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        VStack {
                            Text("45.6K")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Subscribers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        VStack {
                            Text("$3,456")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Revenue")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        
                        VStack {
                            Text("156")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("Videos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Top Performing Videos
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Performing Videos")
                        .font(.headline)
                    
                    ForEach(VideoAnalytics.sampleAnalytics.prefix(2)) { analytics in
                        HStack {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 45)
                                .cornerRadius(6)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Video Title")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                HStack {
                                    Text("\(analytics.views.formatted()) views")
                                    Text("•")
                                    Text("\(analytics.likes.formatted()) likes")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("$\(analytics.revenue, specifier: "%.2f")")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                                
                                Text("\(analytics.engagementRate, specifier: "%.1f")% engagement")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}