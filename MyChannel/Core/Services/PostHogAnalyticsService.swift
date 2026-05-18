#if canImport(PostHog)
import PostHog
#endif
import Foundation

/// PostHog Product Analytics — Session Replay, Funnels, Retention, Feature Flags
/// Tracks every meaningful user action for data-driven product decisions.
@MainActor
final class PostHogAnalyticsService: ObservableObject {
    static let shared = PostHogAnalyticsService()

    private var isConfigured = false

    private init() {}

    func configure(apiKey: String, host: String = "https://us.i.posthog.com") {
        #if canImport(PostHog)
        guard !isConfigured else { return }
        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.sessionReplay = true
        config.sessionReplayConfig.maskAllTextInputs = false
        config.sessionReplayConfig.maskAllImages = false
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        PostHogSDK.shared.setup(config)
        isConfigured = true
        print("✅ [PostHog] Configured.")
        #endif
    }

    func identify(uid: String, properties: [String: Any] = [:]) {
        #if canImport(PostHog)
        PostHogSDK.shared.identify(uid, userProperties: properties)
        #endif
    }

    func track(_ event: String, properties: [String: Any]? = nil) {
        #if canImport(PostHog)
        PostHogSDK.shared.capture(event, properties: properties)
        #endif
    }

    func screen(_ name: String, properties: [String: Any]? = nil) {
        #if canImport(PostHog)
        PostHogSDK.shared.screen(name, properties: properties)
        #endif
    }

    // MARK: - MyChannel-Specific Events

    func trackVideoPlay(videoId: String, title: String, creatorId: String) {
        track("video_play", properties: ["video_id": videoId, "title": title, "creator_id": creatorId])
    }

    func trackVideoUpload(videoId: String, durationSeconds: Int, fileSizeMB: Double) {
        track("video_upload_complete", properties: ["video_id": videoId, "duration_s": durationSeconds, "size_mb": fileSizeMB])
    }

    func trackSubscribe(channelId: String) {
        track("channel_subscribe", properties: ["channel_id": channelId])
    }

    func trackSearch(query: String, resultsCount: Int) {
        track("search", properties: ["query": query, "results": resultsCount])
    }

    func trackPurchase(productId: String, amount: Double) {
        track("purchase", properties: ["product_id": productId, "amount_usd": amount])
    }

    func trackLiveStreamStart(streamId: String) {
        track("live_stream_start", properties: ["stream_id": streamId])
    }

    func reset() {
        #if canImport(PostHog)
        PostHogSDK.shared.reset()
        #endif
    }

    func isFeatureFlagEnabled(_ flag: String) -> Bool {
        #if canImport(PostHog)
        return PostHogSDK.shared.isFeatureEnabled(flag) ?? false
        #else
        return false
        #endif
    }
}
