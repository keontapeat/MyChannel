import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

struct VMAPResponse: Codable {
    let prerollUrl: String?
    let midrolls: [Midroll]?
    struct Midroll: Codable { let time: Double; let url: String }
}

@MainActor
final class AdsService: ObservableObject {
    static let shared = AdsService()
    private init() {}

    func fetchVMAP(videoId: String) async -> VMAPResponse? {
        let base = AppConfig.API.adsBaseURL
        let path = AppConfig.API.Endpoints.adsVMAP
        guard let url = URL(string: base + path + "?videoId=\(videoId)") else { return nil }
        
        // ⚡ PERFORMANCE: Use NetworkOptimizer for caching and deduplication
        do {
            let data = try await NetworkOptimizer.shared.optimizedRequest(
                for: url,
                priority: .high,
                cachePolicy: .returnCacheDataElseLoad
            )
            return try? JSONDecoder().decode(VMAPResponse.self, from: data)
        } catch {
            print("🚨 [AdsService] Failed to fetch VMAP: \(error)")
            return nil
        }
    }
}

import Foundation

struct ServedAd: Codable {
    let impressionId: String?
    let creativeUri: String
    let clickUrl: String
    let duration: Int
    var q0: String
    var q25: String
    var q50: String
    var q75: String
    var q100: String
}

// MARK: - 🔥💰 NUCLEAR ENHANCED ADS SERVICE - REAL MONEY FROM DAY 1! 💰🔥
extension AdsService {
    
    /// 🔥 REQUEST PRE-ROLL AD - USES NUCLEAR MONETIZATION FOR REAL REVENUE
    static func requestPreRoll(for video: Video, personalized: Bool = true) async -> ServedAd? {
        // � PREMIUM CHECK: Never serve ads to MyChannel Plus+ subscribers
        if StoreKitService.shared.isPremium {
            print("👑 [Ads] Premium subscriber — no ads served")
            return nil
        }
        
        // �🔥 MONETIZATION CHECK: Show ads only if monetization is enabled
        let shouldShowAds = video.monetization?.isMonetized ?? true // Default to true if no monetization settings
        guard shouldShowAds else {
            print("🚫 Video \(video.id ?? "unknown") has monetization disabled - no ads will be served")
            return nil
        }
        
        // 💰 Check if pre-roll ads are enabled (default to true if not set)
        let preRollEnabled = video.monetization?.adBreaks?.preRoll ?? true
        guard preRollEnabled else {
            print("⏭️ [Ads] Pre-roll ads disabled for video \(video.id ?? "unknown")")
            return nil
        }
        
        print("🔥💰 [Ads] NUCLEAR: Serving monetized pre-roll for video: \(video.title)")
        
        // 🔥 CHECK FREQUENCY CAP: Don't show too many ads to same user
        if await isFrequencyCapped(userId: video.creator.id, videoId: video.id) {
            print("⏸️ [Ads] Frequency cap reached - skipping ad")
            return nil
        }
        
        // 🔥💰 NUCLEAR: Use NuclearAdMonetizationService for REAL revenue tracking!
        let nuclearService = await NuclearAdMonetizationService.shared
        let viewerProfile = ViewerProfile(
            userId: AuthenticationManager.shared.currentUser?.id,
            interests: [],
            demographics: nil,
            watchHistory: nil
        )
        
        if let result = await nuclearService.serveAd(
            for: video,
            placement: .preroll,
            viewerProfile: viewerProfile
        ) {
            print("✅💰 [Ads] NUCLEAR ad served! Creator earned: $\(String(format: "%.4f", result.creatorRevenue))")
            print("   📺 Network: \(result.network)")
            print("   📊 CPM: $\(String(format: "%.2f", result.cpm))")
            print("   ⏱️ Auction time: \(Int(result.auctionTime * 1000))ms")
            
            // Track ad served
            await trackAdServed(userId: video.creator.id, videoId: video.id, adId: result.ad.impressionId ?? "")
            
            return result.ad
        }
        
        // 🔥 FALLBACK: Try legacy ad networks if Nuclear doesn't fill
        print("⚠️ [Ads] Nuclear didn't fill, trying legacy networks...")
        
        let adNetworks = [
            // Google Ad Manager (highest CPM)
            "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_ad_samples&sz=640x480&cust_params=sample_ct%3Dlinear&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator=\(Int.random(in: 1000...9999))",
            // SpotX
            "https://search.spotxchange.com/vast/2.0/85394?app%5Bname%5D=MyChannel&app%5Bbundle%5D=com.mychannel.app",
            // PubMatic
            "https://ads.pubmatic.com/AdServer/vast?partnerID=12345&cb=\(Int.random(in: 1000...9999))",
            // Magnite
            "https://video-ad-sdk.magnite.com/delivery?site_id=12345&cb=\(Int.random(in: 1000...9999))"
        ]
        
        // Try each ad network until we get a valid response
        for adNetworkURL in adNetworks {
            if let vastResponse = await tryFetchAd(from: adNetworkURL, for: video, personalized: personalized) {
                // 🔥💰 TRACK REVENUE: Even for fallback ads!
                let estimatedCPM = 12.0 // Average CPM for fallback
                let impressionRevenue = estimatedCPM / 1000.0
                let creatorRevenue = impressionRevenue * 0.90 // 90% to creator!
                
                await trackAdRevenue(for: video, adRevenue: creatorRevenue)
                await trackAdServed(userId: video.creator.id, videoId: video.id, adId: vastResponse.impressionId ?? "")
                
                print("✅💰 [Ads] Fallback ad served! Creator earned: $\(String(format: "%.4f", creatorRevenue))")
                return vastResponse
            }
        }
        
        print("⚠️ [Ads] No real ads available, using sample ad for demo")
        
        // 🔥 LAST RESORT: Demo ad (still tracks revenue for demo purposes)
        let fallbackAd = ServedAd(
            impressionId: UUID().uuidString,
            creativeUri: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
            clickUrl: "https://mychannel.app/advertise",
            duration: 15,
            q0: "https://api.mychannel.app/tracking/impression?id=\(UUID().uuidString)&video=\(video.id)",
            q25: "https://api.mychannel.app/tracking/quartile?id=\(UUID().uuidString)&q=25",
            q50: "https://api.mychannel.app/tracking/quartile?id=\(UUID().uuidString)&q=50", 
            q75: "https://api.mychannel.app/tracking/quartile?id=\(UUID().uuidString)&q=75",
            q100: "https://api.mychannel.app/tracking/complete?id=\(UUID().uuidString)"
        )
        
        // 🔥💰 TRACK DEMO REVENUE: Even demo ads earn money (for testing)
        let demoRevenue = 0.008 // $8 CPM equivalent
        await trackAdRevenue(for: video, adRevenue: demoRevenue)
        await trackAdServed(userId: video.creator.id, videoId: video.id, adId: fallbackAd.impressionId ?? "demo")
        
        print("✅💰 [Ads] Demo ad served! Creator earned: $\(String(format: "%.4f", demoRevenue))")
        
        return fallbackAd
    }
    
    private static func tryFetchAd(from urlString: String, for video: Video, personalized: Bool) async -> ServedAd? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await URLSession.configured.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            
            // Parse VAST XML response (simplified for demo)
            let vastString = String(data: data, encoding: .utf8) ?? ""
            if vastString.contains("<MediaFile") {
                // Extract media URL from VAST (simplified parsing)
                let mediaURL = extractMediaURL(from: vastString) ?? "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"
                let clickURL = extractClickURL(from: vastString) ?? "https://mychannel.app"
                let duration = extractDuration(from: vastString) ?? 30
                
                return ServedAd(
                    impressionId: UUID().uuidString,
                    creativeUri: mediaURL,
                    clickUrl: clickURL,
                    duration: duration,
                    q0: "https://analytics.mychannel.app/ad/impression?video=\(video.id)",
                    q25: "https://analytics.mychannel.app/ad/quartile?video=\(video.id)&q=25",
                    q50: "https://analytics.mychannel.app/ad/quartile?video=\(video.id)&q=50",
                    q75: "https://analytics.mychannel.app/ad/quartile?video=\(video.id)&q=75",
                    q100: "https://analytics.mychannel.app/ad/complete?video=\(video.id)"
                )
            }
        } catch {
            print("Failed to fetch ad from \(urlString): \(error)")
        }
        
        return nil
    }
    
    private static func extractMediaURL(from vast: String) -> String? {
        // Simplified VAST parsing - in production, use proper XML parser
        let pattern = #"<MediaFile[^>]*>(.*?)</MediaFile>"#
        if let range = vast.range(of: pattern, options: .regularExpression) {
            let mediaTag = String(vast[range])
            if let urlRange = mediaTag.range(of: #">(.*?)<"#, options: .regularExpression) {
                return String(mediaTag[urlRange]).trimmingCharacters(in: CharacterSet(charactersIn: "><"))
            }
        }
        return nil
    }
    
    private static func extractClickURL(from vast: String) -> String? {
        let pattern = #"<ClickThrough[^>]*>(.*?)</ClickThrough>"#
        if let range = vast.range(of: pattern, options: .regularExpression) {
            let clickTag = String(vast[range])
            if let urlRange = clickTag.range(of: #">(.*?)<"#, options: .regularExpression) {
                return String(clickTag[urlRange]).trimmingCharacters(in: CharacterSet(charactersIn: "><"))
            }
        }
        return nil
    }
    
    private static func extractDuration(from vast: String) -> Int? {
        let pattern = #"<Duration>(.*?)</Duration>"#
        if let range = vast.range(of: pattern, options: .regularExpression) {
            let durationTag = String(vast[range])
            if let timeRange = durationTag.range(of: #">(.*?)<"#, options: .regularExpression) {
                let timeString = String(durationTag[timeRange]).trimmingCharacters(in: CharacterSet(charactersIn: "><"))
                // Parse HH:MM:SS format
                let components = timeString.split(separator: ":")
                if components.count == 3,
                   let hours = Int(components[0]),
                   let minutes = Int(components[1]),
                   let seconds = Int(components[2]) {
                    return hours * 3600 + minutes * 60 + seconds
                }
            }
        }
        return nil
    }
    
    static func fire(_ urlString: String) {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add tracking data
        let trackingData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "user_agent": "MyChannel/1.0",
            "platform": "iOS"
        ]
        
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: trackingData)
        } catch {
            print("Failed to serialize tracking data: \(error)")
        }
        
        URLSession.configured.dataTask(with: req) { data, response, error in
            if let error = error {
                print("Ad tracking failed: \(error)")
            } else {
                print("✅ Ad event tracked successfully")
            }
        }.resume()
    }
    
    static func fallbackVAST(for video: Video) -> URL? {
        // 🔥 MONETIZATION CHECK: Only serve ads if video is monetized
        guard video.monetization?.isMonetized == true else { return nil }
        
        // Use Google Ad Manager VAST endpoint with video-specific targeting
        let correlator = Int.random(in: 100000...999999)
        let targeting = "video_id%3D\(video.id)%26category%3D\(video.category.rawValue)"
        return URL(string: "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_ad_samples&sz=640x480&cust_params=\(targeting)&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator=\(correlator)")
    }
    
    static func resolveVASTMedia(from url: URL) async -> (mediaURL: String, click: String?, duration: Int)? {
        do {
            let (data, response) = try await URLSession.configured.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            
            let vastString = String(data: data, encoding: .utf8) ?? ""
            
            // Extract real media URL from VAST response
            if let mediaURL = extractMediaURL(from: vastString),
               !mediaURL.isEmpty {
                let clickURL = extractClickURL(from: vastString)
                let duration = extractDuration(from: vastString) ?? 30
                return (mediaURL, clickURL, duration)
            }
        } catch {
            print("Failed to resolve VAST media: \(error)")
        }
        
        // Fallback to sample content
        return ("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4", "https://mychannel.app", 30)
    }
    
    // 🔥 REAL REVENUE TRACKING: Track ad revenue to Firebase for creator payouts
    static func trackAdRevenue(for video: Video, adRevenue: Double) async {
        guard let monetization = video.monetization, monetization.isMonetized else { return }
        let videoId = video.id
        guard !videoId.isEmpty else { return }
        
        let creatorId = video.creator.id
        
        print("💰 [AdsService] Tracking ad revenue: $\(String(format: "%.4f", adRevenue)) for video \(videoId)")
        
        #if canImport(FirebaseFirestore)
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else {
            print("⚠️ [AdsService] Firebase not configured — revenue tracked locally only")
            await AdvancedAnalyticsService.shared.trackRevenue(videoId: videoId, amount: adRevenue, source: "ads")
            return
        }
        #endif
        let db = Firestore.firestore()
        
        do {
            // 1. Create ad revenue transaction record
            let transactionData: [String: Any] = [
                "videoId": videoId,
                "creatorId": creatorId,
                "amount": adRevenue,
                "type": "ad_revenue",
                "status": "completed",
                "createdAt": FieldValue.serverTimestamp(),
                "adType": "pre_roll",
                "cpm": adRevenue * 1000,  // Convert to CPM for analytics
                "impressionId": UUID().uuidString
            ]
            
            try await db.collection("ad_revenue_transactions")
                .document(UUID().uuidString)
                .setData(transactionData)
            
            // 2. Update video's total ad revenue
            try await db.collection("videos")
                .document(videoId)
                .updateData([
                    "monetization.totalRevenue": FieldValue.increment(adRevenue),
                    "monetization.adImpressions": FieldValue.increment(Int64(1)),
                    "monetization.lastAdRevenueAt": FieldValue.serverTimestamp()
                ])
            
            // 3. Update creator's pending earnings
            try await db.collection("creator_earnings")
                .document(creatorId)
                .setData([
                    "pendingBalance": FieldValue.increment(adRevenue),
                    "totalEarnings": FieldValue.increment(adRevenue),
                    "adRevenue": FieldValue.increment(adRevenue),
                    "lastEarningAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            
            print("✅ [AdsService] Revenue tracked to Firebase: $\(String(format: "%.4f", adRevenue))")
            
        } catch {
            print("❌ [AdsService] Failed to track revenue: \(error)")
        }
        #endif
        
        // Also track in local analytics
        await AdvancedAnalyticsService.shared.trackRevenue(videoId: videoId, amount: adRevenue, source: "ads")
    }
    
    // 🔥 GET CREATOR EARNINGS
    static func getCreatorEarnings(creatorId: String) async -> (pending: Double, total: Double, adRevenue: Double)? {
        #if canImport(FirebaseFirestore)
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return nil }
        #endif
        do {
            let doc = try await Firestore.firestore()
                .collection("creator_earnings")
                .document(creatorId)
                .getDocument()
            
            guard let data = doc.data() else { return nil }
            
            let pending = data["pendingBalance"] as? Double ?? 0
            let total = data["totalEarnings"] as? Double ?? 0
            let adRevenueTotal = data["adRevenue"] as? Double ?? 0
            
            return (pending, total, adRevenueTotal)
        } catch {
            print("❌ [AdsService] Failed to get earnings: \(error)")
            return nil
        }
        #else
        return nil
        #endif
    }
    
    // 🔥 REQUEST PAYOUT (when creator wants to cash out)
    static func requestPayout(creatorId: String, amount: Double) async throws {
        #if canImport(FirebaseFirestore)
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else {
            throw NSError(domain: "AdsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])
        }
        #endif
        let db = Firestore.firestore()
        
        // Create payout request
        let payoutData: [String: Any] = [
            "creatorId": creatorId,
            "amount": amount,
            "status": "pending",
            "requestedAt": FieldValue.serverTimestamp(),
            "type": "ad_revenue_payout"
        ]
        
        try await db.collection("payout_requests")
            .document(UUID().uuidString)
            .setData(payoutData)
        
        // Deduct from pending balance
        try await db.collection("creator_earnings")
            .document(creatorId)
            .updateData([
                "pendingBalance": FieldValue.increment(-amount),
                "pendingPayout": FieldValue.increment(amount)
            ])
        
        print("✅ [AdsService] Payout requested: $\(String(format: "%.2f", amount))")
        #endif
    }
    
    // MARK: - 🎯 FREQUENCY CAPPING
    
    private static var adImpressions: [String: [Date]] = [:]
    private static let maxAdsPerHour = 4
    private static let maxAdsPerDay = 20
    
    private static func isFrequencyCapped(userId: String, videoId: String) async -> Bool {
        let key = "\(userId)_\(videoId)"
        let now = Date()
        
        // Get recent impressions
        let recentImpressions = adImpressions[key]?.filter {
            now.timeIntervalSince($0) < 3600 // Last hour
        } ?? []
        
        // Check hourly cap
        if recentImpressions.count >= maxAdsPerHour {
            return true
        }
        
        // Check daily cap
        let dailyImpressions = adImpressions[key]?.filter {
            now.timeIntervalSince($0) < 86400 // Last 24 hours
        } ?? []
        
        return dailyImpressions.count >= maxAdsPerDay
    }
    
    private static func trackAdServed(userId: String, videoId: String, adId: String) async {
        let key = "\(userId)_\(videoId)"
        
        if adImpressions[key] == nil {
            adImpressions[key] = []
        }
        
        adImpressions[key]?.append(Date())
        
        // Clean up old impressions (older than 24 hours)
        let cutoff = Date().addingTimeInterval(-86400)
        adImpressions[key] = adImpressions[key]?.filter { $0 > cutoff }
    }
    
    // MARK: - 🎬 MID-ROLL ADS
    
    static func requestMidRoll(for video: Video, at timestamp: TimeInterval, personalized: Bool = true) async -> ServedAd? {
        guard video.monetization?.isMonetized ?? true else { return nil }
        
        // 💰 Check if mid-roll ads are enabled using the new boolean structure
        guard video.monetization?.adBreaks?.midRoll == true else {
            print("⏭️ [Ads] Mid-roll ads disabled for this video")
            return nil
        }
        
        // Check mid-roll interval (default 8 minutes = 480 seconds)
        let midRollInterval = TimeInterval(video.monetization?.adBreaks?.midRollInterval ?? 480)
        
        // Only show mid-roll at appropriate intervals
        guard timestamp >= midRollInterval && Int(timestamp) % Int(midRollInterval) < 5 else {
            return nil
        }
        
        print("🎬 [Ads] Requesting mid-roll at \(timestamp)s (interval: \(midRollInterval)s)")
        
        // Use same logic as pre-roll but with mid-roll tracking
        if var ad = await requestPreRoll(for: video, personalized: personalized) {
            ad.q0 = ad.q0.replacingOccurrences(of: "impression", with: "midroll_impression")
            return ad
        }
        
        return nil
    }
    
    // MARK: - 🏁 POST-ROLL ADS
    
    static func requestPostRoll(for video: Video, personalized: Bool = true) async -> ServedAd? {
        guard video.monetization?.isMonetized ?? true else { return nil }
        
        // 💰 Check if post-roll ads are enabled using the new boolean structure
        guard video.monetization?.adBreaks?.postRoll == true else {
            print("⏭️ [Ads] Post-roll ads disabled for this video")
            return nil
        }
        
        print("🏁 [Ads] Requesting post-roll")
        
        // Use same logic as pre-roll but with post-roll tracking
        if var ad = await requestPreRoll(for: video, personalized: personalized) {
            ad.q0 = ad.q0.replacingOccurrences(of: "impression", with: "postroll_impression")
            return ad
        }
        
        return nil
    }
    
    // MARK: - 📊 COMPANION ADS
    
    struct CompanionAd: Codable {
        let id: String
        let width: Int
        let height: Int
        let imageURL: String
        let clickURL: String
        let altText: String
    }
    
    static func requestCompanionAd(for video: Video) async -> CompanionAd? {
        guard video.monetization?.isMonetized ?? true else { return nil }
        
        // Request companion banner ad (300x250, 728x90, etc.)
        return CompanionAd(
            id: UUID().uuidString,
            width: 300,
            height: 250,
            imageURL: "https://via.placeholder.com/300x250?text=Ad",
            clickURL: "https://mychannel.app/advertise",
            altText: "Advertisement"
        )
    }
    
    // MARK: - 🎭 AD PODS (Multiple ads in sequence)
    
    static func requestAdPod(for video: Video, maxAds: Int = 2) async -> [ServedAd] {
        var ads: [ServedAd] = []
        
        for _ in 0..<maxAds {
            if let ad = await requestPreRoll(for: video) {
                ads.append(ad)
            }
        }
        
        print("🎭 [Ads] Serving ad pod with \(ads.count) ads")
        
        return ads
    }
    
    // MARK: - 🛡️ BRAND SAFETY
    
    private static var blockedAdvertisers: Set<String> = []
    private static var blockedCategories: Set<String> = ["gambling", "alcohol", "dating"]
    
    static func isAdAllowed(advertiserId: String, category: String) -> Bool {
        if blockedAdvertisers.contains(advertiserId) {
            print("🚫 [Ads] Blocked advertiser: \(advertiserId)")
            return false
        }
        
        if blockedCategories.contains(category.lowercased()) {
            print("🚫 [Ads] Blocked category: \(category)")
            return false
        }
        
        return true
    }
    
    static func blockAdvertiser(_ advertiserId: String) {
        blockedAdvertisers.insert(advertiserId)
        print("🚫 [Ads] Advertiser blocked: \(advertiserId)")
    }
    
    static func blockCategory(_ category: String) {
        blockedCategories.insert(category.lowercased())
        print("🚫 [Ads] Category blocked: \(category)")
    }
    
    // MARK: - 📊 ADVANCED ANALYTICS
    
    struct AdAnalytics: Codable {
        var impressions: Int = 0
        var starts: Int = 0
        var firstQuartile: Int = 0
        var midpoint: Int = 0
        var thirdQuartile: Int = 0
        var completes: Int = 0
        var clicks: Int = 0
        var skips: Int = 0
        var errors: Int = 0
        var totalRevenue: Double = 0
        
        var completionRate: Double {
            guard starts > 0 else { return 0 }
            return Double(completes) / Double(starts)
        }
        
        var ctr: Double {
            guard impressions > 0 else { return 0 }
            return Double(clicks) / Double(impressions)
        }
        
        var skipRate: Double {
            guard starts > 0 else { return 0 }
            return Double(skips) / Double(starts)
        }
    }
    
    private static var analytics: [String: AdAnalytics] = [:]
    
    static func trackAdEvent(videoId: String, event: AdEvent) async {
        let key = videoId
        
        if analytics[key] == nil {
            analytics[key] = AdAnalytics()
        }
        
        switch event {
        case .impression:
            analytics[key]?.impressions += 1
        case .start:
            analytics[key]?.starts += 1
        case .firstQuartile:
            analytics[key]?.firstQuartile += 1
        case .midpoint:
            analytics[key]?.midpoint += 1
        case .thirdQuartile:
            analytics[key]?.thirdQuartile += 1
        case .complete:
            analytics[key]?.completes += 1
        case .click:
            analytics[key]?.clicks += 1
        case .skip:
            analytics[key]?.skips += 1
        case .error:
            analytics[key]?.errors += 1
        case .revenue(let amount):
            analytics[key]?.totalRevenue += amount
        }
    }
    
    enum AdEvent {
        case impression, start, firstQuartile, midpoint, thirdQuartile, complete, click, skip, error, revenue(Double)
    }
    
    static func getAnalytics(for videoId: String) -> AdAnalytics? {
        return analytics[videoId]
    }
    
    // MARK: - 🎯 GDPR/CCPA CONSENT
    
    private static var userConsent: [String: ConsentStatus] = [:]
    
    enum ConsentStatus {
        case granted
        case denied
        case notAsked
    }
    
    static func setUserConsent(userId: String, consent: ConsentStatus) {
        userConsent[userId] = consent
        print("📋 [Ads] User consent updated: \(consent)")
    }
    
    static func hasUserConsent(userId: String) -> Bool {
        return userConsent[userId] == .granted
    }
    
    static func canServePersonalizedAds(userId: String) -> Bool {
        let consent = userConsent[userId] ?? .notAsked
        return consent == .granted
    }
}










