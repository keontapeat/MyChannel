import Foundation

// 🔐 SECURE API KEY ACCESS - App Store Compliant
// Order: Keychain (secure) -> Environment variable (build time) -> Info.plist (fallback, will be removed)
struct AppSecrets {
    
    // MARK: - 🔥 SECURE KEYCHAIN ACCESS (New Standard)
    
    static var anthropicAPIKey: String {
        // Priority 1: Keychain (secure, can't be extracted)
        if let keychainValue = KeychainManager.shared.get(KeychainManager.APIKey.anthropic.rawValue),
           !keychainValue.isEmpty {
            return keychainValue
        }
        
        // Priority 2: Environment variable (build time only)
        let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        if !env.isEmpty { return env }
        
        // Priority 3: Info.plist fallback (DEPRECATED - will be removed)
        let plist = (Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        
        return ""
    }
    
    static var openAIAPIKey: String {
        if let keychainValue = KeychainManager.shared.get(KeychainManager.APIKey.openai.rawValue),
           !keychainValue.isEmpty {
            return keychainValue
        }
        
        let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if !env.isEmpty { return env }
        
        let plist = (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        
        return ""
    }
    
    // MARK: - 📺 AdMob Ad Unit IDs (not secret — shipped in binary; configured via Info.plist)

    private static func admobUnitID(_ infoPlistKey: String) -> String {
        let value = (Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty, !value.isPlistPlaceholder { return value }
        return ""
    }

    static var admobPrerollVideoUnitID: String { admobUnitID("ADMOB_PREROLL_VIDEO_UNIT_ID") }
    static var admobRewardedVideoUnitID: String { admobUnitID("ADMOB_REWARDED_VIDEO_UNIT_ID") }
    static var admobInterstitialUnitID: String { admobUnitID("ADMOB_INTERSTITIAL_UNIT_ID") }
    static var admobBannerUnitID: String { admobUnitID("ADMOB_BANNER_UNIT_ID") }
    static var admobNativeUnitID: String { admobUnitID("ADMOB_NATIVE_UNIT_ID") }
    static var admobAppOpenUnitID: String { admobUnitID("ADMOB_APP_OPEN_UNIT_ID") }

    // MARK: - 🚀 NEW SUPER AGI PARTNERS
    
    static var runwayAPIKey: String {
        if let keychainValue = KeychainManager.shared.get("RUNWAY_API_KEY"),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = ProcessInfo.processInfo.environment["RUNWAY_API_KEY"] ?? ""
        if !env.isEmpty { return env }
        return ""
    }
    
    static var elevenLabsAPIKey: String {
        if let keychainValue = KeychainManager.shared.get("ELEVENLABS_API_KEY"),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"] ?? ""
        if !env.isEmpty { return env }
        return ""
    }
    
    static var stabilityAPIKey: String {
        if let keychainValue = KeychainManager.shared.get("STABILITY_API_KEY"),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = ProcessInfo.processInfo.environment["STABILITY_API_KEY"] ?? ""
        if !env.isEmpty { return env }
        return ""
    }
    
    static var googleCloudAPIKey: String {
        if let keychainValue = KeychainManager.shared.get(KeychainManager.APIKey.googleCloud.rawValue),
           !keychainValue.isEmpty {
            return keychainValue
        }
        
        let env = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_API_KEY"] ?? ""
        if !env.isEmpty { return env }
        
        let plist = (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLOUD_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        
        return ""
    }
    
    static var googleCloudProjectID: String {
        if let keychainValue = KeychainManager.shared.get(KeychainManager.APIKey.googleCloudProject.rawValue),
           !keychainValue.isEmpty {
            return keychainValue
        }
        
        let env = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT_ID"] ?? ""
        if !env.isEmpty { return env }
        
        let plist = (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLOUD_PROJECT_ID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        
        return ""
    }
    
    // MARK: - Stripe (Payment Processing)
    
    static var stripePublishableKey: String {
        if let keychainValue = KeychainManager.shared.get("STRIPE_PUBLISHABLE_KEY"),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"] ?? ""
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "STRIPE_PUBLISHABLE_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ""
    }
    
    // stripeSecretKey intentionally removed from the iOS client.
    // All Stripe secret-key operations (PaymentIntents, Identity, payouts)
    // must go through authenticated Cloud Functions. Never reintroduce a
    // client-side STRIPE_SECRET_KEY accessor.
    
    // MARK: - Non-Sensitive Keys (Can stay in plist)
    
    static var aiAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "AI_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return (ProcessInfo.processInfo.environment["AI_API_KEY"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static var tmdbAPIKey: String {
        // TMDB key is public, can stay in plist
        if let keychainValue = KeychainManager.shared.get(KeychainManager.APIKey.tmdb.rawValue),
           !keychainValue.isEmpty {
            return keychainValue
        }
        
        let plist = (Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }

        let env = (ProcessInfo.processInfo.environment["TMDB_API_KEY"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !env.isEmpty { return env }

        // Fallback to default TMDB API key for movies (public API)
        return "cc1d44a1b1c8a4f2a5890cad1660d0be"
    }

    static var pexelsAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "PEXELS_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ProcessInfo.processInfo.environment["PEXELS_API_KEY"] ?? ""
    }

    static var pixabayAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "PIXABAY_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ProcessInfo.processInfo.environment["PIXABAY_API_KEY"] ?? ""
    }

    static var youtubeAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return (ProcessInfo.processInfo.environment["YOUTUBE_API_KEY"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Observability & Monetization Keys

    static var sentryDSN: String {
        let env = ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? ""
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ""
    }

    static var postHogAPIKey: String {
        let env = ProcessInfo.processInfo.environment["POSTHOG_API_KEY"] ?? ""
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ""
    }

    static var revenueCatAPIKey: String {
        let env = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"] ?? ""
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ""
    }

    static var pineconeAPIKey: String? {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "PINECONE_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        
        let env = (ProcessInfo.processInfo.environment["PINECONE_API_KEY"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !env.isEmpty { return env }
        
        return nil
    }
    
    static var algoliaAppID: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "ALGOLIA_APP_ID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        let env = (ProcessInfo.processInfo.environment["ALGOLIA_APP_ID"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return env
    }
    
    static var algoliaAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "ALGOLIA_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        let env = (ProcessInfo.processInfo.environment["ALGOLIA_API_KEY"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return env
    }
}

private extension String {
    var isPlistPlaceholder: Bool {
        // Xcode leaves $(VAR) or ${VAR} unresolved if no value is provided at build time
        contains("$(") || contains("${")
    }
}

