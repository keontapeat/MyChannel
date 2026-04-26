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
        static let enableAnalyticsPredictor = false
        static let enableUserSegmentation = false
        static let enableVertexAI = false
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

        // 🔒 Direct Vertex AI Agent Builder `detectIntent` calls from the iOS client.
        // Disabled: these require OAuth + per-agent permissions the app cannot supply
        // and previously produced endless 404/401s. Route through `agentProxy` function instead.
        static let enableVertexDirectAgentCalls = false

        // MARK: - Phase 51–100 Flags
        // All default OFF; flip per-phase as each wave lands in production.

        // Wave 11 — Post-Launch Growth (51–55)
        static let enableReferralLoop = false              // Phase 51
        static let enableOnboardingExperiments = false     // Phase 52
        static let enableSmartPushTiming = false           // Phase 53
        static let enableLifecycleMessaging = false        // Phase 54
        static let enableAppClipAndWidgets = false         // Phase 55

        // Wave 12 — Monetization Depth (56–60) — gated by enableCreatorMonetization
        static let enableShoppableVideo = false            // Phase 56
        static let enableCreatorFund = false               // Phase 57
        static let enableAdYieldV2 = false                 // Phase 58
        static let enableTieredSubscriptions = false       // Phase 59
        static let enableVirtualGifts = false              // Phase 60 (IAP-only)

        // Wave 13 — Global Scale (61–65)
        static let enableFullLocalization = false          // Phase 61
        static let enableRegionalLicensing = false         // Phase 62
        static let enableEdgeCompute = false               // Phase 63
        static let enableMultiRegionFirestore = false      // Phase 64
        static let enableTaxFX = false                     // Phase 65

        // Wave 14 — Creator Power Tools (66–70)
        static let enableMultiTrackEditor = false          // Phase 66
        static let enableAIBrollVeo = false                // Phase 67
        static let enablePodcastMode = false               // Phase 68
        static let enableCollaborativeDrafts = false       // Phase 69
        static let enablePublicCreatorAPI = false          // Phase 70

        // Wave 15 — Trust & Safety (71–75)
        static let enableKidsMode = false                  // Phase 71
        static let enableDSACompliance = false             // Phase 72
        static let enableC2PAProvenance = false            // Phase 73
        static let enableCopyrightMatchV2 = false          // Phase 74
        static let enableLEPortal = false                  // Phase 75 (ops-only)

        // Wave 16 — AI-Native UX (76–80)
        static let enableAmbientAgent = false              // Phase 76
        static let enableConversationalSearch = false      // Phase 77
        static let enableAIHost = false                    // Phase 78
        static let enableSmartClipping = false             // Phase 79
        static let enableGenerativeThumbnails = false      // Phase 80

        // Wave 17 — Verticals (81–85)
        static let enableEsportsHub = false                // Phase 81
        static let enableSportsLiveCards = false           // Phase 82
        static let enableGameClipSDK = false               // Phase 83
        static let enableWatchParties = false              // Phase 84
        static let enableInteractiveLive = false           // Phase 85

        // Wave 18 — Platforms II (86–90) — platform targets, not flags. Kept for parity.
        static let enableVisionProV2 = false               // Phase 90 visionOS

        // Wave 19 — Infra Hard-Mode (91–95) — ops only; FinOps observable flag:
        static let enableFinOpsDashboard = false           // Phase 93

        // Wave 20 — Moonshots (96–100)
        static let enableMyChannelOriginals = false        // Phase 96
        static let enableCreatorAccelerator = false        // Phase 97
        static let enablePasskeyIdentity = false           // Phase 98
        static let enableMiniAppSDK = false                // Phase 99
        static let enableIPOReadiness = false              // Phase 100

        // MARK: - Phase 101–120 Flags (Deep Roadmap III)

        // Wave 21 — Ecosystem & Developer Flywheel (101–105)
        static let enableMiniAppMarketplace = false        // Phase 101
        static let enableCreatorPluginSDK = false          // Phase 102
        static let enablePublicAPIV2 = false               // Phase 103
        static let enablePartnerIntegrations = false       // Phase 104
        static let enableAutomationRecipes = false         // Phase 105

        // Wave 22 — Enterprise & Team Creation (106–110)
        static let enableTeamWorkspaces = false            // Phase 106
        static let enableMultiChannelCMS = false           // Phase 107
        static let enableRightsClearanceV2 = false         // Phase 108
        static let enableSponsorshipCRM = false            // Phase 109
        static let enableWhiteLabelDistribution = false    // Phase 110

        // Wave 23 — Personalization & Intelligence (111–115)
        static let enableSessionGraphRecommender = false   // Phase 111
        static let enableFeedAutopilot = false             // Phase 112
        static let enableAISearchV3 = false                // Phase 113
        static let enableCreatorGrowthCopilotV2 = false    // Phase 114
        static let enableAutoLocalizationStudio = false    // Phase 115

        // Wave 24 — Resilience, Governance & Future Bets (116–120)
        static let enableGlobalControlPlane = false        // Phase 116
        static let enableDataResidency = false             // Phase 117
        static let enableSafetyOpsCenter = false           // Phase 118
        static let enableSustainability = false            // Phase 119
        static let enableDecadeStrategy = false            // Phase 120

        // MARK: - Phase 121–140 Flags (Deep Roadmap IV)

        // Wave 25 — Social & Community Depth (121–125)
        static let enableCommunitySpaces = false           // Phase 121
        static let enableCollaborativePlaylistsV2 = false  // Phase 122
        static let enableFanClubs = false                  // Phase 123
        static let enableSocialClipsDuets = false          // Phase 124
        static let enableGroupWatchPartiesV2 = false       // Phase 125

        // Wave 26 — Creator Autonomy & Tools (126–130)
        static let enableAIVideoEditorV2 = false           // Phase 126
        static let enableMultiFormatPublisher = false      // Phase 127
        static let enableRevenueIntelligence = false       // Phase 128
        static let enableCreatorCRM = false                // Phase 129
        static let enableContentLicensingOutbound = false  // Phase 130

        // Wave 27 — Next-Gen Media & Immersive (131–135)
        static let enableInteractiveVideo = false          // Phase 131
        static let enableVolumetricVideo = false           // Phase 132
        static let enableAIMusicComposer = false           // Phase 133
        static let enableRealTimeTranslation = false       // Phase 134
        static let enableAccessibilityIntelligence = false // Phase 135

        // Wave 28 — Platform Defensibility & Network Effects (136–140)
        static let enableCreatorGuilds = false             // Phase 136
        static let enableFederatedIdentity = false         // Phase 137
        static let enablePredictiveInfra = false           // Phase 138
        static let enableOpenAlgorithmMarketplace = false  // Phase 139
        static let enablePlatformGovernance = false        // Phase 140

        // MARK: - Phase 141–160 Flags (Deep Roadmap V — VideoDetailView)

        // Wave 29 — Player UX Refinement (141–145)
        static let enablePinchToZoom = false               // Phase 141
        static let enableAmbientMode = false               // Phase 142
        static let enableVolumeNormalization = false        // Phase 143
        static let enableSmartScrubPreviews = false         // Phase 144
        static let enablePlaybackSpeedCurves = false        // Phase 145

        // Wave 30 — Engagement & Social Layer (146–150)
        static let enableTimestampedComments = false        // Phase 146
        static let enableLiveReactionsTimeline = false      // Phase 147
        static let enableCollaborativeAnnotations = false   // Phase 148
        static let enableWatchTogetherSync = false          // Phase 149
        static let enableVideoPollsQuizzes = false          // Phase 150

        // Wave 31 — Intelligence & Context (151–155)
        static let enableAIVideoSummary = false             // Phase 151
        static let enableSmartChapterAutoGen = false        // Phase 152
        static let enableRelatedContextCards = false        // Phase 153
        static let enableSentimentHeatmap = false           // Phase 154
        static let enableMultiAngleViewer = false           // Phase 155

        // Wave 32 — Accessibility & Adaptive Player (156–160)
        static let enablePiPv3 = false                      // Phase 156
        static let enableHapticTimeline = false             // Phase 157
        static let enableAdaptiveBitrateAI = false          // Phase 158
        static let enableOfflineFirstPlayback = false       // Phase 159
        static let enableUniversalPlayerHandoff = false     // Phase 160

        // MARK: - Phase 161–180 Flags (Deep Roadmap VI)

        // Wave 33 — Advanced Monetization & Commerce (161–165)
        static let enableDynamicAdInsertionV2 = false      // Phase 161
        static let enableNFTCollectibles = false            // Phase 162
        static let enableMicropayments = false              // Phase 163
        static let enableAffiliateCommerce = false          // Phase 164
        static let enableCreatorTokens = false              // Phase 165

        // Wave 34 — Creator Economy & Growth (166–170)
        static let enableAIThumbnailGenV2 = false           // Phase 166
        static let enableContentCalendar = false            // Phase 167
        static let enableAudienceInsightsV2 = false         // Phase 168
        static let enableBrandSafety = false                // Phase 169
        static let enableCreatorAcademy = false             // Phase 170

        // Wave 35 — Live & Real-Time Experiences (171–175)
        static let enableUltraLowLatencyLiveV2 = false     // Phase 171
        static let enableLiveCommerce = false               // Phase 172
        static let enableMultiHostLive = false              // Phase 173
        static let enableLiveCaptions = false               // Phase 174
        static let enableLiveAnalyticsDashboard = false    // Phase 175

        // Wave 36 — Platform Scale & Intelligence (176–180)
        static let enableContentGraph = false               // Phase 176
        static let enableCrossPlatformSyndicationV2 = false // Phase 177
        static let enableAdvancedFraudDetection = false    // Phase 178
        static let enableEdgeComputingCDNV2 = false        // Phase 179
        static let enablePlatformTelemetry = false          // Phase 180

        // MARK: - Phase 181–200 Flags (Deep Roadmap VII)

        // Wave 37 — Community Trust & Safety v2 (181–185)
        static let enableCommunityNotes = false             // Phase 181
        static let enableReputationKarma = false            // Phase 182
        static let enableAppealDispute = false              // Phase 183
        static let enableParentalControls = false           // Phase 184
        static let enableAntiHarassment = false             // Phase 185

        // Wave 38 — Advanced Security & Privacy (186–190)
        static let enableEncryptedDMs = false               // Phase 186
        static let enablePrivacyDashboard = false           // Phase 187
        static let enableAdvancedAuth = false               // Phase 188
        static let enableContentProvenance = false          // Phase 189
        static let enableSecurityOpsV2 = false              // Phase 190

        // Wave 39 — Next-Gen AI Features (191–195)
        static let enableChannelMindAGI = false                // AGI decision-making system
        static let enableAICoCreator = false                // Phase 191
        static let enableMultimodalSearchV2 = false         // Phase 192
        static let enableAIHighlights = false               // Phase 193
        static let enableAIModeratorV3 = false              // Phase 194
        static let enableGenerativeVideoFX = false          // Phase 195

        // Wave 40 — Platform Maturity & Future-Proofing (196–200)
        static let enablePluginEcosystemV2 = false          // Phase 196
        static let enableMicroFrontend = false              // Phase 197
        static let enableGlobalCompliance = false           // Phase 198
        static let enableCreatorSuccessAI = false           // Phase 199
        static let enablePlatformMigration = false          // Phase 200

        // MARK: - Phase 201–220 Flags (Deep Roadmap VIII)

        // Wave 41 — Real-Time Intelligence & Predictions (201–205)
        static let enableRealTimeTrendDetector = false      // Phase 201
        static let enablePredictiveEngagement = false       // Phase 202
        static let enableSmartNotification = false          // Phase 203
        static let enableRealTimeABTest = false             // Phase 204
        static let enableAnomalyDetection = false           // Phase 205

        // Wave 42 — Social Features v2 (206–210)
        static let enableStoriesV2 = false                  // Phase 206
        // enableCommunitySpaces already declared in Phase 121  // Phase 207
        static let enableCollaborativePlaylistV2 = false    // Phase 208
        static let enableSocialGraph = false                // Phase 209
        static let enableDirectReactions = false            // Phase 210

        // Wave 43 — Universal Accessibility (211–215)
        static let enableAIAudioDescription = false         // Phase 211
        static let enableCognitiveAccessibility = false     // Phase 212
        static let enableAdaptiveInterface = false          // Phase 213
        static let enableAutoDub = false                    // Phase 214
        static let enableAccessibilityAnalytics = false     // Phase 215

        // Wave 44 — Developer Platform & APIs (216–220)
        static let enablePublicAPIGatewayV2 = false         // Phase 216
        static let enableEmbedSDK = false                   // Phase 217
        static let enableBotFramework = false               // Phase 218
        static let enableDataExportV2 = false               // Phase 219
        static let enableDeveloperAnalytics = false         // Phase 220

        // MARK: - Phase 221–240 Flags (Deep Roadmap IX)

        // Wave 45 — Commerce, Identity & Ownership (221–225)
        static let enableUniversalWallet = false            // Phase 221
        static let enableIdentityGraph = false              // Phase 222
        static let enableCreatorStorefrontsV2 = false       // Phase 223
        static let enableRightsLedger = false               // Phase 224
        static let enableCommerceAttribution = false        // Phase 225

        // Wave 46 — Autonomous Creator Operating System (226–230)
        static let enableCreatorOpsCopilot = false          // Phase 226
        static let enableAutonomousChannelManager = false   // Phase 227
        static let enableAudienceRelationship = false       // Phase 228
        static let enableCreatorNetwork = false             // Phase 229
        static let enableCreatorBusinessIntelligence = false // Phase 230

        // Wave 47 — Interactive Media & Participation Layer (231–235)
        static let enableInteractiveStorytelling = false    // Phase 231
        static let enableViewerMissions = false             // Phase 232
        static let enableCommunityEconomy = false           // Phase 233
        static let enableInteractiveOverlayMarketplace = false // Phase 234
        static let enableParticipationGraph = false         // Phase 235

        // Wave 48 — Platform Intelligence, Governance & Durability (236–240)
        static let enableAlgorithmControls = false          // Phase 236
        static let enableAuthenticityGraph = false          // Phase 237
        static let enablePlatformSimulation = false         // Phase 238
        static let enableRegulatoryAutomation = false       // Phase 239
        static let enableSelfHealingRuntime = false         // Phase 240

        // MARK: - Phase 241–260 Flags (Deep Roadmap X — ProfileView Deep Integration)

        // Wave 49 — Profile Identity & Personalization (241–245)
        static let enableProfileThemes = false               // Phase 241
        static let enableProfileAudioIdentity = false        // Phase 242
        static let enableProfileBadges = false               // Phase 243
        static let enableProfileSocialLinks = false          // Phase 244
        static let enableProfileSmartSharing = false         // Phase 245

        // Wave 50 — Profile Content & Discovery (246–250)
        static let enableProfileHighlights = false           // Phase 246
        static let enableProfileAnalytics = false            // Phase 247
        static let enableProfileDiscovery = false            // Phase 248
        static let enableProfileLiveStatus = false           // Phase 249
        static let enableProfileMembershipShowcase = false   // Phase 250

        // Wave 51 — Profile Engagement & Community (251–255)
        static let enableProfileActivityFeed = false         // Phase 251
        static let enableProfileMilestones = false           // Phase 252
        static let enableProfileCommunityHub = false         // Phase 253
        static let enableProfileMerch = false                // Phase 254
        static let enableProfileOnboarding = false           // Phase 255

        // Wave 52 — Profile Intelligence & Performance (256–260)
        static let enableProfilePrivacy = false              // Phase 256
        static let enableProfileOffline = false              // Phase 257
        static let enableProfileSync = false                 // Phase 258
        static let enableProfileAccessibility = false        // Phase 259
        static let enableProfilePerformance = false          // Phase 260

        // Wave 53: Home Feed UX & Layout (261–265)
        static let enableFeedLayoutEngine = false             // Phase 261
        static let enableFeedSectionManager = false           // Phase 262
        static let enableFeedPagination = false               // Phase 263
        static let enableFeedSkeleton = false                 // Phase 264
        static let enableFeedErrorState = false               // Phase 265

        // Wave 54: Feed Discovery & Curation (266–270)
        static let enableFeedRanking = false                  // Phase 266
        static let enableFeedCategory = false                 // Phase 267
        static let enableFeedCreatorMix = false               // Phase 268
        static let enableFeedTimeAware = false                // Phase 269
        static let enableFeedSerendipity = false              // Phase 270

        // Wave 55: Feed Engagement & Interaction (271–275)
        static let enableFeedQuickActions = false             // Phase 271
        static let enableFeedPreview = false                  // Phase 272
        static let enableFeedWatchHistory = false             // Phase 273
        static let enableFeedSocialSignals = false            // Phase 274
        static let enableFeedNotificationBadge = false        // Phase 275

        // Wave 56: Feed Performance & Intelligence (276–280)
        static let enableFeedCaching = false                  // Phase 276
        static let enableFeedABTesting = false                // Phase 277
        static let enableFeedAnalytics = false                // Phase 278
        static let enableFeedAccessibility = false            // Phase 279
        static let enableFeedPerformance = false              // Phase 280

        // Wave 57: Search UX & Autocomplete (281–285)
        static let enableSearchBarIntelligence = false        // Phase 281
        static let enableAutocompleteV3 = false               // Phase 282
        static let enableSearchHistoryV2 = false              // Phase 283
        static let enableSearchFiltersV3 = false              // Phase 284
        static let enableSearchVoiceVisual = false            // Phase 285

        // Wave 58: Search Ranking & Relevance (286–290)
        static let enableSearchRelevanceEngine = false        // Phase 286
        static let enableSearchPersonalization = false        // Phase 287
        static let enableSearchFreshness = false              // Phase 288
        static let enableSearchEntity = false                 // Phase 289
        static let enableSearchQuality = false                // Phase 290

        // Wave 59: Search Result Presentation (291–295)
        static let enableSearchResultCardsV2 = false          // Phase 291
        static let enableSearchRelated = false                // Phase 292
        static let enableSearchCategoryTabs = false           // Phase 293
        static let enableSearchDeepLinks = false              // Phase 294
        static let enableSearchEmptyState = false             // Phase 295

        // Wave 60: Search Intelligence & Performance (296–300)
        static let enableSearchAIAgentV4 = false              // Phase 296
        static let enableSearchIndexingPipeline = false       // Phase 297
        static let enableSearchAnalyticsV2 = false            // Phase 298
        static let enableSearchAccessibility = false           // Phase 299
        static let enableSearchPerformance = false            // Phase 300

        // Wave 61: Studio Analytics Deep Dive (301–305)
        static let enableStudioRealTimeAnalytics = false      // Phase 301
        static let enableStudioRevenueAnalytics = false       // Phase 302
        static let enableStudioAudienceAnalytics = false      // Phase 303
        static let enableStudioContentAnalytics = false       // Phase 304
        static let enableStudioCompetitiveAnalytics = false   // Phase 305

        // Wave 62: Studio Content Management (306–310)
        static let enableStudioBulkOperationsV2 = false       // Phase 306
        static let enableStudioContentCalendarV2 = false      // Phase 307
        static let enableStudioContentTemplates = false        // Phase 308
        static let enableStudioCollaboration = false           // Phase 309
        static let enableStudioContentArchive = false          // Phase 310

        // Wave 63: Studio Revenue & Growth (311–315)
        static let enableStudioMonetizationDashboard = false   // Phase 311
        static let enableStudioSponsorship = false              // Phase 312
        static let enableStudioGrowthExperiments = false       // Phase 313
        static let enableStudioSEOOptimizer = false            // Phase 314
        static let enableStudioCrossPlatformPublisher = false  // Phase 315

        // Wave 64: Studio Intelligence & Automation (316–320)
        static let enableStudioAICopilotV2 = false             // Phase 316
        static let enableStudioAutomationV2 = false             // Phase 317
        static let enableStudioSmartAlerts = false              // Phase 318
        static let enableStudioDataExport = false               // Phase 319
        static let enableStudioPerformanceDashboard = false    // Phase 320

        // Wave 65: Live Production & Setup (321–325)
        static let enableLiveSetupWizard = false               // Phase 321
        static let enableLiveMultiCam = false                   // Phase 322
        static let enableLiveSchedulerV2 = false               // Phase 323
        static let enableLiveHealthMonitor = false              // Phase 324
        static let enableLiveBackupRecovery = false             // Phase 325

        // Wave 66: Live Engagement & Interaction (326–330)
        static let enableLiveChatIntelligenceV2 = false        // Phase 326
        static let enableLivePollsV2 = false                    // Phase 327
        static let enableLiveReactionsV2 = false               // Phase 328
        static let enableLiveRaidHost = false                   // Phase 329
        static let enableLiveGuestCoStream = false              // Phase 330

        // Wave 67: Live Monetization & Commerce (331–335)
        static let enableLiveSuperChatV2 = false               // Phase 331
        static let enableLiveTippingV2 = false                  // Phase 332
        static let enableLiveShoppingV2 = false                 // Phase 333
        static let enableLiveSubscriptionsV2 = false            // Phase 334
        static let enableLiveSponsorship = false                // Phase 335

        // Wave 68: Live Community & Performance (336–340)
        static let enableLiveClipHighlight = false              // Phase 336
        static let enableLiveReplayVOD = false                  // Phase 337
        static let enableLiveModerationV2 = false               // Phase 338
        static let enableLiveAccessibility = false              // Phase 339
        static let enableLivePerformance = false                // Phase 340

        // Wave 69: Security Deep Dive (341–345)
        static let enableAuthSecurityHardening = false          // Phase 341
        static let enableContentSecurityV2 = false              // Phase 342
        static let enableAPISecurityGateway = false             // Phase 343
        static let enablePrivacyEngineeringV2 = false           // Phase 344
        static let enableIncidentResponse = false               // Phase 345

        // Wave 70: Compliance & Governance (346–350)
        static let enableGDPRCCPAAutomation = false             // Phase 346
        static let enableCOPPAComplianceV2 = false              // Phase 347
        static let enableModerationGovernance = false            // Phase 348
        static let enableTaxFinancialCompliance = false         // Phase 349
        static let enableTermsEnforcementV2 = false             // Phase 350

        // Wave 71: Performance Engineering (351–355)
        static let enableAppStartupOptimization = false         // Phase 351
        static let enableMemoryOptimization = false              // Phase 352
        static let enableNetworkOptimizationV2 = false           // Phase 353
        static let enableDatabaseOptimizationV2 = false          // Phase 354
        static let enableRenderPipeline = false                  // Phase 355

        // Wave 72: Reliability & Observability (356–360)
        static let enableSLOFrameworkV2 = false                  // Phase 356
        static let enableChaosEngineering = false                // Phase 357
        static let enableObservabilityPlatform = false           // Phase 358
        static let enableCapacityAutoscalingV2 = false           // Phase 359
        static let enableDisasterRecoveryV2 = false              // Phase 360
 
        // Wave 73: Ad Demand, Yield & Safety (361–365)
        static let enableAdDemandForecasting = false             // Phase 361
        static let enableAdInventoryQuality = false              // Phase 362
        static let enableYieldStrategy = false                   // Phase 363
        static let enableBrandSafetySuitability = false          // Phase 364
        static let enableCampaignPacing = false                  // Phase 365

        // Wave 74: Creator Revenue Products (366–370)
        static let enableSubscriptionRetention = false           // Phase 366
        static let enableMembershipPerks = false                 // Phase 367
        static let enableSponsorshipMatchmaking = false          // Phase 368
        static let enableAffiliateCommerceOptimization = false   // Phase 369
        static let enableRevenueScenarioPlanner = false          // Phase 370

        // Wave 75: Viewer Commerce & Conversion (371–375)
        static let enablePurchaseIntent = false                  // Phase 371
        static let enableShoppableVideoOrchestration = false     // Phase 372
        static let enableOfferPersonalization = false            // Phase 373
        static let enableCheckoutRecovery = false                // Phase 374
        static let enableGiftEconomy = false                     // Phase 375

        // Wave 76: Revenue Governance & Performance (376–380)
        static let enableRevenueFraudGuard = false               // Phase 376
        static let enableRefundRisk = false                      // Phase 377
        static let enablePayoutReliability = false               // Phase 378
        static let enableRevenueAttributionV2 = false            // Phase 379
        static let enableMonetizationPerformance = false         // Phase 380
        
        // Wave 177: Command Center Real-Time Operations (881–885)
        static let enableIncidentCommand = false                    // Phase 881
        static let enableRevenuePulse = false                       // Phase 882
        static let enableUserActivityHeatmap = false                // Phase 883
        static let enableContentPipelineMonitor = false             // Phase 884
        static let enableAIFleetDashboard = false                   // Phase 885

        // Wave 178: Command Center Intelligence & Automation (886–890)
        static let enablePredictiveAlerts = false                   // Phase 886
        static let enableAutoModerationDecision = false             // Phase 887
        static let enableSmartBriefing = false                      // Phase 888
        static let enableCCWorkflowAutomation = false               // Phase 889
        static let enableCrossDepartmentIntel = false               // Phase 890

        // Wave 179: Command Center Analytics & Reporting (891–895)
        static let enableExecutiveAnalyticsDeepDive = false         // Phase 891
        static let enableCreatorEconomyCommand = false              // Phase 892
        static let enableAdTechCommand = false                      // Phase 893
        static let enableInfraCommand = false                       // Phase 894
        static let enableComplianceGovernance = false               // Phase 895

        // Wave 180: Command Center UX & Mobile Operations (896–900)
        static let enableCCMobileFirst = false                      // Phase 896
        static let enableCCQuickActions = false                     // Phase 897
        static let enableCCNotificationIntel = false                // Phase 898
        static let enableCCMultiWindow = false                      // Phase 899
        static let enableCCVoiceAssistant = false                   // Phase 900

        // MARK: - YouTube Parity Infrastructure Flags
        
        // 🔥 YOUTUBE PARITY: Core infrastructure features
        static let enableElasticsearch = true                    // Full-text search index
        static let enableHLSManifests = true                     // HLS adaptive streaming
        static let enableDASHManifests = false                   // MPEG-DASH streaming
        static let enableAV1Encoding = false                    // AV1 codec (expensive, enable per-region)
        static let enableVP9Encoding = false                    // VP9 codec
        static let enableHTTP3 = true                           // HTTP/3 (QUIC) transport
        static let enableWebRTCLive = false                     // WebRTC ultra-low-latency live
        static let enableClickHouseAnalytics = false            // Columnar OLAP analytics
        static let enableGraphQLFederation = false              // GraphQL API gateway
        static let enableEdgePersonalization = false            // CDN edge functions
        static let enableUnifiedAPIClient = true                // Centralized API client
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