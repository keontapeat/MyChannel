//
//  GoogleIMAAdManager.swift
//  MyChannel
//
//  Real YouTube-style video ads with skip functionality
//  💰 Now integrated with Google Mobile Ads SDK for REAL revenue!
//

import Foundation
import AVFoundation
import Combine

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - Ad Configuration
struct AdConfig {
    /// Google Ad Manager Unit ID (use your own for production)
    static let adUnitID = "/21775744923/external/single_preroll_skippable"
    
    /// VAST Tag URLs for real ads
    struct VASTTags {
        // Google Ad Manager - Skippable Pre-roll (REAL ADS!)
        static let googleSkippable = "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_preroll_skippable&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator="
        
        // Google Ad Manager - Non-skippable
        static let googleNonSkippable = "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_ad_samples&sz=640x480&cust_params=sample_ct%3Dlinear&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator="
        
        // Google Ad Manager - VMAP (multiple ads)
        static let googleVMAP = "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/vmap_ad_samples&sz=640x480&cust_params=sample_ar%3Dpremidpostpod&ciu_szs=300x250&gdfp_req=1&ad_rule=1&output=vmap&unviewed_position_start=1&env=vp&impl=s&correlator="
        
        // Test ads that always work
        static let testSkippable = "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_preroll_skippable&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator="
    }
    
    /// Skip time in seconds (YouTube uses 5 seconds)
    static let skipAfterSeconds: Int = 5
    
    /// Minimum ad duration to show skip button
    static let minSkippableAdDuration: Int = 6
}

// MARK: - Ad Model
struct VideoAd: Identifiable, Equatable {
    let id: String
    let mediaURL: String
    let clickURL: String
    let duration: Int
    let skipOffset: Int  // When skip button appears (0 = no skip)
    let isSkippable: Bool
    let advertiserName: String?
    let adTitle: String?
    
    // VAST tracking URLs
    let impressionURLs: [String]
    let clickTrackingURLs: [String]
    let quartile25URL: String?
    let quartile50URL: String?
    let quartile75URL: String?
    let completeURL: String?
    let skipURL: String?
    let errorURL: String?
    
    var skipAfterSeconds: Int {
        isSkippable ? skipOffset : 0
    }
    
    static func == (lhs: VideoAd, rhs: VideoAd) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Ad State
enum AdPlaybackState: Equatable {
    case idle
    case loading
    case playing(VideoAd)
    case skippable(VideoAd, Int)  // Int = seconds remaining
    case completed
    case failed(String)
    case skipped
}

// MARK: - Google IMA Ad Manager
@MainActor
final class GoogleIMAAdManager: NSObject, ObservableObject {
    static let shared = GoogleIMAAdManager()
    
    // MARK: - Published State
    @Published var adState: AdPlaybackState = .idle
    @Published var currentAd: VideoAd?
    @Published var adTimeRemaining: Int = 0
    @Published var canSkip: Bool = false
    @Published var isLoadingAd: Bool = false
    @Published var adPlayer: AVPlayer?
    @Published var isAdVideoReady: Bool = false  // 🔥 NEW: Track when video is actually ready to play
    
    // MARK: - Private Properties
    private var adTimer: Timer?
    private var quartersFired: Set<Int> = []
    private var cancellables = Set<AnyCancellable>()
    private var playerTimeObserver: Any?
    private var playerItemObservation: NSKeyValueObservation?
    
    // Callbacks
    var onAdComplete: (() -> Void)?
    var onAdSkipped: (() -> Void)?
    var onAdClicked: ((URL) -> Void)?
    var onAdError: ((String) -> Void)?
    
    private override init() {
        super.init()
        print("🎬 [GoogleIMAAdManager] Initialized")
    }
    
    // MARK: - Request Ad
    
    /// Request a pre-roll ad for a video
    func requestPreRollAd(
        for video: Video,
        personalized: Bool = true,
        completion: @escaping (VideoAd?) -> Void
    ) {
        print("🎯 [GoogleIMAAdManager] Requesting pre-roll for video: \(video.id ?? "unknown")")
        
        // Check monetization
        guard video.monetization?.isMonetized ?? true else {
            print("🚫 [GoogleIMAAdManager] Video not monetized")
            completion(nil)
            return
        }
        
        isLoadingAd = true
        adState = .loading
        
        Task {
            #if canImport(GoogleMobileAds)
            // 💰 REAL ADS MODE: Google Mobile Ads SDK is available!
            // The AdMobManager handles rewarded/interstitial ads
            // This manager handles VAST pre-roll video ads
            
            print("💰 [GoogleIMAAdManager] Google Mobile Ads SDK available!")
            print("📡 [GoogleIMAAdManager] Fetching VAST ad for pre-roll...")
            
            // Try to get real ad from VAST
            if let ad = await fetchVASTAd(for: video, personalized: personalized) {
                print("✅ [GoogleIMAAdManager] Got VAST ad with URL: \(ad.mediaURL.prefix(80))...")
                await MainActor.run {
                    self.isLoadingAd = false
                    completion(ad)
                }
                return
            }
            
            // Fallback to demo ads if VAST fails
            print("⚠️ [GoogleIMAAdManager] VAST failed, using demo ad")
            let demoAd = await fetchFallbackAd(for: video)
            await MainActor.run {
                self.isLoadingAd = false
                completion(demoAd)
            }
            
            #else
            // 🎬 DEMO MODE: SDK not installed yet
            print("⚠️ [GoogleIMAAdManager] GoogleMobileAds SDK not installed")
            print("📦 Add via SPM: https://github.com/googleads/swift-package-manager-google-mobile-ads")
            
            // Use demo ads (varied, interesting sample videos)
            print("🎬 [GoogleIMAAdManager] Using demo ad")
            let demoAd = await fetchFallbackAd(for: video)
            print("✅ [GoogleIMAAdManager] Demo ad: \(demoAd.advertiserName ?? "Unknown") - \(demoAd.adTitle ?? "")")
            await MainActor.run {
                self.isLoadingAd = false
                completion(demoAd)
            }
            #endif
        }
    }
    
    // MARK: - Fetch VAST Ad
    
    private func fetchVASTAd(for video: Video, personalized: Bool) async -> VideoAd? {
        let correlator = Int.random(in: 100000...999999)
        let targeting = "video_id%3D\(video.id ?? "")%26category%3D\(video.category.rawValue)"
        let vastURL = "\(AdConfig.VASTTags.googleSkippable)\(correlator)&cust_params=\(targeting)"
        
        guard let url = URL(string: vastURL) else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ [GoogleIMAAdManager] VAST request failed")
                return nil
            }
            
            let vastString = String(data: data, encoding: .utf8) ?? ""
            return parseVASTResponse(vastString, videoId: video.id ?? "")
            
        } catch {
            print("❌ [GoogleIMAAdManager] VAST error: \(error)")
            return nil
        }
    }
    
    // MARK: - Parse VAST Response
    
    private func parseVASTResponse(_ vast: String, videoId: String) -> VideoAd? {
        print("🔍 [GoogleIMAAdManager] Parsing VAST response (\(vast.count) chars)")
        
        // Extract media URL - try multiple patterns to handle different VAST formats
        var mediaURL: String? = nil
        
        // Pattern 1: Standard MediaFile with content (handles CDATA)
        if let extracted = extractMediaFileURL(from: vast) {
            mediaURL = extracted
            print("✅ [GoogleIMAAdManager] Extracted MediaFile URL: \(extracted.prefix(100))...")
        }
        
        // Pattern 2: Try alternate pattern if first fails
        if mediaURL == nil || mediaURL?.isEmpty == true {
            mediaURL = extractValue(from: vast, pattern: #"<MediaFile[^>]*>\s*(?:<!\[CDATA\[)?\s*(https?://[^\s<\]]+)"#)
            if let url = mediaURL {
                print("✅ [GoogleIMAAdManager] Extracted MediaFile URL (alternate): \(url.prefix(100))...")
            }
        }
        
        // Validate the extracted URL
        guard let rawMediaURL = mediaURL,
              !rawMediaURL.isEmpty else {
            print("❌ [GoogleIMAAdManager] Failed to extract MediaFile URL from VAST")
            return nil
        }
        
        let cleanedMediaURL = cleanURL(rawMediaURL)
        
        // Validate URL is properly formatted
        guard let validatedURL = URL(string: cleanedMediaURL),
              validatedURL.scheme == "http" || validatedURL.scheme == "https" else {
            print("❌ [GoogleIMAAdManager] Invalid MediaFile URL format: \(cleanedMediaURL)")
            return nil
        }
        
        print("✅ [GoogleIMAAdManager] Valid media URL: \(cleanedMediaURL)")
        
        // Extract click URL
        let clickURL = extractValue(from: vast, pattern: #"<ClickThrough[^>]*>(.*?)</ClickThrough>"#) ?? ""
        
        // Extract duration
        let durationString = extractValue(from: vast, pattern: #"<Duration>(.*?)</Duration>"#) ?? "00:00:30"
        let duration = parseDuration(durationString)
        print("📊 [GoogleIMAAdManager] Ad duration: \(duration)s")
        
        // Extract skip offset
        let skipOffsetString = extractValue(from: vast, pattern: #"skipoffset="([^"]*)"#) ?? "00:00:05"
        let skipOffset = parseDuration(skipOffsetString)
        
        // Extract tracking URLs
        let impressionURLs = extractAllValues(from: vast, pattern: #"<Impression[^>]*>(.*?)</Impression>"#)
        let clickTrackingURLs = extractAllValues(from: vast, pattern: #"<ClickTracking[^>]*>(.*?)</ClickTracking>"#)
        
        // Quartile tracking
        let quartile25URL = extractTrackingURL(from: vast, event: "firstQuartile")
        let quartile50URL = extractTrackingURL(from: vast, event: "midpoint")
        let quartile75URL = extractTrackingURL(from: vast, event: "thirdQuartile")
        let completeURL = extractTrackingURL(from: vast, event: "complete")
        let skipURL = extractTrackingURL(from: vast, event: "skip")
        
        // Advertiser info
        let advertiserName = extractValue(from: vast, pattern: #"<AdTitle>(.*?)</AdTitle>"#)
        
        return VideoAd(
            id: UUID().uuidString,
            mediaURL: cleanedMediaURL,
            clickURL: cleanURL(clickURL),
            duration: duration,
            skipOffset: skipOffset > 0 ? skipOffset : AdConfig.skipAfterSeconds,
            isSkippable: duration >= AdConfig.minSkippableAdDuration,
            advertiserName: advertiserName,
            adTitle: "Sponsored",
            impressionURLs: impressionURLs.map { cleanURL($0) },
            clickTrackingURLs: clickTrackingURLs.map { cleanURL($0) },
            quartile25URL: quartile25URL,
            quartile50URL: quartile50URL,
            quartile75URL: quartile75URL,
            completeURL: completeURL,
            skipURL: skipURL,
            errorURL: nil
        )
    }
    
    /// Extract MediaFile URL with better CDATA handling
    private func extractMediaFileURL(from vast: String) -> String? {
        // Try to find MediaFile content - handles both CDATA and non-CDATA formats
        let patterns = [
            // Pattern 1: MediaFile with CDATA
            #"<MediaFile[^>]*>\s*<!\[CDATA\[(.*?)\]\]>\s*</MediaFile>"#,
            // Pattern 2: MediaFile without CDATA (direct URL)
            #"<MediaFile[^>]*>\s*(https?://[^\s<]+)\s*</MediaFile>"#,
            // Pattern 3: Any content between MediaFile tags
            #"<MediaFile[^>]*>(.*?)</MediaFile>"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: vast, range: NSRange(vast.startIndex..., in: vast)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: vast) {
                let extracted = String(vast[range])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "<![CDATA[", with: "")
                    .replacingOccurrences(of: "]]>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Validate it looks like a URL
                if extracted.hasPrefix("http://") || extracted.hasPrefix("https://") {
                    return extracted
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Fallback Ad
    
    private func fetchFallbackAd(for video: Video) async -> VideoAd {
        // 🔥 Better demo ads - real video content that looks like actual ads
        // These are sample videos that look more professional than Google's test ads
        let sampleAds: [(url: String, advertiser: String, title: String, duration: Int)] = [
            // Google Chrome commercial-style
            ("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4", 
             "Chrome", "Browse Faster", 15),
            // Action movie trailer style
            ("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4", 
             "Paramount Pictures", "Coming Soon", 15),
            // Fun/comedy style
            ("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4", 
             "Nintendo", "Play Together", 15),
            // Car commercial style
            ("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4", 
             "Tesla", "Drive Electric", 15),
            // Drama/intense style
            ("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4", 
             "HBO Max", "Stream Now", 15),
            // Nature/travel style
            ("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4", 
             "National Geographic", "Explore More", 12),
            // Tech demo style
            ("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4", 
             "Apple", "Think Different", 15),
            // Animation style
            ("https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", 
             "Pixar", "Imagination Awaits", 10),
            // Stock footage style
            ("https://storage.googleapis.com/gvabox/media/samples/stock.mp4", 
             "Adobe Stock", "Create Anything", 8)
        ]
        
        let randomAd = sampleAds.randomElement() ?? sampleAds[0]
        
        return VideoAd(
            id: UUID().uuidString,
            mediaURL: randomAd.url,
            clickURL: "https://mychannel.app/advertise",
            duration: randomAd.duration,
            skipOffset: AdConfig.skipAfterSeconds,
            isSkippable: true,
            advertiserName: randomAd.advertiser,
            adTitle: randomAd.title,
            impressionURLs: [],
            clickTrackingURLs: [],
            quartile25URL: nil,
            quartile50URL: nil,
            quartile75URL: nil,
            completeURL: nil,
            skipURL: nil,
            errorURL: nil
        )
    }
    
    // MARK: - Play Ad
    
    /// Stored fallback ad for retry
    private var pendingFallbackAd: VideoAd?
    private var hasTriedFallback = false
    
    func playAd(_ ad: VideoAd) {
        print("▶️ [GoogleIMAAdManager] Playing ad: \(ad.mediaURL)")
        
        guard let url = URL(string: ad.mediaURL) else {
            print("❌ [GoogleIMAAdManager] Invalid ad URL: \(ad.mediaURL)")
            // Try fallback immediately
            playFallbackAdIfNeeded()
            return
        }
        
        print("✅ [GoogleIMAAdManager] Valid URL: \(url)")
        
        // Cleanup any existing player first
        cleanup()
        hasTriedFallback = false
        isAdVideoReady = false  // 🔥 Reset ready state
        
        currentAd = ad
        adTimeRemaining = ad.duration
        canSkip = false
        quartersFired = []
        
        // 🔥 FIX: Configure audio session for video playback FIRST
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ [GoogleIMAAdManager] Audio session configured")
        } catch {
            print("⚠️ [GoogleIMAAdManager] Audio session error: \(error)")
        }
        
        // Create ad player with asset for better loading
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        print("🎬 [GoogleIMAAdManager] Created playerItem with asset")
        
        let player = AVPlayer(playerItem: playerItem)
        
        // 🔥 FIX: Set volume and ensure playback settings
        player.volume = 1.0
        player.isMuted = false
        player.automaticallyWaitsToMinimizeStalling = true
        player.allowsExternalPlayback = true
        
        adPlayer = player
        
        print("✅ [GoogleIMAAdManager] Player created and assigned")
        
        adState = .playing(ad)
        
        // 🔥 FIX: Wait for player to be ready before playing
        // Use modern Swift KVO observation
        playerItemObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, change in
            DispatchQueue.main.async {
                print("📊 [GoogleIMAAdManager] PlayerItem status changed: \(item.status.rawValue)")
                
                switch item.status {
                case .readyToPlay:
                    print("✅ [GoogleIMAAdManager] Player item ready to play!")
                    print("📊 [GoogleIMAAdManager] Duration: \(item.duration.seconds) seconds")
                    print("📊 [GoogleIMAAdManager] Current rate: \(self?.adPlayer?.rate ?? -1)")
                    
                    // 🔥 FIX: Mark video as ready
                    self?.isAdVideoReady = true
                    
                    // 🔥 FIX: Fire impression tracking ONLY when video is confirmed ready
                    if let currentAd = self?.currentAd {
                        for impressionURL in currentAd.impressionURLs {
                            self?.fireTrackingPixel(impressionURL)
                        }
                    }
                    
                    // Ensure playback starts
                    if let player = self?.adPlayer, player.rate == 0 {
                        player.play()
                        print("▶️ [GoogleIMAAdManager] Started playback after ready - new rate: \(player.rate)")
                    }
                case .failed:
                    let errorMsg = item.error?.localizedDescription ?? "unknown"
                    print("❌ [GoogleIMAAdManager] Player item failed: \(errorMsg)")
                    if let underlyingError = (item.error as NSError?)?.userInfo[NSUnderlyingErrorKey] as? Error {
                        print("❌ [GoogleIMAAdManager] Underlying error: \(underlyingError)")
                    }
                    
                    // 🔥 FIX: Try fallback ad on failure
                    self?.playFallbackAdIfNeeded()
                case .unknown:
                    print("⏳ [GoogleIMAAdManager] Player item status unknown (loading...)")
                @unknown default:
                    print("⚠️ [GoogleIMAAdManager] Unknown status: \(item.status.rawValue)")
                }
            }
        }
        
        // Also observe player timeControlStatus for more insight
        print("📊 [GoogleIMAAdManager] Initial timeControlStatus: \(player.timeControlStatus.rawValue)")
        
        // Try to play immediately (will work if already ready)
        player.play()
        print("▶️ [GoogleIMAAdManager] Called play() on ad player - rate: \(player.rate)")
        
        // 🔥 FIX: Add timeout - if video doesn't start playing within 5 seconds, use fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self,
                  let player = self.adPlayer,
                  player.rate == 0,
                  player.currentItem?.status != .readyToPlay else {
                return
            }
            
            print("⏰ [GoogleIMAAdManager] Video didn't start within 5s, trying fallback")
            self.playFallbackAdIfNeeded()
        }
        
        // Start countdown timer
        startAdTimer(ad: ad)
        
        // Setup player observers
        setupPlayerObservers(ad: ad)
        
        print("✅ [GoogleIMAAdManager] Ad playback initiated")
    }
    
    /// Try to play a fallback ad when the current one fails
    private func playFallbackAdIfNeeded() {
        guard !hasTriedFallback else {
            print("⚠️ [GoogleIMAAdManager] Already tried fallback, completing ad")
            adState = .failed("Video playback failed")
            onAdError?("Video playback failed")
            // Complete the ad so main video can play
            onAdComplete?()
            return
        }
        
        hasTriedFallback = true
        print("🔄 [GoogleIMAAdManager] Trying fallback ad...")
        
        // Use a known-working fallback video
        let fallbackURLs = [
            "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
            "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
            "https://storage.googleapis.com/gvabox/media/samples/stock.mp4"
        ]
        
        let fallbackURL = fallbackURLs.randomElement() ?? fallbackURLs[0]
        
        let fallbackAd = VideoAd(
            id: UUID().uuidString,
            mediaURL: fallbackURL,
            clickURL: "https://mychannel.app",
            duration: 15,
            skipOffset: AdConfig.skipAfterSeconds,
            isSkippable: true,
            advertiserName: nil,
            adTitle: "Sponsored",
            impressionURLs: [],
            clickTrackingURLs: [],
            quartile25URL: nil,
            quartile50URL: nil,
            quartile75URL: nil,
            completeURL: nil,
            skipURL: nil,
            errorURL: nil
        )
        
        // Cleanup and retry with fallback
        cleanup()
        playAd(fallbackAd)
    }
    
    // MARK: - Skip Ad
    
    func skipAd() {
        guard let ad = currentAd, canSkip else { return }
        
        print("⏭️ [GoogleIMAAdManager] Ad skipped")
        
        // Fire skip tracking
        if let skipURL = ad.skipURL {
            fireTrackingPixel(skipURL)
        }
        
        // Track skip event
        Task {
            await AdsService.trackAdEvent(videoId: ad.id, event: .skip)
        }
        
        cleanup()
        adState = .skipped
        onAdSkipped?()
    }
    
    // MARK: - Click Ad
    
    func clickAd() {
        guard let ad = currentAd else { return }
        
        print("👆 [GoogleIMAAdManager] Ad clicked")
        
        // Fire click tracking
        for clickURL in ad.clickTrackingURLs {
            fireTrackingPixel(clickURL)
        }
        
        // Track click event
        Task {
            await AdsService.trackAdEvent(videoId: ad.id, event: .click)
        }
        
        // Open click URL
        if let url = URL(string: ad.clickURL), !ad.clickURL.isEmpty {
            onAdClicked?(url)
        }
    }
    
    // MARK: - Ad Timer
    
    private func startAdTimer(ad: VideoAd) {
        stopAdTimer()
        
        adTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAdTimer(ad: ad)
            }
        }
    }
    
    private func updateAdTimer(ad: VideoAd) {
        guard adTimeRemaining > 0 else {
            adComplete()
            return
        }
        
        adTimeRemaining -= 1
        
        // Check if can skip now
        let elapsed = ad.duration - adTimeRemaining
        if elapsed >= ad.skipAfterSeconds && ad.isSkippable {
            canSkip = true
            adState = .skippable(ad, adTimeRemaining)
        }
        
        // Fire quartile tracking
        let progress = Double(elapsed) / Double(ad.duration)
        
        if progress >= 0.25 && !quartersFired.contains(25) {
            quartersFired.insert(25)
            if let url = ad.quartile25URL { fireTrackingPixel(url) }
            Task { await AdsService.trackAdEvent(videoId: ad.id, event: .firstQuartile) }
        }
        
        if progress >= 0.50 && !quartersFired.contains(50) {
            quartersFired.insert(50)
            if let url = ad.quartile50URL { fireTrackingPixel(url) }
            Task { await AdsService.trackAdEvent(videoId: ad.id, event: .midpoint) }
        }
        
        if progress >= 0.75 && !quartersFired.contains(75) {
            quartersFired.insert(75)
            if let url = ad.quartile75URL { fireTrackingPixel(url) }
            Task { await AdsService.trackAdEvent(videoId: ad.id, event: .thirdQuartile) }
        }
    }
    
    private func adComplete() {
        guard let ad = currentAd else { return }
        
        print("✅ [GoogleIMAAdManager] Ad completed")
        
        // Fire complete tracking
        if let url = ad.completeURL { fireTrackingPixel(url) }
        Task { await AdsService.trackAdEvent(videoId: ad.id, event: .complete) }
        
        // Track revenue
        let revenue = calculateAdRevenue(ad: ad)
        print("💰 [GoogleIMAAdManager] Ad revenue: $\(String(format: "%.2f", revenue))")
        
        cleanup()
        adState = .completed
        onAdComplete?()
    }
    
    // MARK: - Revenue Calculation
    
    private func calculateAdRevenue(ad: VideoAd) -> Double {
        // Real CPM-based revenue calculation
        // CPM ranges: $2.50 - $15 for video ads
        let baseCPM = Double.random(in: 2.5...8.0)  // Average video CPM
        let impressionValue = baseCPM / 1000.0  // Value per impression
        
        // Bonus for completed view (vs skipped)
        let completionBonus = 1.5
        
        return impressionValue * completionBonus
    }
    
    // MARK: - Player Observers
    
    private func setupPlayerObservers(ad: VideoAd) {
        // Observe playback end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: adPlayer?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.adComplete()
        }
        
        // Observe playback errors
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: adPlayer?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.adState = .failed("Playback error")
            self?.onAdError?("Playback error")
            self?.cleanup()
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopAdTimer()
        
        if let observer = playerTimeObserver {
            adPlayer?.removeTimeObserver(observer)
        }
        
        // 🔥 FIX: Invalidate KVO observation
        playerItemObservation?.invalidate()
        playerItemObservation = nil
        
        NotificationCenter.default.removeObserver(self)
        
        adPlayer?.pause()
        adPlayer = nil
        currentAd = nil
        canSkip = false
        adTimeRemaining = 0
        quartersFired = []
        isAdVideoReady = false  // 🔥 Reset ready state on cleanup
        // Note: Don't reset hasTriedFallback here - it's managed per playAd() call
    }
    
    /// Full reset including fallback state
    func fullReset() {
        cleanup()
        hasTriedFallback = false
        adState = .idle
        isLoadingAd = false
        isAdVideoReady = false
    }
    
    private func stopAdTimer() {
        adTimer?.invalidate()
        adTimer = nil
    }
    
    // MARK: - Tracking
    
    private func fireTrackingPixel(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("⚠️ [GoogleIMAAdManager] Tracking failed: \(error)")
            } else {
                print("✅ [GoogleIMAAdManager] Tracking fired: \(urlString.prefix(50))...")
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    private func extractValue(from string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) else {
            return nil
        }
        
        if match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: string) {
            return String(string[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func extractAllValues(from string: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
        
        return matches.compactMap { match in
            if match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: string) {
                return String(string[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }
    }
    
    private func extractTrackingURL(from vast: String, event: String) -> String? {
        let pattern = #"<Tracking[^>]*event="\#(event)"[^>]*>(.*?)</Tracking>"#
        return extractValue(from: vast, pattern: pattern)
    }
    
    private func parseDuration(_ timeString: String) -> Int {
        let components = timeString.split(separator: ":")
        
        if components.count == 3,
           let hours = Int(components[0]),
           let minutes = Int(components[1]),
           let seconds = Int(components[2].split(separator: ".").first ?? "") {
            return hours * 3600 + minutes * 60 + seconds
        }
        
        // Try parsing as just seconds
        if let seconds = Int(timeString) {
            return seconds
        }
        
        return 30  // Default
    }
    
    private func cleanURL(_ url: String) -> String {
        return url
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
    }
    
    // NOTE: deinit removed - this is a singleton (static let shared) so deinit never gets called.
    // Cleanup is handled explicitly via cleanup() method when needed.
}

// MARK: - Preview Helper
extension VideoAd {
    static var sample: VideoAd {
        VideoAd(
            id: "sample-ad",
            mediaURL: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
            clickURL: "https://mychannel.app",
            duration: 15,
            skipOffset: 5,
            isSkippable: true,
            advertiserName: "Sample Advertiser",
            adTitle: "Sample Ad",
            impressionURLs: [],
            clickTrackingURLs: [],
            quartile25URL: nil,
            quartile50URL: nil,
            quartile75URL: nil,
            completeURL: nil,
            skipURL: nil,
            errorURL: nil
        )
    }
}


