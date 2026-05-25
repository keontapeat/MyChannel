//
//  RealTimeRevenueTracker.swift
//  MyChannel
//
//  🔥💰 REAL-TIME REVENUE TRACKING - WATCH YOUR MONEY GROW LIVE! 💰🔥
//
//  Shows earnings as they happen:
//  ✅ Live earnings counter (updates every impression)
//  ✅ Today's earnings
//  ✅ This month's earnings
//  ✅ CPM tracking
//  ✅ Revenue breakdown by video
//  ✅ Real-time Firebase listener
//

import Foundation
import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - 🔥 REAL-TIME REVENUE TRACKER

@MainActor
final class RealTimeRevenueTracker: ObservableObject {
    static let shared = RealTimeRevenueTracker()
    
    // MARK: - Published State (Auto-updates UI!)
    @Published var lifetimeEarnings: Double = 0
    @Published var todayEarnings: Double = 0
    @Published var thisWeekEarnings: Double = 0
    @Published var thisMonthEarnings: Double = 0
    @Published var pendingPayout: Double = 0
    @Published var availableForWithdrawal: Double = 0
    
    @Published var todayImpressions: Int = 0
    @Published var lifetimeImpressions: Int = 0
    
    @Published var currentCPM: Double = 15.0 // Average CPM
    @Published var revenuePerMinute: Double = 0
    
    @Published var recentEarnings: [RevenueEvent] = []
    @Published var topEarningVideos: [VideoRevenue] = []
    @Published var hourlyEarnings: [HourlyEarning] = []
    
    @Published var isTracking: Bool = false
    @Published var lastUpdate: Date = Date()
    
    // 🔥 ANIMATION: For live counter effect
    @Published var showEarningAnimation: Bool = false
    @Published var lastEarningAmount: Double = 0
    
    private var earningsListener: ListenerRegistration?
    private var transactionsListener: ListenerRegistration?
    private var currentCreatorId: String?
    private var cancellables = Set<AnyCancellable>()
    
    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    #endif
    
    private init() {
        setupNotificationListeners()
    }
    
    // MARK: - 🔥 START TRACKING
    
    func startTracking(creatorId: String) {
        guard !isTracking || currentCreatorId != creatorId else { return }
        
        print("💰📊 [RevenueTracker] Starting real-time tracking for: \(creatorId)")
        
        stopTracking()
        currentCreatorId = creatorId
        isTracking = true
        
        // Load initial data
        Task {
            await loadInitialEarnings(creatorId: creatorId)
        }
        
        // Start Firebase listeners
        setupFirebaseListeners(creatorId: creatorId)
    }
    
    func stopTracking() {
        earningsListener?.remove()
        transactionsListener?.remove()
        earningsListener = nil
        transactionsListener = nil
        isTracking = false
        currentCreatorId = nil
        print("⏹️ [RevenueTracker] Stopped tracking")
    }
    
    // MARK: - 🔥 LOAD INITIAL DATA
    
    private func loadInitialEarnings(creatorId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("creator_earnings")
                .document(creatorId)
                .getDocument()
            
            guard let data = doc.data() else {
                print("📊 [RevenueTracker] No earnings data yet - fresh account!")
                return
            }
            
            await MainActor.run {
                self.lifetimeEarnings = data["totalEarnings"] as? Double ?? 0
                self.todayEarnings = data["todayEarnings"] as? Double ?? 0
                self.thisMonthEarnings = data["thisMonthEarnings"] as? Double ?? 0
                self.pendingPayout = data["pendingBalance"] as? Double ?? 0
                self.availableForWithdrawal = data["availableBalance"] as? Double ?? 0
                self.todayImpressions = data["impressionsToday"] as? Int ?? 0
                self.currentCPM = data["averageCPM"] as? Double ?? 15.0
                self.lastUpdate = Date()
            }
            
            print("✅ [RevenueTracker] Loaded initial earnings: $\(String(format: "%.2f", lifetimeEarnings))")
            
            // Load recent transactions
            await loadRecentTransactions(creatorId: creatorId)
            await loadTopEarningVideos(creatorId: creatorId)
            await loadHourlyEarnings(creatorId: creatorId)
            
        } catch {
            print("❌ [RevenueTracker] Failed to load earnings: \(error)")
        }
        #endif
    }
    
    private func loadRecentTransactions(creatorId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection("ad_revenue_transactions")
                .whereField("creatorId", isEqualTo: creatorId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            var events: [RevenueEvent] = []
            for doc in snapshot.documents {
                let data = doc.data()
                events.append(RevenueEvent(
                    id: doc.documentID,
                    videoId: data["videoId"] as? String ?? "",
                    amount: data["creatorRevenue"] as? Double ?? 0,
                    type: data["adType"] as? String ?? "ad",
                    network: data["network"] as? String ?? "",
                    timestamp: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                ))
            }
            
            await MainActor.run {
                self.recentEarnings = events
            }
            
        } catch {
            print("❌ [RevenueTracker] Failed to load transactions: \(error)")
        }
        #endif
    }
    
    private func loadTopEarningVideos(creatorId: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let snapshot = try await db.collection("videos")
                .whereField("creatorId", isEqualTo: creatorId)
                .order(by: "monetization.totalRevenue", descending: true)
                .limit(to: 10)
                .getDocuments()
            
            var videos: [VideoRevenue] = []
            for doc in snapshot.documents {
                let data = doc.data()
                let monetization = data["monetization"] as? [String: Any] ?? [:]
                videos.append(VideoRevenue(
                    id: doc.documentID,
                    title: data["title"] as? String ?? "",
                    thumbnailURL: data["thumbnailURL"] as? String ?? "",
                    revenue: monetization["totalRevenue"] as? Double ?? 0,
                    impressions: monetization["adImpressions"] as? Int ?? 0,
                    cpm: (monetization["totalRevenue"] as? Double ?? 0) / max(1, Double(monetization["adImpressions"] as? Int ?? 1)) * 1000
                ))
            }
            
            await MainActor.run {
                self.topEarningVideos = videos
            }
            
        } catch {
            print("❌ [RevenueTracker] Failed to load top videos: \(error)")
        }
        #endif
    }
    
    private func loadHourlyEarnings(creatorId: String) async {
        // Generate hourly breakdown for today
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        var hourly: [HourlyEarning] = []
        for hour in 0..<24 {
            let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourDate)!
            
            // In production, query Firebase for actual hourly data
            // For now, distribute today's earnings across hours
            let hoursElapsed = max(1, calendar.component(.hour, from: now) + 1)
            let avgHourly = todayEarnings / Double(hoursElapsed)
            
            hourly.append(HourlyEarning(
                hour: hour,
                date: hourDate,
                amount: hourDate <= now ? avgHourly : 0
            ))
        }
        
        await MainActor.run {
            self.hourlyEarnings = hourly
        }
    }
    
    // MARK: - 🔥 FIREBASE REAL-TIME LISTENERS
    
    private func setupFirebaseListeners(creatorId: String) {
        #if canImport(FirebaseFirestore)
        // 1. Listen to earnings document changes
        earningsListener = db.collection("creator_earnings")
            .document(creatorId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let data = snapshot?.data() else { return }
                
                Task { @MainActor in
                    let newTotal = data["totalEarnings"] as? Double ?? 0
                    let newToday = data["todayEarnings"] as? Double ?? 0
                    
                    // 🔥 ANIMATION: Trigger earning animation if amount increased
                    if newTotal > self.lifetimeEarnings {
                        let earned = newTotal - self.lifetimeEarnings
                        self.lastEarningAmount = earned
                        self.showEarningAnimation = true
                        
                        // Haptic feedback!
                        HapticManager.shared.notification(type: .success)
                        
                        // Hide animation after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.showEarningAnimation = false
                        }
                    }
                    
                    self.lifetimeEarnings = newTotal
                    self.todayEarnings = newToday
                    self.thisMonthEarnings = data["thisMonthEarnings"] as? Double ?? 0
                    self.pendingPayout = data["pendingBalance"] as? Double ?? 0
                    self.availableForWithdrawal = data["availableBalance"] as? Double ?? 0
                    self.todayImpressions = data["impressionsToday"] as? Int ?? 0
                    self.currentCPM = data["averageCPM"] as? Double ?? 15.0
                    self.lastUpdate = Date()
                    
                    // Calculate revenue per minute
                    let calendar = Calendar.current
                    let minutesSinceStart = calendar.dateComponents([.minute], from: calendar.startOfDay(for: Date()), to: Date()).minute ?? 1
                    self.revenuePerMinute = newToday / max(1, Double(minutesSinceStart))
                }
            }
        
        // 2. Listen to new transactions
        transactionsListener = db.collection("ad_revenue_transactions")
            .whereField("creatorId", isEqualTo: creatorId)
            .order(by: "createdAt", descending: true)
            .limit(to: 10)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    var events: [RevenueEvent] = []
                    for doc in snapshot?.documents ?? [] {
                        let data = doc.data()
                        events.append(RevenueEvent(
                            id: doc.documentID,
                            videoId: data["videoId"] as? String ?? "",
                            amount: data["creatorRevenue"] as? Double ?? 0,
                            type: data["adType"] as? String ?? "ad",
                            network: data["network"] as? String ?? "",
                            timestamp: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        ))
                    }
                    self.recentEarnings = events
                }
            }
        #endif
    }
    
    // MARK: - 🔥 NOTIFICATION LISTENERS
    
    private func setupNotificationListeners() {
        NotificationCenter.default.publisher(for: .adRevenueEarned)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let result = notification.object as? ServedAdResult else { return }
                
                // 🔥 INSTANT UPDATE (before Firebase sync)
                self.lastEarningAmount = result.creatorRevenue
                self.todayEarnings += result.creatorRevenue
                self.lifetimeEarnings += result.creatorRevenue
                self.pendingPayout += result.creatorRevenue
                self.todayImpressions += 1
                
                // Trigger animation
                self.showEarningAnimation = true
                HapticManager.shared.impact(style: .medium)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showEarningAnimation = false
                }
                
                // Add to recent earnings
                let event = RevenueEvent(
                    id: UUID().uuidString,
                    videoId: "",
                    amount: result.creatorRevenue,
                    type: "video_ad",
                    network: result.network,
                    timestamp: Date()
                )
                self.recentEarnings.insert(event, at: 0)
                if self.recentEarnings.count > 50 {
                    self.recentEarnings.removeLast()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 🔥 PROJECTED EARNINGS
    
    var projectedDailyEarnings: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let hoursElapsed = Double(calendar.dateComponents([.hour], from: startOfDay, to: now).hour ?? 1)
        guard hoursElapsed > 0 else { return todayEarnings }
        
        let hourlyRate = todayEarnings / hoursElapsed
        return hourlyRate * 24
    }
    
    var projectedMonthlyEarnings: Double {
        let calendar = Calendar.current
        let now = Date()
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDay = calendar.component(.day, from: now)
        guard currentDay > 0 else { return thisMonthEarnings }
        
        let dailyRate = thisMonthEarnings / Double(currentDay)
        return dailyRate * Double(daysInMonth)
    }
    
    var projectedYearlyEarnings: Double {
        return projectedMonthlyEarnings * 12
    }
    
    // MARK: - 🔥 FORMATTED STRINGS
    
    var formattedLifetimeEarnings: String {
        formatCurrency(lifetimeEarnings)
    }
    
    var formattedTodayEarnings: String {
        formatCurrency(todayEarnings)
    }
    
    var formattedPendingPayout: String {
        formatCurrency(pendingPayout)
    }
    
    var formattedCPM: String {
        "$\(String(format: "%.2f", currentCPM))"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1000000 {
            return "$\(String(format: "%.2fM", amount / 1000000))"
        } else if amount >= 1000 {
            return "$\(String(format: "%.2fK", amount / 1000))"
        } else if amount >= 1 {
            return "$\(String(format: "%.2f", amount))"
        } else {
            return "$\(String(format: "%.4f", amount))"
        }
    }
}

// MARK: - 🔥 MODELS

struct RevenueEvent: Identifiable {
    let id: String
    let videoId: String
    let amount: Double
    let type: String
    let network: String
    let timestamp: Date
    
    var formattedAmount: String {
        if amount >= 1 {
            return "$\(String(format: "%.2f", amount))"
        } else {
            return "$\(String(format: "%.4f", amount))"
        }
    }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}

struct VideoRevenue: Identifiable {
    let id: String
    let title: String
    let thumbnailURL: String
    let revenue: Double
    let impressions: Int
    let cpm: Double
    
    var formattedRevenue: String {
        "$\(String(format: "%.2f", revenue))"
    }
    
    var formattedCPM: String {
        "$\(String(format: "%.2f", cpm))"
    }
}

struct HourlyEarning: Identifiable {
    var id: Int { hour }
    let hour: Int
    let date: Date
    let amount: Double
    
    var formattedHour: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }
}

// MARK: - 🔥 SWIFTUI VIEW MODIFIER FOR LIVE EARNINGS

struct LiveEarningsModifier: ViewModifier {
    @ObservedObject var tracker: RealTimeRevenueTracker
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if tracker.showEarningAnimation {
                    EarningPopup(amount: tracker.lastEarningAmount)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: tracker.showEarningAnimation)
                }
            }
    }
}

struct EarningPopup: View {
    let amount: Double
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.green)
            
            Text("+$\(String(format: "%.4f", amount))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.15))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .padding(.trailing, 16)
        .padding(.top, 60)
    }
}

extension View {
    func withLiveEarnings() -> some View {
        modifier(LiveEarningsModifier(tracker: RealTimeRevenueTracker.shared))
    }
}






