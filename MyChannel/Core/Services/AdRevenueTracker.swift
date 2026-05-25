//
//  AdRevenueTracker.swift
//  MyChannel
//
//  🔥💰 REAL-TIME AD REVENUE TRACKING - SHOW ME THE MONEY! 💰🔥
//

import Foundation
import SwiftUI
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - 💰 Ad Revenue Event

struct AdRevenueEvent: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let adType: AdType
    let adNetwork: String
    let estimatedRevenue: Double
    let currency: String
    let videoId: String?
    let creatorId: String?
    let impressionId: String?
    
    enum AdType: String, Codable {
        case preroll = "preroll"
        case midroll = "midroll"
        case postroll = "postroll"
        case rewarded = "rewarded"
        case interstitial = "interstitial"
        case banner = "banner"
        case native = "native"
        case appOpen = "app_open"
    }
    
    init(
        adType: AdType,
        adNetwork: String = "admob",
        estimatedRevenue: Double,
        videoId: String? = nil,
        creatorId: String? = nil
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.adType = adType
        self.adNetwork = adNetwork
        self.estimatedRevenue = estimatedRevenue
        self.currency = "USD"
        self.videoId = videoId
        self.creatorId = creatorId
        self.impressionId = UUID().uuidString
    }
}

// MARK: - 💰 Ad Revenue Tracker

@MainActor
final class AdRevenueTracker: ObservableObject {
    static let shared = AdRevenueTracker()
    
    // MARK: - Published State
    @Published var todayRevenue: Double = 0.0
    @Published var weekRevenue: Double = 0.0
    @Published var monthRevenue: Double = 0.0
    @Published var lifetimeRevenue: Double = 0.0
    
    @Published var todayImpressions: Int = 0
    @Published var todayClicks: Int = 0
    @Published var averageECPM: Double = 0.0
    
    @Published var recentEvents: [AdRevenueEvent] = []
    @Published var isLoading = false
    
    // Revenue by ad type
    @Published var revenueByType: [AdRevenueEvent.AdType: Double] = [:]
    
    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // eCPM estimates by ad type (industry averages)
    private let ecpmEstimates: [AdRevenueEvent.AdType: Double] = [
        .rewarded: 15.0,      // $15 eCPM for rewarded video
        .interstitial: 8.0,   // $8 eCPM for interstitial
        .preroll: 12.0,       // $12 eCPM for pre-roll video
        .midroll: 14.0,       // $14 eCPM for mid-roll (higher engagement)
        .postroll: 6.0,       // $6 eCPM for post-roll (lower engagement)
        .banner: 1.5,         // $1.50 eCPM for banner
        .native: 5.0,         // $5 eCPM for native
        .appOpen: 10.0        // $10 eCPM for app open
    ]
    
    private init() {
        loadCachedRevenue()
    }
    
    // MARK: - Track Ad Events
    
    /// Track an ad impression and calculate revenue
    func trackImpression(
        adType: AdRevenueEvent.AdType,
        adNetwork: String = "admob",
        videoId: String? = nil,
        creatorId: String? = nil,
        customECPM: Double? = nil
    ) {
        let ecpm = customECPM ?? ecpmEstimates[adType] ?? 5.0
        let revenue = ecpm / 1000.0 // eCPM is per 1000 impressions
        
        let event = AdRevenueEvent(
            adType: adType,
            adNetwork: adNetwork,
            estimatedRevenue: revenue,
            videoId: videoId,
            creatorId: creatorId
        )
        
        // Update local state
        todayRevenue += revenue
        lifetimeRevenue += revenue
        todayImpressions += 1
        recentEvents.insert(event, at: 0)
        
        // Keep only last 100 events
        if recentEvents.count > 100 {
            recentEvents = Array(recentEvents.prefix(100))
        }
        
        // Update by type
        revenueByType[adType, default: 0] += revenue
        
        // Calculate average eCPM
        if todayImpressions > 0 {
            averageECPM = (todayRevenue * 1000) / Double(todayImpressions)
        }
        
        // Save to cache
        saveCachedRevenue()
        
        // Save to Firebase
        Task {
            await saveToFirebase(event: event)
        }
        
        print("💰 [AdRevenue] Tracked \(adType.rawValue) impression: $\(String(format: "%.4f", revenue))")
        print("📊 [AdRevenue] Today's total: $\(String(format: "%.2f", todayRevenue)) (\(todayImpressions) impressions)")
    }
    
    /// Track an ad click (worth more!)
    func trackClick(adType: AdRevenueEvent.AdType) {
        todayClicks += 1
        
        // Clicks add bonus revenue (typically 10-20x impression value)
        let clickBonus = (ecpmEstimates[adType] ?? 5.0) / 1000.0 * 15.0
        todayRevenue += clickBonus
        lifetimeRevenue += clickBonus
        
        saveCachedRevenue()
        
        print("👆 [AdRevenue] Click tracked! Bonus: $\(String(format: "%.4f", clickBonus))")
    }
    
    /// Track completed rewarded video (full watch)
    func trackRewardedComplete(videoId: String? = nil, creatorId: String? = nil) {
        // Rewarded video completion is worth more than just impression
        let completionBonus = 0.02 // $20 eCPM equivalent for completed view
        
        let event = AdRevenueEvent(
            adType: .rewarded,
            adNetwork: "admob",
            estimatedRevenue: completionBonus,
            videoId: videoId,
            creatorId: creatorId
        )
        
        todayRevenue += completionBonus
        lifetimeRevenue += completionBonus
        recentEvents.insert(event, at: 0)
        revenueByType[.rewarded, default: 0] += completionBonus
        
        saveCachedRevenue()
        
        Task {
            await saveToFirebase(event: event)
        }
        
        print("🎉 [AdRevenue] Rewarded video completed! Revenue: $\(String(format: "%.4f", completionBonus))")
    }
    
    // MARK: - Firebase Sync
    
    private func saveToFirebase(event: AdRevenueEvent) async {
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            
            // Save event
            var eventData: [String: Any] = [
                "id": event.id,
                "timestamp": FieldValue.serverTimestamp(),
                "adType": event.adType.rawValue,
                "adNetwork": event.adNetwork,
                "estimatedRevenue": event.estimatedRevenue,
                "currency": event.currency,
                "impressionId": event.impressionId ?? ""
            ]
            
            if let videoId = event.videoId {
                eventData["videoId"] = videoId
            }
            if let creatorId = event.creatorId {
                eventData["creatorId"] = creatorId
            }
            
            try await db.collection("ad_revenue_events")
                .document(event.id)
                .setData(eventData)
            
            // Update aggregates
            let today = Calendar.current.startOfDay(for: Date())
            let dateString = ISO8601DateFormatter().string(from: today)
            
            try await db.collection("ad_revenue_daily")
                .document(dateString)
                .setData([
                    "date": today,
                    "revenue": FieldValue.increment(event.estimatedRevenue),
                    "impressions": FieldValue.increment(Int64(1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            
            print("✅ [AdRevenue] Saved to Firebase")
        } catch {
            print("❌ [AdRevenue] Firebase error: \(error)")
        }
        #endif
    }
    
    // MARK: - Fetch From Firebase
    
    func fetchRevenueData() async {
        isLoading = true
        
        #if canImport(FirebaseFirestore)
        do {
            let db = Firestore.firestore()
            
            // Fetch today's aggregate
            let today = Calendar.current.startOfDay(for: Date())
            let dateString = ISO8601DateFormatter().string(from: today)
            
            let todayDoc = try await db.collection("ad_revenue_daily")
                .document(dateString)
                .getDocument()
            
            if let data = todayDoc.data() {
                await MainActor.run {
                    self.todayRevenue = data["revenue"] as? Double ?? 0
                    self.todayImpressions = data["impressions"] as? Int ?? 0
                }
            }
            
            // Fetch week aggregate
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
            let weekDocs = try await db.collection("ad_revenue_daily")
                .whereField("date", isGreaterThanOrEqualTo: weekAgo)
                .getDocuments()
            
            let weekTotal = weekDocs.documents.compactMap { $0.data()["revenue"] as? Double }.reduce(0, +)
            await MainActor.run {
                self.weekRevenue = weekTotal
            }
            
            // Fetch lifetime from user doc
            if let userId = AuthenticationManager.shared.currentUser?.id {
                let userEarnings = try await db.collection("creator_earnings")
                    .document(userId)
                    .getDocument()
                
                if let data = userEarnings.data() {
                    await MainActor.run {
                        self.lifetimeRevenue = data["totalEarnings"] as? Double ?? 0
                    }
                }
            }
            
            print("✅ [AdRevenue] Fetched revenue data from Firebase")
            
        } catch {
            print("❌ [AdRevenue] Failed to fetch: \(error)")
        }
        #endif
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Local Cache
    
    private func loadCachedRevenue() {
        todayRevenue = userDefaults.double(forKey: "adRevenue_today")
        lifetimeRevenue = userDefaults.double(forKey: "adRevenue_lifetime")
        todayImpressions = userDefaults.integer(forKey: "adRevenue_todayImpressions")
        todayClicks = userDefaults.integer(forKey: "adRevenue_todayClicks")
        
        // Check if we need to reset daily stats
        let lastDate = userDefaults.object(forKey: "adRevenue_lastDate") as? Date ?? Date.distantPast
        if !Calendar.current.isDateInToday(lastDate) {
            // New day, reset daily stats
            todayRevenue = 0
            todayImpressions = 0
            todayClicks = 0
            recentEvents = []
            revenueByType = [:]
            saveCachedRevenue()
        }
    }
    
    private func saveCachedRevenue() {
        userDefaults.set(todayRevenue, forKey: "adRevenue_today")
        userDefaults.set(lifetimeRevenue, forKey: "adRevenue_lifetime")
        userDefaults.set(todayImpressions, forKey: "adRevenue_todayImpressions")
        userDefaults.set(todayClicks, forKey: "adRevenue_todayClicks")
        userDefaults.set(Date(), forKey: "adRevenue_lastDate")
    }
    
    // MARK: - Reset
    
    func resetDailyStats() {
        todayRevenue = 0
        todayImpressions = 0
        todayClicks = 0
        recentEvents = []
        saveCachedRevenue()
    }
}

// MARK: - 💰 Revenue Dashboard View

struct AdRevenueDashboardView: View {
    @StateObject private var tracker = AdRevenueTracker.shared
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ad Revenue")
                        .font(.headline)
                    Text("Real-time earnings from AdMob")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
            }
            
            // Revenue Cards
            HStack(spacing: 12) {
                AdRevenueCard(
                    title: "Today",
                    amount: tracker.todayRevenue,
                    icon: "sun.max.fill",
                    color: .orange
                )
                
                AdRevenueCard(
                    title: "This Week",
                    amount: tracker.weekRevenue,
                    icon: "calendar",
                    color: .blue
                )
                
                AdRevenueCard(
                    title: "Lifetime",
                    amount: tracker.lifetimeRevenue,
                    icon: "star.fill",
                    color: .purple
                )
            }
            
            // Stats Row
            HStack(spacing: 20) {
                AdStatItem(value: "\(tracker.todayImpressions)", label: "Impressions")
                AdStatItem(value: "\(tracker.todayClicks)", label: "Clicks")
                AdStatItem(value: "$\(String(format: "%.2f", tracker.averageECPM))", label: "Avg eCPM")
            }
            .padding(.top, 8)
            
            // Recent Events
            if !tracker.recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(tracker.recentEvents.prefix(5)) { event in
                        HStack {
                            Circle()
                                .fill(colorForAdType(event.adType))
                                .frame(width: 8, height: 8)
                            
                            Text(event.adType.rawValue.capitalized)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text("+$\(String(format: "%.4f", event.estimatedRevenue))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(AppTheme.Colors.cardBackground)
        .cornerRadius(16)
        .task {
            await tracker.fetchRevenueData()
        }
    }
    
    private func colorForAdType(_ type: AdRevenueEvent.AdType) -> Color {
        switch type {
        case .rewarded: return .green
        case .interstitial: return .blue
        case .preroll: return .orange
        case .midroll: return .red
        case .postroll: return .purple
        case .banner: return .gray
        case .native: return .teal
        case .appOpen: return .yellow
        }
    }
}

// MARK: - Ad Revenue Card

private struct AdRevenueCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("$\(String(format: "%.2f", amount))")
                .font(.headline)
                .fontWeight(.bold)
                .contentTransition(.numericText())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Ad Stat Item

private struct AdStatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AdRevenueTracker_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            AdRevenueDashboardView()
                .padding()
        }
        .background(Color.black)
    }
}
#endif
