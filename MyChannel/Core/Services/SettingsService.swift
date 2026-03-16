import Foundation
import Combine

@MainActor
final class SettingsService: ObservableObject {
    static let shared = SettingsService()

    @Published var appSettings = AppSettings()
    @Published var studioSettings = StudioSettings()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let userDefaults = UserDefaults.standard

    private init() {
        loadLocalSettings()
        Task {
            await loadCloudSettingsIfNeeded()
        }
    }

    var currentUserId: String? {
        AuthenticationManager.shared.currentUser?.id
    }

    func refresh() {
        loadLocalSettings()
        Task {
            await loadCloudSettingsIfNeeded()
        }
    }

    func updateAppSettings(_ update: (inout AppSettings) -> Void) {
        update(&appSettings)
        applyDerivedState()
        persistAppSettings()
    }

    func updateStudioSettings(_ update: (inout StudioSettings) -> Void) {
        update(&studioSettings)
        persistStudioSettings()
    }

    func resetAppSettings() {
        appSettings = AppSettings()
        applyDerivedState()
        persistAppSettings()
    }

    func resetStudioSettings() {
        studioSettings = StudioSettings()
        persistStudioSettings()
    }

    func clearWatchHistory() async {
        do {
            try await DatabaseService.shared.clearWatchHistory()
        } catch {
            print("⚠️ Failed to clear watch history: \(error)")
        }
        AppState.shared.watchHistory.removeAll()
    }

    func clearSearchHistory() {
        userDefaults.removeObject(forKey: "recent_searches")
    }

    func recentSearches() -> [String] {
        userDefaults.stringArray(forKey: "recent_searches") ?? []
    }

    func deleteAllDownloads() {
        userDefaults.removeObject(forKey: "downloadedVideos")
    }

    private func loadLocalSettings() {
        if let data = userDefaults.data(forKey: appSettingsKey),
           let decoded = try? decoder.decode(AppSettings.self, from: data) {
            appSettings = decoded
        } else {
            appSettings = AppSettings.migrated(from: userDefaults)
        }

        if let data = userDefaults.data(forKey: studioSettingsKey),
           let decoded = try? decoder.decode(StudioSettings.self, from: data) {
            studioSettings = decoded
        } else {
            studioSettings = StudioSettings.migrated(from: userDefaults)
        }

        applyDerivedState()
    }

    private func loadCloudSettingsIfNeeded() async {
        guard let userId = currentUserId else { return }

        if let cloudApp: AppSettings = try? await DataPersistenceService.shared.loadDualLayer(
            AppSettings.self,
            key: appSettingsKey,
            collectionPath: "userSettings",
            docId: userId
        ) {
            appSettings = cloudApp
        }

        if let cloudStudio: StudioSettings = try? await DataPersistenceService.shared.loadDualLayer(
            StudioSettings.self,
            key: studioSettingsKey,
            collectionPath: "studioSettings",
            docId: userId
        ) {
            studioSettings = cloudStudio
        }

        applyDerivedState()
    }

    private func persistAppSettings() {
        guard let data = try? encoder.encode(appSettings) else { return }
        userDefaults.set(data, forKey: appSettingsKey)
        persistLegacyAppKeys()

        guard let userId = currentUserId else { return }
        let settings = appSettings
        Task {
            do {
                try await DataPersistenceService.shared.saveDualLayer(
                    settings,
                    key: appSettingsKey,
                    collectionPath: "userSettings",
                    docId: userId
                )
            } catch {
                print("⚠️ Failed to sync app settings: \(error)")
            }
        }
    }

    private func persistStudioSettings() {
        guard let data = try? encoder.encode(studioSettings) else { return }
        userDefaults.set(data, forKey: studioSettingsKey)
        persistLegacyStudioKeys()

        guard let userId = currentUserId else { return }
        let settings = studioSettings
        Task {
            do {
                try await DataPersistenceService.shared.saveDualLayer(
                    settings,
                    key: studioSettingsKey,
                    collectionPath: "studioSettings",
                    docId: userId
                )
            } catch {
                print("⚠️ Failed to sync studio settings: \(error)")
            }
        }
    }

    private func applyDerivedState() {
        AppState.shared.autoPlayEnabled = appSettings.playback.autoplay
        AppState.shared.notificationsEnabled = appSettings.notifications.pushEnabled
        AppState.shared.autoPiPEnabled = appSettings.playback.autoPictureInPicture
        AppState.shared.preferredVideoQuality = appSettings.videoQuality.preferredAppStateQuality
    }

    private func persistLegacyAppKeys() {
        userDefaults.set(appSettings.general.language, forKey: "appLanguage")
        userDefaults.set(appSettings.general.country, forKey: "appCountry")
        userDefaults.set(appSettings.general.darkMode, forKey: "darkMode")
        userDefaults.set(appSettings.general.darkMode, forKey: "appearance.darkModeEnabled")
        userDefaults.set(appSettings.playback.autoplay, forKey: "preferences.autoPlayEnabled")
        userDefaults.set(appSettings.notifications.pushEnabled, forKey: "preferences.notificationsEnabled")
        userDefaults.set(appSettings.privacy.personalizedAds, forKey: "preferences.personalizedAdsEnabled")
        userDefaults.set(appSettings.playback.autoPictureInPicture, forKey: "autoPiPEnabled")
        userDefaults.set(appSettings.playback.backgroundPlay, forKey: "backgroundPlayEnabled")
        userDefaults.set(appSettings.videoQuality.wifiQuality.rawValue, forKey: "videoQuality")
        userDefaults.set(appSettings.videoQuality.mobileUsage.rawValue, forKey: "mobileDataUsage")
        userDefaults.set(appSettings.downloads.downloadQuality.rawValue, forKey: "downloadQuality")
        userDefaults.set(appSettings.downloads.smartDownloads, forKey: "nuclear_smart_downloads")
        userDefaults.set(appSettings.downloads.storageLimitGB, forKey: "nuclear_storage_limit")
        userDefaults.set(appSettings.uploads.uploadQuality, forKey: "uploadQuality")
        userDefaults.set(appSettings.uploads.wifiOnly, forKey: "wifiUploadsOnly")
        userDefaults.set(appSettings.chat.showLiveChat, forKey: "showLiveChat")
        userDefaults.set(appSettings.chat.chatNotifications, forKey: "chatNotifications")
        userDefaults.set(appSettings.privacy.privateProfile, forKey: "privateProfile")
        userDefaults.set(appSettings.privacy.showSubscriptions, forKey: "showSubscriptions")
        userDefaults.set(appSettings.privacy.showPlaylists, forKey: "showPlaylists")
        userDefaults.set(appSettings.experimental.aiRecommendations, forKey: "experimentalAI")
        userDefaults.set(appSettings.experimental.experimentalPlayer, forKey: "experimentalPlayer")
    }

    private func persistLegacyStudioKeys() {
        userDefaults.set(studioSettings.notifications.enableNotifications, forKey: "studio_notifications_enabled")
        userDefaults.set(studioSettings.uploadDefaults.defaultVisibility.rawValue, forKey: "studio_default_visibility")
        userDefaults.set(studioSettings.uploadDefaults.defaultQuality, forKey: "studio_upload_quality")
        userDefaults.set(studioSettings.monetization.adsEnabled, forKey: "ads_enabled")
        userDefaults.set(studioSettings.monetization.prerollEnabled, forKey: "preroll_enabled")
        userDefaults.set(studioSettings.monetization.midrollEnabled, forKey: "midroll_enabled")
        userDefaults.set(studioSettings.monetization.postrollEnabled, forKey: "postroll_enabled")
        userDefaults.set(studioSettings.monetization.skippableAds, forKey: "skippable_ads")
        userDefaults.set(studioSettings.monetization.personalizedAds, forKey: "personalized_ads")
    }

    private var appSettingsKey: String {
        if let userId = currentUserId { return "app_settings_\(userId)" }
        return "app_settings_guest"
    }

    private var studioSettingsKey: String {
        if let userId = currentUserId { return "studio_settings_\(userId)" }
        return "studio_settings_guest"
    }
}

struct AppSettings: Codable, Equatable {
    var general = GeneralSettings()
    var notifications = NotificationSettingsPayload()
    var playback = PlaybackSettingsPayload()
    var videoQuality = VideoQualitySettingsPayload()
    var downloads = DownloadSettingsPayload()
    var uploads = UploadSettingsPayload()
    var privacy = PrivacySettingsPayload()
    var experimental = ExperimentalSettingsPayload()
    var chat = ChatSettingsPayload()
    var history = HistorySettingsPayload()
    var connectedApps = ConnectedAppsSettingsPayload()

    static func migrated(from userDefaults: UserDefaults) -> AppSettings {
        var settings = AppSettings()
        settings.general.language = userDefaults.string(forKey: "appLanguage") ?? settings.general.language
        settings.general.country = userDefaults.string(forKey: "appCountry") ?? settings.general.country
        settings.general.darkMode = userDefaults.bool(forKey: "darkMode")
        settings.notifications.pushEnabled = userDefaults.object(forKey: "preferences.notificationsEnabled") as? Bool ?? settings.notifications.pushEnabled
        settings.playback.autoplay = userDefaults.object(forKey: "preferences.autoPlayEnabled") as? Bool ?? settings.playback.autoplay
        settings.playback.autoPictureInPicture = userDefaults.object(forKey: "autoPiPEnabled") as? Bool ?? settings.playback.autoPictureInPicture
        settings.playback.backgroundPlay = userDefaults.object(forKey: "backgroundPlayEnabled") as? Bool ?? settings.playback.backgroundPlay
        settings.privacy.personalizedAds = userDefaults.object(forKey: "preferences.personalizedAdsEnabled") as? Bool ?? settings.privacy.personalizedAds
        settings.privacy.privateProfile = userDefaults.object(forKey: "privateProfile") as? Bool ?? settings.privacy.privateProfile
        settings.privacy.showSubscriptions = userDefaults.object(forKey: "showSubscriptions") as? Bool ?? settings.privacy.showSubscriptions
        settings.privacy.showPlaylists = userDefaults.object(forKey: "showPlaylists") as? Bool ?? settings.privacy.showPlaylists
        settings.experimental.aiRecommendations = userDefaults.object(forKey: "experimentalAI") as? Bool ?? settings.experimental.aiRecommendations
        settings.experimental.experimentalPlayer = userDefaults.object(forKey: "experimentalPlayer") as? Bool ?? settings.experimental.experimentalPlayer
        settings.uploads.uploadQuality = userDefaults.string(forKey: "uploadQuality") ?? settings.uploads.uploadQuality
        settings.uploads.wifiOnly = userDefaults.object(forKey: "wifiUploadsOnly") as? Bool ?? settings.uploads.wifiOnly
        settings.chat.showLiveChat = userDefaults.object(forKey: "showLiveChat") as? Bool ?? settings.chat.showLiveChat
        settings.chat.chatNotifications = userDefaults.object(forKey: "chatNotifications") as? Bool ?? settings.chat.chatNotifications
        settings.videoQuality.wifiQuality = StreamingQualityOption(rawValue: userDefaults.string(forKey: "videoQuality") ?? "Auto") ?? settings.videoQuality.wifiQuality
        settings.videoQuality.mobileUsage = MobileDataPreference(rawValue: userDefaults.string(forKey: "mobileDataUsage") ?? "Auto") ?? settings.videoQuality.mobileUsage
        settings.downloads.downloadQuality = DownloadQualityPreference(rawValue: userDefaults.string(forKey: "downloadQuality") ?? DownloadQualityPreference.high.rawValue) ?? settings.downloads.downloadQuality
        settings.downloads.smartDownloads = userDefaults.object(forKey: "nuclear_smart_downloads") as? Bool ?? settings.downloads.smartDownloads
        settings.downloads.storageLimitGB = userDefaults.object(forKey: "nuclear_storage_limit") as? Double ?? settings.downloads.storageLimitGB
        return settings
    }
}

struct StudioSettings: Codable, Equatable {
    var uploadDefaults = StudioUploadDefaults()
    var notifications = StudioNotificationSettings()
    var privacy = StudioPrivacySettings()
    var connectedAccounts = StudioConnectedAccountsSettings()
    var moderation = StudioModerationSettings()
    var live = StudioLiveSettings()
    var monetization = StudioMonetizationSettings()
    var advanced = StudioAdvancedSettings()

    static func migrated(from userDefaults: UserDefaults) -> StudioSettings {
        var settings = StudioSettings()
        settings.uploadDefaults.defaultQuality = userDefaults.string(forKey: "studio_upload_quality") ?? settings.uploadDefaults.defaultQuality
        settings.uploadDefaults.defaultVisibility = StudioVisibility(rawValue: userDefaults.string(forKey: "studio_default_visibility") ?? StudioVisibility.public.rawValue) ?? settings.uploadDefaults.defaultVisibility
        settings.notifications.enableNotifications = userDefaults.object(forKey: "studio_notifications_enabled") as? Bool ?? settings.notifications.enableNotifications
        settings.monetization.adsEnabled = userDefaults.object(forKey: "ads_enabled") as? Bool ?? settings.monetization.adsEnabled
        settings.monetization.prerollEnabled = userDefaults.object(forKey: "preroll_enabled") as? Bool ?? settings.monetization.prerollEnabled
        settings.monetization.midrollEnabled = userDefaults.object(forKey: "midroll_enabled") as? Bool ?? settings.monetization.midrollEnabled
        settings.monetization.postrollEnabled = userDefaults.object(forKey: "postroll_enabled") as? Bool ?? settings.monetization.postrollEnabled
        settings.monetization.skippableAds = userDefaults.object(forKey: "skippable_ads") as? Bool ?? settings.monetization.skippableAds
        settings.monetization.personalizedAds = userDefaults.object(forKey: "personalized_ads") as? Bool ?? settings.monetization.personalizedAds
        return settings
    }
}

struct GeneralSettings: Codable, Equatable {
    var language = "English"
    var country = "United States"
    var darkMode = false
}

struct NotificationSettingsPayload: Codable, Equatable {
    var pushEnabled = true
    var newVideos = true
    var liveStreams = true
    var comments = true
    var subscriptions = true
    var likes = false
    var mentions = true
    var replies = true
    var watchLaterReminders = true
    var subscriptionReminders = false
    var trending = false
    var recommendations = true
    var quietHoursEnabled = false
    var quietHoursStart = 22
    var quietHoursEnd = 8
    var weekendNotifications = true
    var frequency: NotificationDeliveryFrequency = .immediate
    var digestFrequency: SettingsDigestFrequency = .daily
}

struct PlaybackSettingsPayload: Codable, Equatable {
    var autoplay = true
    var autoPictureInPicture = false
    var backgroundPlay = false
}

struct VideoQualitySettingsPayload: Codable, Equatable {
    var wifiQuality: StreamingQualityOption = .auto
    var mobileUsage: MobileDataPreference = .auto

    var preferredAppStateQuality: VideoQuality {
        switch wifiQuality {
        case .highest, .high:
            return .quality1080p
        case .medium:
            return .quality480p
        case .low:
            return .quality360p
        case .auto:
            return .auto
        }
    }
}

struct DownloadSettingsPayload: Codable, Equatable {
    var downloadQuality: DownloadQualityPreference = .high
    var wifiOnly = true
    var smartDownloads = false
    var storageLimitGB = 10.0
}

struct UploadSettingsPayload: Codable, Equatable {
    var uploadQuality = "1080p"
    var wifiOnly = true
}

struct PrivacySettingsPayload: Codable, Equatable {
    var privateProfile = false
    var showSubscriptions = true
    var showPlaylists = true
    var personalizedAds = true
    var pauseWatchHistory = false
    var pauseSearchHistory = false
}

struct ExperimentalSettingsPayload: Codable, Equatable {
    var aiRecommendations = false
    var experimentalPlayer = false
}

struct ChatSettingsPayload: Codable, Equatable {
    var showLiveChat = true
    var chatNotifications = true
}

struct HistorySettingsPayload: Codable, Equatable {
    var lastDataExportRequest: Date?
}

struct ConnectedAppsSettingsPayload: Codable, Equatable {
    var youtubeConnected = false
    var googleConnected = true
    var instagramConnected = false
    var tiktokConnected = false
}

struct StudioUploadDefaults: Codable, Equatable {
    var defaultQuality = "1080p"
    var defaultVisibility: StudioVisibility = .public
    var addToFeatured = false
    var autoGenerateCaptions = true
    var audienceMadeForKids = false
}

struct StudioNotificationSettings: Codable, Equatable {
    var enableNotifications = true
    var newComments = true
    var newSubscribers = true
    var revenueUpdates = true
    var contentClaims = true
    var livePerformanceAlerts = true
}

struct StudioPrivacySettings: Codable, Equatable {
    var showSubscriberCount = true
    var showVideoStats = true
    var allowComments = true
    var allowEmbedding = true
    var publishToSubscriptionsFeed = true
}

struct StudioConnectedAccountsSettings: Codable, Equatable {
    var instagramConnected = false
    var twitterConnected = false
    var tiktokConnected = false
}

struct StudioModerationSettings: Codable, Equatable {
    var holdPotentiallyInappropriateComments = true
    var holdLinksForReview = true
    var allowClips = true
}

struct StudioLiveSettings: Codable, Equatable {
    var liveChatReplay = true
    var enableAutoCaptions = true
    var clipLiveMoments = true
}

struct StudioMonetizationSettings: Codable, Equatable {
    var adsEnabled = true
    var prerollEnabled = true
    var midrollEnabled = true
    var postrollEnabled = false
    var skippableAds = true
    var personalizedAds = true
}

struct StudioAdvancedSettings: Codable, Equatable {
    var apiAccessEnabled = false
    var webhooksEnabled = false
    var developerConsoleEnabled = false
}

enum NotificationDeliveryFrequency: String, Codable, CaseIterable, CustomStringConvertible {
    case immediate = "Immediate"
    case batched = "Batched"
    case quiet = "Quiet"

    var description: String { rawValue }
}

enum SettingsDigestFrequency: String, Codable, CaseIterable, CustomStringConvertible {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"

    var description: String { rawValue }
}

enum StreamingQualityOption: String, Codable, CaseIterable {
    case auto = "Auto"
    case highest = "1080p"
    case high = "720p"
    case medium = "480p"
    case low = "360p"
}

enum MobileDataPreference: String, Codable, CaseIterable {
    case auto = "Auto"
    case higher = "Higher"
    case saver = "Saver"
}

enum DownloadQualityPreference: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case highest = "Highest"
}

enum StudioVisibility: String, Codable, CaseIterable {
    case `public` = "Public"
    case unlisted = "Unlisted"
    case `private` = "Private"
}
