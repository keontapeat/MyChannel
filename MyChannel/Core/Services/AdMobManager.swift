//
//  AdMobManager.swift
//  MyChannel
//
//  Google Mobile Ads SDK integration for REAL ad revenue! 💰
//

import Foundation
import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - 💰 AdMob Manager - Real Ads, Real Money!

/// Manages Google Mobile Ads SDK initialization and ad loading
/// Your AdMob Publisher ID: pub-6523548415882152
@MainActor
final class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()
    
    // MARK: - Published State
    @Published var isInitialized = false
    @Published var isLoadingAd = false
    @Published var lastError: String?
    
    // MARK: - Ad Unit IDs
    /// ⚠️ IMPORTANT: Replace these with your REAL ad unit IDs from AdMob console!
    /// Go to: https://admob.google.com → Apps → MyChannel → Ad units
    struct AdUnitIDs {
        // 🔥 TEST ADS (Use these during development)
        // Google provides these test IDs that always return test ads
        static let testBanner = "ca-app-pub-3940256099942544/2934735716"
        static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"
        static let testRewarded = "ca-app-pub-3940256099942544/1712485313"
        static let testRewardedInterstitial = "ca-app-pub-3940256099942544/6978759866"
        static let testNative = "ca-app-pub-3940256099942544/3986624511"
        static let testAppOpen = "ca-app-pub-3940256099942544/5662855259"
        
        // 🔥 YOUR REAL AD UNIT IDs (Create these in AdMob console)
        // Format: ca-app-pub-6523548415882152/XXXXXXXXXX
        // ⚠️ Replace "XXXXXXXXXX" with your actual ad unit IDs!
        
        /// Pre-roll video ad before main content
        static var prerollVideo: String {
            #if DEBUG
            return testRewarded // Use test ads in debug
            #else
            // TODO: Replace with your real ad unit ID
            return "ca-app-pub-6523548415882152/XXXXXXXXXX"
            #endif
        }
        
        /// Rewarded video ad (user chooses to watch for rewards)
        static var rewardedVideo: String {
            #if DEBUG
            return testRewarded
            #else
            // TODO: Replace with your real ad unit ID
            return "ca-app-pub-6523548415882152/XXXXXXXXXX"
            #endif
        }
        
        /// Interstitial ad (full-screen between content)
        static var interstitial: String {
            #if DEBUG
            return testInterstitial
            #else
            // TODO: Replace with your real ad unit ID
            return "ca-app-pub-6523548415882152/XXXXXXXXXX"
            #endif
        }
        
        /// Banner ad (persistent at bottom/top of screen)
        static var banner: String {
            #if DEBUG
            return testBanner
            #else
            // TODO: Replace with your real ad unit ID
            return "ca-app-pub-6523548415882152/XXXXXXXXXX"
            #endif
        }
        
        /// Native ad (blends with content)
        static var native: String {
            #if DEBUG
            return testNative
            #else
            // TODO: Replace with your real ad unit ID
            return "ca-app-pub-6523548415882152/XXXXXXXXXX"
            #endif
        }
        
        /// App open ad (shown when app opens)
        static var appOpen: String {
            #if DEBUG
            return testAppOpen
            #else
            // TODO: Replace with your real ad unit ID
            return "ca-app-pub-6523548415882152/XXXXXXXXXX"
            #endif
        }
    }
    
    // MARK: - Private Properties
    #if canImport(GoogleMobileAds)
    private var rewardedAd: GADRewardedAd?
    private var interstitialAd: GADInterstitialAd?
    private var appOpenAd: GADAppOpenAd?
    #endif
    
    private override init() {
        super.init()
    }
    
    // MARK: - SDK Initialization
    
    /// Initialize the Google Mobile Ads SDK
    /// Call this ONCE at app startup (in FirebaseAppDelegate)
    func initialize() {
        guard !isInitialized else {
            print("✅ [AdMob] Already initialized")
            return
        }
        
        #if canImport(GoogleMobileAds)
        print("🚀 [AdMob] Initializing Google Mobile Ads SDK...")
        
        // Start the SDK
        GADMobileAds.sharedInstance().start { [weak self] status in
            Task { @MainActor in
                self?.isInitialized = true
                
                // Log adapter status
                let adapters = status.adapterStatusesByClassName
                for (adapter, adapterStatus) in adapters {
                    print("📱 [AdMob] Adapter: \(adapter)")
                    print("   State: \(adapterStatus.state.rawValue)")
                    print("   Latency: \(adapterStatus.latency)ms")
                }
                
                print("✅ [AdMob] SDK initialized successfully!")
                print("💰 [AdMob] Publisher ID: pub-6523548415882152")
                
                // Pre-load ads for better UX
                self?.preloadAds()
            }
        }
        
        // Configure SDK settings
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [
            GADSimulatorID, // Always gets test ads on simulator
            // Add your real device IDs here for testing:
            // "YOUR-DEVICE-ID-HERE"
        ]
        
        #else
        print("⚠️ [AdMob] GoogleMobileAds SDK not imported - add it via SPM")
        print("📦 Package URL: https://github.com/googleads/swift-package-manager-google-mobile-ads")
        #endif
    }
    
    // MARK: - Pre-load Ads
    
    private func preloadAds() {
        #if canImport(GoogleMobileAds)
        // Pre-load rewarded ad
        loadRewardedAd()
        
        // Pre-load interstitial
        loadInterstitialAd()
        
        print("📦 [AdMob] Pre-loading ads...")
        #endif
    }
    
    // MARK: - 🎬 Rewarded Video Ads (Best for video apps!)
    
    /// Load a rewarded video ad
    func loadRewardedAd() {
        #if canImport(GoogleMobileAds)
        guard isInitialized else {
            print("⚠️ [AdMob] SDK not initialized yet")
            return
        }
        
        isLoadingAd = true
        
        let request = GADRequest()
        
        GADRewardedAd.load(withAdUnitID: AdUnitIDs.rewardedVideo, request: request) { [weak self] ad, error in
            Task { @MainActor in
                self?.isLoadingAd = false
                
                if let error = error {
                    print("❌ [AdMob] Failed to load rewarded ad: \(error.localizedDescription)")
                    self?.lastError = error.localizedDescription
                    return
                }
                
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                print("✅ [AdMob] Rewarded ad loaded!")
            }
        }
        #endif
    }
    
    /// Show a rewarded video ad
    /// - Parameters:
    ///   - viewController: The presenting view controller
    ///   - onReward: Callback when user earns reward
    ///   - onDismiss: Callback when ad is dismissed
    func showRewardedAd(
        from viewController: UIViewController? = nil,
        onReward: @escaping (Double) -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        #if canImport(GoogleMobileAds)
        guard let ad = rewardedAd else {
            print("⚠️ [AdMob] Rewarded ad not ready, loading...")
            loadRewardedAd()
            return
        }
        
        guard let rootVC = viewController ?? getRootViewController() else {
            print("❌ [AdMob] No view controller to present from")
            return
        }
        
        ad.present(fromRootViewController: rootVC) { [weak self] in
            // User earned reward!
            let reward = ad.adReward
            let amount = reward.amount.doubleValue
            let type = reward.type
            
            print("🎉 [AdMob] User earned reward: \(amount) \(type)")
            
            // Track revenue (eCPM-based estimation)
            let estimatedRevenue = self?.calculateRewardedAdRevenue() ?? 0.015
            
            Task {
                await AdvancedAnalyticsService.shared.trackRevenue(
                    videoId: "rewarded_ad",
                    amount: estimatedRevenue,
                    source: "admob_rewarded"
                )
            }
            
            onReward(amount)
        }
        
        // Pre-load next ad
        loadRewardedAd()
        #else
        print("⚠️ [AdMob] SDK not available")
        #endif
    }
    
    /// Check if rewarded ad is ready
    var isRewardedAdReady: Bool {
        #if canImport(GoogleMobileAds)
        return rewardedAd != nil
        #else
        return false
        #endif
    }
    
    // MARK: - 📺 Interstitial Ads
    
    /// Load an interstitial ad
    func loadInterstitialAd() {
        #if canImport(GoogleMobileAds)
        guard isInitialized else { return }
        
        let request = GADRequest()
        
        GADInterstitialAd.load(withAdUnitID: AdUnitIDs.interstitial, request: request) { [weak self] ad, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ [AdMob] Failed to load interstitial: \(error.localizedDescription)")
                    return
                }
                
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
                print("✅ [AdMob] Interstitial ad loaded!")
            }
        }
        #endif
    }
    
    /// Show an interstitial ad
    func showInterstitialAd(from viewController: UIViewController? = nil, completion: (() -> Void)? = nil) {
        #if canImport(GoogleMobileAds)
        guard let ad = interstitialAd else {
            print("⚠️ [AdMob] Interstitial not ready")
            loadInterstitialAd()
            completion?()
            return
        }
        
        guard let rootVC = viewController ?? getRootViewController() else {
            completion?()
            return
        }
        
        ad.present(fromRootViewController: rootVC)
        loadInterstitialAd() // Pre-load next
        #else
        completion?()
        #endif
    }
    
    // MARK: - 🚀 App Open Ads
    
    /// Load an app open ad
    func loadAppOpenAd() {
        #if canImport(GoogleMobileAds)
        guard isInitialized else { return }
        
        let request = GADRequest()
        
        GADAppOpenAd.load(withAdUnitID: AdUnitIDs.appOpen, request: request) { [weak self] ad, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ [AdMob] Failed to load app open ad: \(error.localizedDescription)")
                    return
                }
                
                self?.appOpenAd = ad
                self?.appOpenAd?.fullScreenContentDelegate = self
                print("✅ [AdMob] App open ad loaded!")
            }
        }
        #endif
    }
    
    /// Show app open ad (call when app comes to foreground)
    func showAppOpenAd() {
        #if canImport(GoogleMobileAds)
        guard let ad = appOpenAd, let rootVC = getRootViewController() else {
            loadAppOpenAd()
            return
        }
        
        ad.present(fromRootViewController: rootVC)
        loadAppOpenAd() // Pre-load next
        #endif
    }
    
    // MARK: - Helpers
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    
    private func calculateRewardedAdRevenue() -> Double {
        // Estimated eCPM for rewarded video ads: $10-30
        // This is per 1000 impressions, so per impression = eCPM / 1000
        let estimatedECPM = 15.0 // Conservative estimate
        return estimatedECPM / 1000.0
    }
}

// MARK: - Full Screen Content Delegate

#if canImport(GoogleMobileAds)
extension AdMobManager: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            print("📺 [AdMob] Ad dismissed")
            
            // Track completion
            if ad is GADRewardedAd {
                rewardedAd = nil
            } else if ad is GADInterstitialAd {
                interstitialAd = nil
            } else if ad is GADAppOpenAd {
                appOpenAd = nil
            }
        }
    }
    
    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("❌ [AdMob] Ad failed to present: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
    
    nonisolated func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            print("📺 [AdMob] Ad will present")
        }
    }
    
    nonisolated func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            print("💰 [AdMob] Ad impression recorded!")
            
            // Track impression for analytics
            Task {
                await AdvancedAnalyticsService.shared.trackEvent(
                    name: "ad_impression",
                    parameters: ["ad_type": String(describing: type(of: ad))]
                )
            }
        }
    }
    
    nonisolated func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            print("👆 [AdMob] Ad clicked!")
            
            // Clicks are worth more! Track it
            Task {
                await AdvancedAnalyticsService.shared.trackEvent(
                    name: "ad_click",
                    parameters: ["ad_type": String(describing: type(of: ad))]
                )
            }
        }
    }
}
#endif

// MARK: - SwiftUI Banner Ad View

#if canImport(GoogleMobileAds)
/// SwiftUI wrapper for banner ads
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    
    init(adUnitID: String = AdMobManager.AdUnitIDs.banner) {
        self.adUnitID = adUnitID
    }
    
    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = context.coordinator.rootViewController
        bannerView.load(GADRequest())
        return bannerView
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var rootViewController: UIViewController? {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return nil
            }
            return window.rootViewController
        }
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct AdMobManager_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("AdMob Integration")
                .font(.title)
            
            Text("Add GoogleMobileAds SDK via SPM to enable real ads")
                .foregroundColor(.secondary)
            
            #if canImport(GoogleMobileAds)
            BannerAdView()
                .frame(height: 50)
            #else
            Text("SDK not installed")
                .foregroundColor(.red)
            #endif
        }
        .padding()
    }
}
#endif


