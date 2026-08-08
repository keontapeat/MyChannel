package com.mychannel.domain.model

/**
 * User-facing reasons for reporting content or a channel.
 *
 * Mirrors the iOS `VideoReportReason` (raw values + titles) so both platforms
 * write the same `reason` string into the shared `content_reports` Firestore
 * collection consumed by moderation tooling.
 */
enum class ContentReportReason(val raw: String, val title: String) {
    SPAM("spam", "Spam or Misleading"),
    NUDITY("nudity", "Nudity or Sexual Content"),
    VIOLENCE("violence", "Violence or Dangerous Content"),
    HARASSMENT("harassment", "Harassment or Bullying"),
    HATE("hate", "Hate Speech"),
    MISINFORMATION("misinformation", "False Information"),
    COPYRIGHT("copyright", "Copyright Violation"),
    OTHER("other", "Something Else")
}

/**
 * Canonical content types for a report. Raw values match the iOS
 * `CanonicalContentReportType` so moderation queries are cross-platform.
 */
enum class ContentReportType(val raw: String) {
    VIDEO("video"),
    FLICK("flick"),
    COMMENT("comment"),
    LIVE_STREAM("live_stream"),
    USER("user"),
    CHAT_MESSAGE("chat_message")
}
