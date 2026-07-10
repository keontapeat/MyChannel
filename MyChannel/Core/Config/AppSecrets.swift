import Foundation

// 🔐 SECURE API KEY ACCESS - App Store Compliant
// Order: Keychain (secure) -> Environment variable (build time) -> Info.plist (fallback, will be removed)
struct AppSecrets {
    
    // MARK: - 🔥 SECURE KEYCHAIN ACCESS (New Standard)

    /// Debug/Simulator may read env vars; Release ignores env for secrets (Keychain → plist only).
    private static func envOverride(_ key: String) -> String {
        #if DEBUG
        return (ProcessInfo.processInfo.environment[key] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        return ""
        #endif
    }

    /// Never log secret values — redact for observability.
    static func redactSecret(_ value: String) -> String {
        guard value.count > 8 else { return value.isEmpty ? "(empty)" : "****" }
        return String(value.prefix(4)) + "…" + String(value.suffix(4))
    }
    
    static var anthropicAPIKey: String {
        // Priority 1: Keychain (secure, can't be extracted)
        if let keychainValue = KeychainManager.shared.get(KeychainManager.APIKey.anthropic.rawValue),
           !keychainValue.isEmpty {
            return keychainValue
        }
        
        // Priority 2: Environment variable (DEBUG builds only)
        let env = envOverride("ANTHROPIC_API_KEY")
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
        
        let env = envOverride("OPENAI_API_KEY")
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
        // Keychain-first (see docs/secrets-rotation-checklist.md)
        if let keychainValue = KeychainManager.shared.get("RUNWAY_API_KEY"),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = envOverride("RUNWAY_API_KEY")
        if !env.isEmpty { return env }
        return ""
    }
    
    static var elevenLabsAPIKey: String {
        // Keychain-first — never ship in Info.plist
        if let keychainValue = KeychainManager.shared.get("ELEVENLABS_API_KEY"),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = envOverride("ELEVENLABS_API_KEY")
        if !env.isEmpty { return env }
        return ""
    }
    
    static var stabilityAPIKey: String {
        // Keychain-first — never ship in Info.plist
        if let keychainValue = KeychainManager.shared.get("STABILITY_API_KEY"),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = envOverride("STABILITY_API_KEY")
        if !env.isEmpty { return env }
        return ""
    }
    
    static var googleCloudAPIKey: String {
        if let keychainValue = KeychainManager.shared.get(KeychainManager.APIKey.googleCloud.rawValue),
           !keychainValue.isEmpty {
            return keychainValue
        }
        
        let env = envOverride("GOOGLE_CLOUD_API_KEY")
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
        
        let env = envOverride("GOOGLE_CLOUD_PROJECT_ID")
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
        let env = envOverride("STRIPE_PUBLISHABLE_KEY")
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
        // Keychain → env → plist (same priority as anthropic/openAI)
        if let keychainValue = KeychainManager.shared.get(KeychainManager.APIKey.openai.rawValue),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = envOverride("AI_API_KEY")
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "AI_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ""
    }
    
    static var tmdbAPIKey: String {
        // TMDB key is public but must not be hardcoded in source — Keychain → plist → env.
        if let keychainValue = KeychainManager.shared.get(KeychainManager.APIKey.tmdb.rawValue),
           !keychainValue.isEmpty {
            return keychainValue
        }
        
        let plist = (Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }

        let env = envOverride("TMDB_API_KEY")
        if !env.isEmpty { return env }

        // Fail closed — no baked-in fallback key in the binary.
        return ""
    }

    static var pexelsAPIKey: String {
        if let keychainValue = KeychainManager.shared.get("PEXELS_API_KEY"),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = envOverride("PEXELS_API_KEY")
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "PEXELS_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        // Fail closed — no baked-in fallback key in the binary.
        return ""
    }

    static var pixabayAPIKey: String {
        if let keychainValue = KeychainManager.shared.get("PIXABAY_API_KEY"),
           !keychainValue.isEmpty {
            return keychainValue
        }
        let env = envOverride("PIXABAY_API_KEY")
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "PIXABAY_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        // Fail closed — no baked-in fallback key in the binary.
        return ""
    }

    static var youtubeAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return envOverride("YOUTUBE_API_KEY")
    }
    
    // MARK: - Observability & Monetization Keys

    static var sentryDSN: String {
        let env = envOverride("SENTRY_DSN")
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "SENTRY_DSN") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ""
    }

    static var postHogAPIKey: String {
        let env = envOverride("POSTHOG_API_KEY")
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ""
    }

    static var revenueCatAPIKey: String {
        let env = envOverride("REVENUECAT_API_KEY")
        if !env.isEmpty { return env }
        let plist = (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        return ""
    }

    static var pineconeAPIKey: String? {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "PINECONE_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        
        let env = envOverride("PINECONE_API_KEY")
        if !env.isEmpty { return env }
        
        return nil
    }
    
    static var algoliaAppID: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "ALGOLIA_APP_ID") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !plist.isPlistPlaceholder { return plist }
        let env = envOverride("ALGOLIA_APP_ID")
        return env
    }
    
    static var algoliaAPIKey: String {
        let plist = (Bundle.main.object(forInfoDictionaryKey: "ALGOLIA_API_KEY") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !plist.isEmpty, !isInfoPlistPlaceholder(plist) { return plist }
        let env = envOverride("ALGOLIA_API_KEY")
        return env
    }

    /// Detect unresolved Xcode build-setting placeholders in Info.plist values.
    /// Returns true for `$(VAR)` or `${VAR}` strings left unsubstituted at build time.
    static func isInfoPlistPlaceholder(_ value: String) -> Bool {
        value.contains("$(") || value.contains("${")
    }
}

private extension String {
    var isPlistPlaceholder: Bool {
        AppSecrets.isInfoPlistPlaceholder(self)
    }
}

