//
//  AppConfig.swift
//  MyChannel
//
//  Created by AI Assistant on 8/9/25.
//

import Foundation

// MARK: - 🔧 App Configuration
struct AppConfig {
    
    // MARK: - Environment
    enum Environment {
        case development
        case staging
        case production
        
        var displayName: String {
            switch self {
            case .development: return "Development"
            case .staging: return "Staging"
            case .production: return "Production"
            }
        }
        
        var apiBaseURL: String {
            switch self {
            case .development: return "https://dev-api.mychannel.app"
            case .staging: return "https://staging-api.mychannel.app"
            case .production: return "https://api.mychannel.app"
            }
        }
    }
    
    static let environment: Environment = {
        // Use staging when dev API is unreachable in Simulator
        #if DEBUG
        return .staging
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }()
    
    // MARK: - Video Configuration
    struct Video {
        enum Quality: String, CaseIterable {
            case quality240p = "240p"
            case quality360p = "360p"
            case quality480p = "480p"
            case quality720p = "720p"
            case quality1080p = "1080p"
            case quality1440p = "1440p"
            case quality4K = "4K"
            
            var displayName: String { return rawValue }
            var bitrate: Int {
                switch self {
                case .quality240p: return 300_000
                case .quality360p: return 700_000
                case .quality480p: return 1_500_000
                case .quality720p: return 5_000_000
                case .quality1080p: return 8_000_000
                case .quality1440p: return 16_000_000
                case .quality4K: return 35_000_000
                }
            }
        }
        
        static let defaultQuality = Quality.quality720p
        static let supportedFormats = ["mp4", "mov", "m4v"]
        static let maxDuration: TimeInterval = 10 * 60 * 60 // 10 hours
        static let maxDurationSeconds: TimeInterval = 10 * 60 * 60 // 10 hours
        static let minDuration: TimeInterval = 1 // 1 second
        static let maxUploadSizeMB: Int = 2048 // 2GB
        static let thumbnailSize = CGSize(width: 320, height: 180) // 16:9 aspect ratio
    }
    
    // MARK: - API Configuration
    struct API {
        static let baseURL = environment.apiBaseURL
        static let cloudRunBaseURL = "https://mychannel-ai-124515086975.us-central1.run.app"
        static let gatewayBaseURL = "https://mychannel-gw-1l792fzz.uc.gateway.dev"
        static let adsBaseURL: String = gatewayBaseURL
        static let mlAgentsURL: String? = "https://ml-agents-fkri6ifojq-uc.a.run.app"
        static let version = "v1"
        static let timeout: TimeInterval = 30.0
        // Note: This app uses Firebase exclusively - no Supabase needed
        static let supabaseAnonKey = "" // Deprecated - use Firebase
        
        // Google Cloud Partner Benefits
        static var googleCloudAPIKey: String? {
            return AppSecrets.googleCloudAPIKey.isEmpty ? nil : AppSecrets.googleCloudAPIKey
        }
        
        static var googleCloudProjectID: String? {
            return AppSecrets.googleCloudProjectID.isEmpty ? nil : AppSecrets.googleCloudProjectID
        }
        static let chatWebSocketBaseURL: String = {
            switch environment {
            case .development: return "wss://dev-api.mychannel.app/chat"
            case .staging: return "wss://staging-api.mychannel.app/chat"
            case .production: return "wss://api.mychannel.app/chat"
            }
        }()
        
        // API Endpoints
        struct Endpoints {
            static let videos = "/videos"
            static let users = "/users"
            static let analytics = "/analytics"
            static let ai = "/ai"
            static let upload = "/upload"
            static let flicks = "/flicks"
            static let recommendations = "/recommendations"
            // Ads (served via API Gateway → ads service)
            static let adsVMAP = "/ads/vmap"
        }
    }
    
    // MARK: - App Information
    struct App {
        static let name = "MyChannel"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.mychannel.app"
    }
    
    // Convenience accessor for app version
    static let appVersion = App.version
    
    // MARK: - Feature Flags
    struct Features {
        static let enableFlicks = true
        static let enableLiveStreaming = true
        static let enableAIRecommendations = true
        static let enablePremiumFeatures = true
        static let enableAnalytics = true
        static let enablePushNotifications = true
        static let enableDeepLinks = true
        static let enableOfflineDownload = true
        // 🔥 FIX 2.1(b): Hide subscription purchase UI until IAPs are submitted & approved
        // Flip to `true` once App Store Connect IAPs are approved by App Review.
        static let enableSubscriptions = false
        // 🔥 FIX 3.1.1: Hide ALL external payment features (Stripe tips, Super Thanks,
        // fan funding, creator payouts) until proper IAP integration is complete.
        // These bypass Apple IAP and violate Guideline 3.1.1.
        static let enableTipping = false
        static let enableCreatorMonetization = false
        // Disable mock data in TestFlight/app store; allow in debug
        static let enableMockData: Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }()
        static let enableNetworkLogging = isDebug // Enable network logging in debug mode

        static let enableFlicksPeek = false
        // Ads
        static let enableAds = true
    }
    
    // MARK: - Performance Settings
    struct Performance {
        static let maxVideoPreload = 3
        static let videoQualityOptions = ["360p", "480p", "720p", "1080p"]
        static let defaultVideoQuality = "720p"
        static let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
        static let backgroundTaskTimeout: TimeInterval = 30.0
    }
    
    // MARK: - Verification Configuration
    struct Verification {
        /// Minimum subscribers required for automatic eligibility
        static let subscriberMilestone: Int = 100_000
        /// Minimum lifetime views required if subscriber milestone is not met
        static let totalViewsMilestone: Int = 5_000_000
        /// Minimum published videos required to unlock manual review
        static let minimumVideoCount: Int = 50
        /// Minimum account age (days) before a badge can be awarded
        static let minimumAccountAgeDays: Int = 30
        /// Enable automatic eligibility checks when stats update
        static let enableAutoEligibility: Bool = true
    }
    
    // MARK: - UI Configuration
    struct UI {
        static let animationDuration: TimeInterval = 0.3
        static let tabBarHeight: CGFloat = 83
        static let miniPlayerHeight: CGFloat = 60
        static let maxVideoAspectRatio: CGFloat = 16/9
        static let minVideoAspectRatio: CGFloat = 9/16
    }
    
    // MARK: - Analytics
    struct Analytics {
        static let enableCrashReporting = true
        static let enablePerformanceTracking = true
        static let enableUserBehaviorTracking = true
        static let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes
        static let videoWatchEvent = "video_watch"
        static let videoLikeEvent = "video_like"
        static let videoShareEvent = "video_share"
        static let videoCommentEvent = "video_comment"
    }
    
    // MARK: - Security
    struct Security {
        static let enableBiometricAuth = true
        static let sessionDuration: TimeInterval = 24 * 60 * 60 // 24 hours
        static let maxLoginAttempts = 5
        // Disable SSL pinning for staging (KAS server has wrong certificate)
        static let enableSSLPinning: Bool = {
            #if DEBUG
            return false // Allow self-signed/mismatched certs in development/staging
            #else
            return true // Enable for production only
            #endif
        }()
    }
    
    // MARK: - Storage Configuration
    struct Storage {
        static let thumbnailPath = "thumbnails"
        static let videoPath = "videos"
        static let profileImagePath = "profile-images"
        static let tempPath = "temp"
        static let maxFileSize: Int64 = 2 * 1024 * 1024 * 1024 // 2GB
    }
    
    // MARK: - Environment Detection
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var isPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    static var isTestFlight: Bool {
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
    
    static var isAppStore: Bool {
        return !isDebug && !isTestFlight
    }
    
    // MARK: - URL Schemes
    struct URLSchemes {
        static let main = "mychannel"
        static let video = "mychannel://video"
        static let profile = "mychannel://profile"
        static let flicks = "mychannel://flicks"
    }
    
    // MARK: - Social Media
    struct Social {
        static let twitterHandle = "@MyChannelApp"
        static let instagramHandle = "@MyChannelApp"
        static let websiteURL = "https://www.mychannel.app"
        static let supportEmail = "support@mychannel.app"
        static let enableAppleLogin = true
        static let enableGoogleLogin = true
        static let enableFacebookLogin = false
        static let enableTwitterLogin = false
    }
}

// MARK: - Environment-specific Configuration
extension AppConfig {
    static func configure() {
        // Configure based on environment
        if isDebug {
            print("🔧 Configuring for DEBUG environment")
            // Debug-specific configurations
        } else if isTestFlight {
            print("🔧 Configuring for TESTFLIGHT environment")
            // TestFlight-specific configurations
        } else {
            print("🔧 Configuring for PRODUCTION environment")
            // Production-specific configurations
        }
    }
}