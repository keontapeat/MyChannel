//
//  AdModels.swift
//  MyChannel
//
//  SHARED AD MODELS
//  All ad-related types in one place to avoid ambiguity
//

import Foundation

// MARK: - Ad Context

struct AdContext {
    let timeOfDay: Int
    let dayOfWeek: Int
    let deviceType: String
    let placement: AdPlacement
}

// MARK: - Ad Placement

enum AdPlacement: String, Codable {
    case preroll
    case midroll
    case postroll
    case native
    case display
    
    var numericValue: Double {
        switch self {
        case .preroll: return 1.0
        case .midroll: return 2.0
        case .postroll: return 3.0
        case .native: return 4.0
        case .display: return 5.0
        }
    }
}

// MARK: - Creative Type

enum CreativeType: String, Codable {
    case video = "Video"
    case image = "Image"
    case carousel = "Carousel"
}

// MARK: - Creative Status

enum CreativeStatus: String, Codable {
    case pending = "Pending"
    case approved = "Approved"
    case rejected = "Rejected"
}

// MARK: - Ad Creative

struct AdCreative: Identifiable, Codable {
    let id: String
    let name: String
    let thumbnailUrl: String
    let type: CreativeType
    let duration: Int
    let ctr: Double
    let conversions: Int
    let status: CreativeStatus
    let imageURL: String? // ✅ Added for compatibility
    let videoURL: String? // ✅ Added for compatibility
    let isVideo: Bool // ✅ Added for compatibility
    let headline: String? // ✅ Added for CreativePerformanceAgent
    let callToAction: String? // ✅ Added for CreativePerformanceAgent
    let dimensions: String? // ✅ Added for compatibility (e.g., "1920x1080")
}

// MARK: - Campaign Objective

enum CampaignObjective: String, Codable, CaseIterable {
    case awareness = "Brand Awareness"
    case consideration = "Consideration"
    case conversion = "Conversion"
    case conversions = "Conversions" // ✅ Added for Vertex AI compatibility
    case traffic = "Traffic"
    case engagement = "Engagement"
    case videoViews = "Video Views"
    case leadGeneration = "Lead Generation"
    case appInstalls = "App Installs" // ✅ Added for Vertex AI compatibility
    
    var displayName: String {
        rawValue
    }
    
    var title: String {
        rawValue
    }
}

// MARK: - Bid Strategy

enum BidStrategy: String, Codable {
    case automatic = "Automatic" // ✅ Changed from lowestCost
    case manual = "Manual"
    case targetCPA = "Target CPA"
    case targetROAS = "Target ROAS"
}

// MARK: - Campaign Step

enum CampaignStep: String, Codable, CaseIterable, Comparable {
    case objective = "Objective"
    case audience = "Audience"
    case targeting = "Targeting"
    case budget = "Budget"
    case creative = "Creative"
    case review = "Review"
    
    var number: Int {
        switch self {
        case .objective: return 1
        case .audience: return 2
        case .targeting: return 3
        case .budget: return 4
        case .creative: return 5
        case .review: return 6
        }
    }
    
    var title: String {
        rawValue
    }
    
    static func < (lhs: CampaignStep, rhs: CampaignStep) -> Bool {
        lhs.number < rhs.number
    }
}

// MARK: - Ad Campaign (for AdTargetingAGI)

struct AdCampaign: Identifiable, Codable {
    let id: String
    let name: String
    let status: CampaignStatus
    let budget: Double
    let spent: Double
    let totalSpend: Double
    let impressions: Int
    let clicks: Int
    let conversions: Int
    let ctr: Double
    let startDate: Date
    let endDate: Date
    
    // ✅ Additional fields for AdTargetingAGI
    let bidCPM: Double
    let targeting: AdTargeting
}

// MARK: - Campaign Status

enum CampaignStatus: String, Codable {
    case active = "Active"
    case paused = "Paused"
    case completed = "Completed"
    case draft = "Draft"
}

// MARK: - Ad Targeting

struct AdTargeting: Codable {
    let interests: [String]
    let ageRanges: [String]
    let genders: [String]
    let locations: [String]
    let devices: [String] // ✅ Added for AdTargetingAGI compatibility
}

// MARK: - Scored Ad

struct ScoredAd {
    let ad: AdCreative
    let score: Double // Alias for relevanceScore
    let factors: [String: Double]
    
    // Additional fields for AdTargetingAGI
    let campaign: AdCampaign? // For campaign-based scoring
    let relevanceScore: Double
    let predictedCTR: Double
    let expectedValue: Double
    
    // Convenience initializer with just ad and score
    init(ad: AdCreative, score: Double, factors: [String: Double]) {
        self.ad = ad
        self.score = score
        self.factors = factors
        self.campaign = nil
        self.relevanceScore = score
        self.predictedCTR = 0.0
        self.expectedValue = 0.0
    }
    
    // Full initializer for AdTargetingAGI with AdCampaign
    init(ad: AdCampaign, relevanceScore: Double, predictedCTR: Double, expectedValue: Double) {
        // Convert AdCampaign to AdCreative for compatibility
        self.ad = AdCreative(
            id: ad.id,
            name: ad.name,
            thumbnailUrl: "",
            type: .video,
            duration: 30,
            ctr: ad.ctr,
            conversions: ad.conversions,
            status: .approved,
            imageURL: nil,
            videoURL: nil,
            isVideo: true,
            headline: nil,
            callToAction: nil,
            dimensions: "1920x1080"
        )
        self.score = relevanceScore
        self.factors = [:]
        self.campaign = ad
        self.relevanceScore = relevanceScore
        self.predictedCTR = predictedCTR
        self.expectedValue = expectedValue
    }
}

// MARK: - Engagement Data

struct EngagementData {
    // Basic metrics
    let videoWatchTime: TimeInterval
    let likesCount: Int
    let commentsCount: Int
    let sharesCount: Int
    let avgSessionDuration: TimeInterval
    
    // Ad-specific metrics (for AdTargetingAGI)
    let avgCompletionRate: Double
    let adCompletionRate: Double
    let adClickRate: Double
    let adSkipRate: Double
    let avgLikesPerVideo: Double
    let avgCommentsPerVideo: Double
    let avgSharesPerVideo: Double
    let avgSkipRate: Double
}

// MARK: - Fraud Analysis

struct FraudAnalysis {
    let userId: String
    let riskScore: Double  // 0-1
    let fraudScore: Double  // ✅ Added
    let riskLevel: FraudLevel
    let level: FraudLevel  // ✅ Added alias for compatibility
    let indicators: [String]
    let primaryReason: String  // ✅ Added
    let recommendedAction: String
    let isFraud: Bool
    let action: String
    let detectedAt: Date
    
    // ✅ Computed property for FraudDetectionAGI
    var shouldBlock: Bool {
        riskLevel.shouldBlock
    }
}

// MARK: - Fraud Level

enum FraudLevel: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var shouldBlock: Bool {
        self == .high
    }
}

// MARK: - Ad Request

struct AdRequest {
    let requestId: String
    let userId: String
    let timestamp: Date
    let ipAddress: String
    let userAgent: String
    let referrer: String?
    let timeSinceLastRequest: TimeInterval // ✅ Added for FraudDetectionMLAgent
    let recentRequestCount: Int // ✅ Added for FraudDetectionMLAgent
    let fingerprintChangeCount: Int // ✅ Added for FraudDetectionMLAgent
}

