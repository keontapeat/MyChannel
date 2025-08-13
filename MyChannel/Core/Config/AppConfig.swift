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
        #if DEBUG
        return .development
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
        static let cloudRunBaseURL = "https://mychannel-api-abcd123-uc.a.run.app"
        static let version = "v1"
        static let timeout: TimeInterval = 30.0
        static let supabaseAnonKey = "your-supabase-anon-key-here" // Replace with actual key
        
        // API Endpoints
        struct Endpoints {
            static let videos = "/videos"
            static let users = "/users"
            static let analytics = "/analytics"
            static let ai = "/ai"
            static let upload = "/upload"
            static let flicks = "/flicks"
            static let recommendations = "/recommendations"
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
        static let enableMockData = isDebug // Enable mock data in debug mode
        static let enableNetworkLogging = isDebug // Enable network logging in debug mode

        static let enableFlicksPeek = false
    }
    
    // MARK: - Performance Settings
    struct Performance {
        static let maxVideoPreload = 3
        static let videoQualityOptions = ["360p", "480p", "720p", "1080p"]
        static let defaultVideoQuality = "720p"
        static let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
        static let backgroundTaskTimeout: TimeInterval = 30.0
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
        static let enableSSLPinning = true
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