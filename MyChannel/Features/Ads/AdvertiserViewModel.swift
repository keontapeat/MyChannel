//
//  AdvertiserViewModel.swift
//  MyChannel
//
//  ViewModel for Advertiser Dashboard
//

import Foundation
import SwiftUI

@MainActor
class AdvertiserViewModel: ObservableObject {
    // Stats
    @Published var totalImpressions: Int = 0
    @Published var totalClicks: Int = 0
    @Published var totalConversions: Int = 0
    @Published var totalSpend: Double = 0
    @Published var accountBalance: Double = 0
    
    // Calculated metrics
    @Published var ctr: Double = 0
    @Published var conversionRate: Double = 0
    @Published var avgCPC: Double = 0
    @Published var roi: Double = 0
    
    // Changes
    @Published var impressionsChange: Double = 0
    @Published var clicksChange: Double = 0
    @Published var ctrChange: Double = 0
    @Published var roiChange: Double = 0
    
    // Percentages
    @Published var clickPercentage: Double = 0
    @Published var conversionPercentage: Double = 0
    
    // Data
    @Published var campaigns: [AdvertiserCampaign] = []
    @Published var performanceData: [PerformanceDataPoint] = []
    @Published var aiInsights: [String] = []
    @Published var topCreatives: [Creative] = []
    @Published var paymentMethods: [PaymentMethod] = []
    @Published var transactions: [AdvertiserTransaction] = []
    @Published var audiences: [Audience] = []
    @Published var creatives: [Creative] = []
    
    // UI State
    @Published var showingAddFunds = false
    @Published var showingAddPaymentMethod = false
    @Published var showingCreateAudience = false
    @Published var showingUploadCreative = false
    
    func loadData() async {
        // Simulate loading data from Firestore/API
        await loadStats()
        await loadCampaigns()
        await loadPerformanceData()
        await loadAIInsights()
        await loadTopCreatives()
        await loadPaymentMethods()
        await loadTransactions()
        await loadAudiences()
        await loadCreatives()
        
        calculateMetrics()
    }
    
    private func loadStats() async {
        // TODO: Load from Firestore
        totalImpressions = Int.random(in: 100000...1000000)
        totalClicks = Int.random(in: 5000...50000)
        totalConversions = Int.random(in: 500...5000)
        totalSpend = Double.random(in: 5000...50000)
        accountBalance = Double.random(in: 10000...100000)
        
        impressionsChange = Double.random(in: -20...50)
        clicksChange = Double.random(in: -15...40)
        ctrChange = Double.random(in: -10...30)
        roiChange = Double.random(in: 0...100)
    }
    
    private func loadCampaigns() async {
        campaigns = [
            AdvertiserCampaign(
                id: "1",
                name: "Summer Sale 2025",
                status: .active,
                budget: 10000,
                spent: 3456.78,
                totalSpend: 3456.78,
                impressions: 250000,
                clicks: 12500,
                conversions: 1250,
                ctr: 5.0,
                startDate: Date(),
                endDate: Date().addingTimeInterval(30*24*60*60)
            ),
            AdvertiserCampaign(
                id: "2",
                name: "Brand Awareness Campaign",
                status: .active,
                budget: 5000,
                spent: 4123.45,
                totalSpend: 4123.45,
                impressions: 180000,
                clicks: 9000,
                conversions: 450,
                ctr: 5.0,
                startDate: Date(),
                endDate: Date().addingTimeInterval(60*24*60*60)
            ),
            AdvertiserCampaign(
                id: "3",
                name: "Product Launch",
                status: .paused,
                budget: 15000,
                spent: 8234.56,
                totalSpend: 8234.56,
                impressions: 350000,
                clicks: 17500,
                conversions: 2100,
                ctr: 5.0,
                startDate: Date(),
                endDate: Date().addingTimeInterval(45*24*60*60)
            )
        ]
    }
    
    private func loadPerformanceData() async {
        let calendar = Calendar.current
        let today = Date()
        
        performanceData = (0..<30).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            return PerformanceDataPoint(
                date: date,
                impressions: Int.random(in: 5000...50000),
                clicks: Int.random(in: 100...2000),
                conversions: Int.random(in: 10...200)
            )
        }.reversed()
    }
    
    private func loadAIInsights() async {
        aiInsights = [
            "💡 Increase budget by 20% on 'Summer Sale 2025' for 3x more conversions",
            "💡 Best performing time: 8-10pm EST - schedule more ads during this window",
            "💡 Audience 25-34 converting at 18% - consider creating a dedicated campaign",
            "💡 Video Creative #3 has 12% CTR - use this for all placements",
            "💡 Your ROI is 850% - 3x better than industry average! Keep it up!"
        ]
    }
    
    private func loadTopCreatives() async {
        topCreatives = [
            Creative(
                id: "c1",
                name: "Summer Sale Video",
                thumbnailUrl: "https://picsum.photos/300/200?random=1",
                type: .video,
                duration: 15,
                ctr: 12.5,
                conversions: 1200,
                status: .approved
            ),
            Creative(
                id: "c2",
                name: "Brand Story",
                thumbnailUrl: "https://picsum.photos/300/200?random=2",
                type: .video,
                duration: 30,
                ctr: 8.3,
                conversions: 890,
                status: .approved
            ),
            Creative(
                id: "c3",
                name: "Product Demo",
                thumbnailUrl: "https://picsum.photos/300/200?random=3",
                type: .video,
                duration: 20,
                ctr: 10.1,
                conversions: 1050,
                status: .approved
            )
        ]
    }
    
    private func loadPaymentMethods() async {
        paymentMethods = [
            PaymentMethod(
                id: "pm1",
                name: "Visa",
                type: .card,
                last4: "4242",
                isDefault: true
            ),
            PaymentMethod(
                id: "pm2",
                name: "Bank Account",
                type: .bank,
                last4: "6789",
                isDefault: false
            )
        ]
    }
    
    private func loadTransactions() async {
        transactions = [
            AdvertiserTransaction(
                id: "t1",
                description: "Campaign Charge - Summer Sale",
                amount: 234.56,
                type: .debit,
                date: Date()
            ),
            AdvertiserTransaction(
                id: "t2",
                description: "Account Funding",
                amount: 10000,
                type: .credit,
                date: Date().addingTimeInterval(-86400)
            ),
            AdvertiserTransaction(
                id: "t3",
                description: "Campaign Charge - Brand Awareness",
                amount: 156.78,
                type: .debit,
                date: Date().addingTimeInterval(-172800)
            )
        ]
    }
    
    private func loadAudiences() async {
        audiences = [
            Audience(
                id: "a1",
                name: "Tech Enthusiasts",
                description: "Users interested in technology, gadgets, and innovation",
                size: 2500000,
                tags: ["Tech", "Gaming", "Innovation"]
            ),
            Audience(
                id: "a2",
                name: "Fashion Lovers",
                description: "Users interested in fashion, beauty, and lifestyle",
                size: 1800000,
                tags: ["Fashion", "Beauty", "Lifestyle"]
            ),
            Audience(
                id: "a3",
                name: "Fitness Community",
                description: "Users interested in fitness, health, and wellness",
                size: 1200000,
                tags: ["Fitness", "Health", "Wellness"]
            )
        ]
    }
    
    private func loadCreatives() async {
        creatives = topCreatives + [
            Creative(
                id: "c4",
                name: "Holiday Special",
                thumbnailUrl: "https://picsum.photos/300/200?random=4",
                type: .video,
                duration: 15,
                ctr: 6.5,
                conversions: 450,
                status: .pending
            ),
            Creative(
                id: "c5",
                name: "Customer Testimonials",
                thumbnailUrl: "https://picsum.photos/300/200?random=5",
                type: .video,
                duration: 25,
                ctr: 7.2,
                conversions: 580,
                status: .approved
            )
        ]
    }
    
    private func calculateMetrics() {
        // CTR
        if totalImpressions > 0 {
            ctr = (Double(totalClicks) / Double(totalImpressions)) * 100
            clickPercentage = (Double(totalClicks) / Double(totalImpressions)) * 100
        }
        
        // Conversion Rate
        if totalClicks > 0 {
            conversionRate = (Double(totalConversions) / Double(totalClicks)) * 100
            conversionPercentage = (Double(totalConversions) / Double(totalClicks)) * 100
        }
        
        // Average CPC
        if totalClicks > 0 {
            avgCPC = totalSpend / Double(totalClicks)
        }
        
        // ROI (assuming $10 per conversion)
        let revenue = Double(totalConversions) * 10.0
        if totalSpend > 0 {
            roi = ((revenue - totalSpend) / totalSpend) * 100
        }
    }
    
    func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

// MARK: - Models

// ✅ Renamed to AdvertiserCampaign to avoid conflict with AdModels.AdCampaign
struct AdvertiserCampaign: Identifiable, Codable {
    let id: String
    let name: String
    let status: CampaignStatus
    let budget: Double
    let spent: Double
    let totalSpend: Double  // ✅ Added for Vertex AI compatibility
    let impressions: Int
    let clicks: Int
    let conversions: Int
    let ctr: Double
    let startDate: Date
    let endDate: Date
}

struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let impressions: Int
    let clicks: Int
    let conversions: Int
}

struct Creative: Identifiable, Codable {
    let id: String
    let name: String
    let thumbnailUrl: String
    let type: CreativeType
    let duration: Int
    let ctr: Double
    let conversions: Int
    let status: CreativeStatus
}

// ✅ CreativeType and CreativeStatus are now defined in AdModels.swift

struct PaymentMethod: Identifiable {
    let id: String
    let name: String
    let type: AdvertiserPaymentType
    let last4: String
    let isDefault: Bool
}

enum AdvertiserPaymentType {
    case card
    case bank
}

struct AdvertiserTransaction: Identifiable {
    let id: String
    let description: String
    let amount: Double
    let type: AdvertiserTransactionType
    let date: Date
}

enum AdvertiserTransactionType {
    case credit
    case debit
}

struct Audience: Identifiable {
    let id: String
    let name: String
    let description: String
    let size: Int
    let tags: [String]
}

