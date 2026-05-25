//
//  FanFundingViewModel.swift
//  MyChannel
//
//  ViewModel for Fan Funding
//

import Foundation
import SwiftUI

struct FundingTier: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let price: Double
    let icon: String
    let colorHex: String // Store as hex string for Codable
    var subscriberCount: Int
    let perks: [String]
    let creatorId: String
    
    // Computed property to get Color from hex
    var color: Color {
        Color(hexString: colorHex) ?? .blue
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, price, icon, colorHex, subscriberCount, perks, creatorId
    }
}

struct FanSupporter: Identifiable, Codable {
    let id: String
    let name: String
    let avatarURL: String
    let tierName: String
    let monthlyAmount: Double
    let isTopSupporter: Bool
    let joinDate: Date
}

struct ExclusiveContent: Identifiable, Codable {
    let id: String
    let title: String
    let thumbnailURL: String
    let requiredTier: String
    let views: Int
    let uploadedAt: Date
}

@MainActor
class FanFundingViewModel: ObservableObject {
    @Published var tiers: [FundingTier] = []
    @Published var topSupporters: [FanSupporter] = []
    @Published var exclusiveContent: [ExclusiveContent] = []
    
    @Published var totalSupporters: Int = 0
    @Published var monthlyRecurring: String = "0"
    @Published var growthRate: Int = 0
    @Published var lifetimeEarnings: String = "0"
    
    @Published var subscriptionRevenue: Int = 0
    @Published var tipRevenue: Int = 0
    @Published var contentRevenue: Int = 0
    
    func loadFundingData() async {
        // Load from Firestore
        totalSupporters = 487
        monthlyRecurring = "4,850"
        growthRate = 23
        lifetimeEarnings = "28.5K"
        
        subscriptionRevenue = 3640
        tipRevenue = 730
        contentRevenue = 480
        
        // Mock tiers
        tiers = [
            FundingTier(
                id: "1",
                name: "Bronze Member",
                description: "Get access to exclusive content and behind-the-scenes",
                price: 4.99,
                icon: "medal.fill",
                colorHex: "#CC8033", // Bronze color
                subscriberCount: 234,
                perks: [
                    "Exclusive videos every week",
                    "Behind-the-scenes content",
                    "Early access to new videos",
                    "Member-only community chat"
                ],
                creatorId: "creator1"
            ),
            FundingTier(
                id: "2",
                name: "Silver Member",
                description: "Get everything in Bronze plus live streams and Q&As",
                price: 9.99,
                icon: "star.fill",
                colorHex: "#B3B3B3", // Silver color
                subscriberCount: 156,
                perks: [
                    "Everything in Bronze",
                    "Weekly live streams",
                    "Priority Q&A responses",
                    "Custom badge and emoji",
                    "Members-only polls"
                ],
                creatorId: "creator1"
            ),
            FundingTier(
                id: "3",
                name: "Gold Member",
                description: "Ultimate access with personal shoutouts and more",
                price: 24.99,
                icon: "crown.fill",
                colorHex: "#FFCC00", // Gold color
                subscriberCount: 97,
                perks: [
                    "Everything in Silver",
                    "Monthly personal shoutout",
                    "1-on-1 video call (quarterly)",
                    "Vote on content ideas",
                    "Exclusive merchandise",
                    "Your name in video credits"
                ],
                creatorId: "creator1"
            )
        ]
        
        // Mock supporters
        topSupporters = [
            FanSupporter(
                id: "1",
                name: "Sarah M.",
                avatarURL: "",
                tierName: "Gold Member",
                monthlyAmount: 24.99,
                isTopSupporter: true,
                joinDate: Date().addingTimeInterval(-86400 * 365)
            ),
            FanSupporter(
                id: "2",
                name: "Mike Johnson",
                avatarURL: "",
                tierName: "Gold Member",
                monthlyAmount: 24.99,
                isTopSupporter: true,
                joinDate: Date().addingTimeInterval(-86400 * 300)
            ),
            FanSupporter(
                id: "3",
                name: "Emma Wilson",
                avatarURL: "",
                tierName: "Silver Member",
                monthlyAmount: 9.99,
                isTopSupporter: false,
                joinDate: Date().addingTimeInterval(-86400 * 180)
            )
        ]
        
        // Mock exclusive content
        exclusiveContent = [
            ExclusiveContent(
                id: "1",
                title: "Behind the Scenes: How I Edit My Videos",
                thumbnailURL: "",
                requiredTier: "Bronze+",
                views: 1234,
                uploadedAt: Date().addingTimeInterval(-86400 * 7)
            ),
            ExclusiveContent(
                id: "2",
                title: "My Secret Productivity System Revealed",
                thumbnailURL: "",
                requiredTier: "Silver+",
                views: 856,
                uploadedAt: Date().addingTimeInterval(-86400 * 14)
            )
        ]
    }
}

