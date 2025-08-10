//
//  AppConfig.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import Foundation
import SwiftUI

struct AppConfig {
    
    // MARK: - Environment
    enum Environment: String, CaseIterable {
        case development = "development"
        case staging = "staging"
        case production = "production"
        
        var displayName: String {
            switch self {
            case .development: return "Development"
            case .staging: return "Staging"
            case .production: return "Production"
            }
        }
    }
    
    // MARK: - Current Environment
    static var environment: Environment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }
    
    // MARK: - App Information
    static let appName = "MyChannel"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.yourcompany.mychannel"
    
    // MARK: - API Configuration
    struct API {
        static var baseURL: String {
            switch environment {
            case .development:
                return "https://your-dev-api.supabase.co"
            case .staging:
                return "https://your-staging-api.supabase.co"
            case .production:
                return "https://your-prod-api.supabase.co"
            }
        }

        static var cloudRunBaseURL: String {
            switch environment {
            case .development:
                return "https://mychannel-gw-b9ljiz6f.uc.gateway.dev"
            case .staging:
                return "https://mychannel-gw-b9ljiz6f.uc.gateway.dev"
            case .production:
                return "https://mychannel-gw-b9ljiz6f.uc.gateway.dev"
            }
        }
        
        static var supabaseURL: String {
            return baseURL
        }
        
        static var supabaseAnonKey: String {
            switch environment {
            case .development:
                return "your-dev-supabase-anon-key"
            case .staging:
                return "your-staging-supabase-anon-key"
            case .production:
                return "your-prod-supabase-anon-key"
            }
        }
        
        static let timeout: TimeInterval = 30.0
        static let maxRetryAttempts = 3
    }
    
    // MARK: - Video Configuration
    struct Video {
        static let maxUploadSizeMB: Int = 500
        static let maxDurationSeconds: TimeInterval = 3600 // 1 hour
        static let supportedFormats = ["mp4", "mov", "avi", "mkv"]
        static let thumbnailSize = CGSize(width: 1280, height: 720)
        
        // Video quality settings
        enum Quality: String, CaseIterable {
            case low = "360p"
            case medium = "720p"
            case high = "1080p"
            case ultra = "4K"
            
            var bitrate: Int {
                switch self {
                case .low: return 1000
                case .medium: return 5000
                case .high: return 8000
                case .ultra: return 20000
                }
            }
        }
        
        static let defaultQuality: Quality = .high
    }
    
    // MARK: - Storage Configuration
    struct Storage {
        static var bucketName: String {
            switch environment {
            case .development: return "mychannel-dev"
            case .staging: return "mychannel-staging"
            case .production: return "mychannel-prod"
            }
        }
        
        static let videoPath = "videos"
        static let thumbnailPath = "thumbnails"
        static let profileImagePath = "profiles"
        static let bannerImagePath = "banners"
    }
    
    // MARK: - Feature Flags
    struct Features {
        static let enableLiveStreaming = true
        static let enableShorts = true
        static let enableStories = true
        static let enableMonetization = environment == .production
        static let enableAnalytics = true
        static let enablePushNotifications = true
        static let enableOfflineViewing = false // Future feature
        static let enableiCloudSync = false // Future feature
        
        // Development features
        static let showDebugMenu = environment == .development
        static let enableMockData = environment == .development
        static let enableNetworkLogging = environment != .production
    }
    
    // MARK: - UI Configuration
    struct UI {
        static let animationDuration: TimeInterval = 0.3
        static let longAnimationDuration: TimeInterval = 0.5
        static let shortAnimationDuration: TimeInterval = 0.15
        
        static let cornerRadius: CGFloat = 12.0
        static let shadowRadius: CGFloat = 8.0
        static let blurRadius: CGFloat = 20.0
        
        // Pagination
        static let defaultPageSize = 20
        static let maxPageSize = 50
    }
    
    // MARK: - Notification Configuration
    struct Notifications {
        static let enableInApp = true
        static let enablePush = true
        static let autoHideDelay: TimeInterval = 3.0
        
        // Categories
        static let likeCategory = "LIKE_CATEGORY"
        static let commentCategory = "COMMENT_CATEGORY"
        static let followCategory = "FOLLOW_CATEGORY"
        static let uploadCategory = "UPLOAD_CATEGORY"
    }
    
    // MARK: - Analytics Configuration
    struct Analytics {
        static let enableCrashReporting = environment == .production
        static let enablePerformanceMonitoring = true
        static let enableUserAnalytics = environment == .production
        
        // Events
        static let videoWatchEvent = "video_watch"
        static let videoLikeEvent = "video_like"
        static let videoShareEvent = "video_share"
        static let profileViewEvent = "profile_view"
        static let searchEvent = "search"
    }
    
    // MARK: - Security Configuration
    struct Security {
        static let enableSSLPinning = environment == .production
        static let enableRequestSigning = environment == .production
        static let sessionTimeoutMinutes: TimeInterval = 60 * 24 // 24 hours
        static let maxLoginAttempts = 5
        static let lockoutDurationMinutes: TimeInterval = 15
    }
    
    // MARK: - Cache Configuration
    struct Cache {
        static let maxVideoCache = 1024 * 1024 * 500 // 500MB
        static let maxImageCache = 1024 * 1024 * 100 // 100MB
        static let cacheExpirationHours: TimeInterval = 24
    }
    
    // MARK: - Social Configuration
    struct Social {
        static let enableAppleLogin = true
        static let enableGoogleLogin = true
        static let enableFacebookLogin = false
        static let enableTwitterLogin = false
        
        // Sharing
        static let shareBaseURL = "https://mychannel.app/video/"
        static let appStoreURL = "https://apps.apple.com/app/mychannel/id123456789"
    }
    
    // MARK: - Development Tools
    struct Debug {
        static var isEnabled: Bool {
            return environment == .development && Features.showDebugMenu
        }
        
        static let enableNetworkInspector = environment == .development
        static let enableViewBorders = false
        static let enablePerformanceOverlay = false
        static let enableMemoryMonitoring = environment == .development
    }
    
    // MARK: - Helper Methods
    static func printConfiguration() {
        print("🚀 MyChannel Configuration")
        print("📱 App: \(appName) v\(appVersion) (\(buildNumber))")
        print("🌍 Environment: \(environment.displayName)")
        print("🔗 API Base URL: \(API.baseURL)")
        print("🎬 Max Upload Size: \(Video.maxUploadSizeMB)MB")
        print("✨ Features: Live=\(Features.enableLiveStreaming), Shorts=\(Features.enableShorts), Analytics=\(Features.enableAnalytics)")
        
        if Debug.isEnabled {
            print("🐛 Debug Mode: Enabled")
            print("📊 Mock Data: \(Features.enableMockData)")
            print("🌐 Network Logging: \(Features.enableNetworkLogging)")
        }
    }
}

// MARK: - Bundle Extensions
extension Bundle {
    var displayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
               object(forInfoDictionaryKey: "CFBundleName") as? String ??
               "MyChannel"
    }
    
    var appVersion: String {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    var buildNumber: String {
        return object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

// MARK: - Configuration Validation
extension AppConfig {
    static func validateConfiguration() -> [String] {
        var errors: [String] = []
        
        // Validate API configuration
        if API.baseURL.isEmpty {
            errors.append("API base URL is not configured")
        }
        
        if API.supabaseAnonKey.isEmpty || API.supabaseAnonKey.contains("your-") {
            errors.append("Supabase anonymous key is not configured")
        }
        
        // Validate video configuration
        if Video.maxUploadSizeMB <= 0 {
            errors.append("Invalid max upload size")
        }
        
        // Validate storage configuration
        if Storage.bucketName.isEmpty {
            errors.append("Storage bucket name is not configured")
        }
        
        return errors
    }
    
    static func isProductionReady() -> Bool {
        return validateConfiguration().isEmpty && environment == .production
    }
}

#if DEBUG
// MARK: - Debug Configuration Preview
struct AppConfigPreview: View {
    var body: some View {
        NavigationView {
            List {
                Section("App Information") {
                    ConfigInfoRow(icon: "app.fill", title: "Name", value: AppConfig.appName)
                    ConfigInfoRow(icon: "number", title: "Version", value: AppConfig.appVersion)
                    ConfigInfoRow(icon: "hammer.fill", title: "Build", value: AppConfig.buildNumber)
                    ConfigInfoRow(icon: "globe", title: "Environment", value: AppConfig.environment.displayName)
                }
                
                Section("API Configuration") {
                    ConfigInfoRow(icon: "link", title: "Base URL", value: AppConfig.API.baseURL)
                    ConfigInfoRow(icon: "clock", title: "Timeout", value: "\(AppConfig.API.timeout)s")
                }
                
                Section("Features") {
                    FeatureRow(title: "Live Streaming", enabled: AppConfig.Features.enableLiveStreaming)
                    FeatureRow(title: "Shorts", enabled: AppConfig.Features.enableShorts)
                    FeatureRow(title: "Stories", enabled: AppConfig.Features.enableStories)
                    FeatureRow(title: "Monetization", enabled: AppConfig.Features.enableMonetization)
                    FeatureRow(title: "Analytics", enabled: AppConfig.Features.enableAnalytics)
                }
                
                Section("Video Settings") {
                    ConfigInfoRow(icon: "video", title: "Max Upload Size", value: "\(AppConfig.Video.maxUploadSizeMB)MB")
                    ConfigInfoRow(icon: "clock.fill", title: "Max Duration", value: "\(Int(AppConfig.Video.maxDurationSeconds/60)) minutes")
                    ConfigInfoRow(icon: "tv", title: "Default Quality", value: AppConfig.Video.defaultQuality.rawValue)
                }
                
                if AppConfig.Debug.isEnabled {
                    Section("Debug") {
                        FeatureRow(title: "Mock Data", enabled: AppConfig.Features.enableMockData)
                        FeatureRow(title: "Network Logging", enabled: AppConfig.Features.enableNetworkLogging)
                        FeatureRow(title: "Debug Menu", enabled: AppConfig.Features.showDebugMenu)
                    }
                }
            }
            .navigationTitle("App Configuration")
        }
    }
}

struct ConfigInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .fontWeight(.medium)
        }
    }
}

struct FeatureRow: View {
    let title: String
    let enabled: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(enabled ? AppTheme.Colors.success : AppTheme.Colors.error)
        }
    }
}

#Preview("App Configuration") {
    AppConfigPreview()
}
#endif