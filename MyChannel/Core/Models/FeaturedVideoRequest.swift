//
//  FeaturedVideoRequest.swift
//  MyChannel
//
//  Model for featured video requests with payment and duration
//

import Foundation

// MARK: - Featured Video Request
struct FeaturedVideoRequest: Identifiable, Codable, Hashable {
    let id: String
    let videoId: String
    let creatorId: String
    let videoTitle: String
    let videoThumbnail: String
    let creatorName: String
    
    // Payment info
    let requestedDuration: FeaturedDuration
    let amountPaid: Double
    let paymentTransactionId: String
    let paymentStatus: PaymentStatus
    let paidAt: Date
    
    // Admin controls
    let status: RequestStatus
    let reviewedBy: String? // Admin user ID
    let reviewedAt: Date?
    let rejectionReason: String?
    
    // Active featuring
    let featuredAt: Date?
    let expiresAt: Date?
    let isActive: Bool
    
    let createdAt: Date
    let updatedAt: Date
    
    enum FeaturedDuration: String, Codable, CaseIterable {
        case oneDay = "1_day"
        case oneWeek = "1_week"
        case twoWeeks = "2_weeks"
        case oneMonth = "1_month"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .oneDay: return "1 Day"
            case .oneWeek: return "1 Week"
            case .twoWeeks: return "2 Weeks"
            case .oneMonth: return "1 Month"
            case .custom: return "Custom"
            }
        }
        
        var days: Int {
            switch self {
            case .oneDay: return 1
            case .oneWeek: return 7
            case .twoWeeks: return 14
            case .oneMonth: return 30
            case .custom: return 0 // Set manually
            }
        }
        
        var price: Double {
            switch self {
            case .oneDay: return 9.99
            case .oneWeek: return 49.99
            case .twoWeeks: return 89.99
            case .oneMonth: return 299.99
            case .custom: return 0 // Calculated manually
            }
        }
    }
    
    enum PaymentStatus: String, Codable {
        case pending
        case processing
        case completed
        case failed
        case refunded
    }
    
    enum RequestStatus: String, Codable {
        case pending
        case approved
        case rejected
        case active
        case expired
        case cancelled
    }
}

// MARK: - Featured Video (Active)
struct ActiveFeaturedVideo: Identifiable, Codable, Hashable {
    let id: String
    let videoId: String
    let requestId: String
    let creatorId: String
    let videoTitle: String
    let videoThumbnail: String
    let creatorName: String
    
    let featuredAt: Date
    let expiresAt: Date
    let priority: Int // Higher = shown first
    let isActive: Bool
    
    let createdAt: Date
    let updatedAt: Date
}









