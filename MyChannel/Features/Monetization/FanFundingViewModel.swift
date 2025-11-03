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
    let color: Color
    var subscriberCount: Int
    let perks: [String]
    let creatorId: String
}

extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        let alpha = try container.decode(Double.self, forKey: .alpha)
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let components = self.components()
        try container.encode(components.red, forKey: .red)
        try container.encode(components.green, forKey: .green)
        try container.encode(components.blue, forKey: .blue)
        try container.encode(components.alpha, forKey: .alpha)
    }
    
    private func components() -> (red: Double, green: Double, blue: Double, alpha: Double) {
        #if os(macOS)
        let nsColor = NSColor(self)
        return (
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
        #else
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
        #endif
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
                color: Color(red: 0.8, green: 0.5, blue: 0.2),
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
                color: Color(red: 0.7, green: 0.7, blue: 0.7),
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
                color: Color(red: 1.0, green: 0.8, blue: 0.0),
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

