package com.mychannel.data.remote

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.mychannel.domain.model.ContentReportReason
import com.mychannel.domain.model.ContentReportType
import kotlinx.coroutines.tasks.await
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Writes user-initiated moderation actions (content reports + user blocks) to
 * Firestore. This is the Android counterpart of the iOS `ContentReportService`
 * and the block flow in `VideoMoreOptionsSheet`, and it writes the exact same
 * document shapes so moderation tooling is platform-agnostic.
 *
 * Schema (must stay in sync with iOS):
 * - Reports  → `content_reports/{sha256(reporterId␟type␟contentId)}`
 * - Blocks   → `users/{blockerId}/blockedUsers/{blockedUserId}`
 *
 * The deterministic report id makes re-reports idempotent (a user reporting the
 * same content twice updates one doc instead of spamming the queue).
 */
@Singleton
class ModerationDataSource @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val auth: FirebaseAuth
) {

    /** Result of a report submission, mirroring iOS `ContentReportSubmissionResult`. */
    enum class ReportResult { CREATED, EXISTING }

    /**
     * Submits a content report. Requires an authenticated user.
     * @throws IllegalStateException if not signed in.
     * @throws IllegalArgumentException if the target/reason are invalid.
     */
    suspend fun submitReport(
        type: ContentReportType,
        contentId: String,
        contentCreatorId: String,
        reason: ContentReportReason,
        details: String? = null,
        videoId: String? = null
    ): ReportResult {
        val reporterId = auth.currentUser?.uid
            ?: throw IllegalStateException("Sign in to submit a report.")

        val targetId = contentId.trim()
        require(targetId.isNotEmpty() && targetId.length <= 256) { "Invalid content id." }

        // Firestore rules require contentCreatorId to equal the target's stored
        // creatorId/userId. For video reports the client only has channelId, which
        // may differ, so resolve the authoritative value from the video doc.
        val resolvedCreatorId = if (type == ContentReportType.VIDEO) {
            runCatching {
                val doc = firestore.collection(VIDEOS).document(targetId).get().await()
                (doc.getString("creatorId") ?: doc.getString("userId"))?.takeIf { it.isNotBlank() }
            }.getOrNull() ?: contentCreatorId
        } else {
            contentCreatorId
        }

        val reportId = deterministicReportId(reporterId, type.raw, targetId)
        val reportRef = firestore.collection(CONTENT_REPORTS).document(reportId)

        if (reportRef.get().await().exists()) return ReportResult.EXISTING

        val data = mutableMapOf<String, Any>(
            "type" to type.raw,
            "contentId" to targetId,
            "contentCreatorId" to resolvedCreatorId,
            "reporterId" to reporterId,
            "reason" to reason.raw,
            "reasonTitle" to reason.title,
            "status" to "pending",
            "reviewed" to false,
            "createdAt" to FieldValue.serverTimestamp()
        )
        details?.trim()?.take(1000)?.takeIf { it.isNotEmpty() }?.let { data["details"] = it }
        // Required by rules for comment reports (identifies the parent video doc).
        videoId?.trim()?.takeIf { it.isNotEmpty() }?.let { data["videoId"] = it }

        reportRef.set(data).await()
        return ReportResult.CREATED
    }

    /**
     * Blocks a user so their content can be filtered from the reporter's feeds.
     * Writes to the same `users/{uid}/blockedUsers/{blockedId}` path as iOS.
     * @throws IllegalStateException if not signed in.
     */
    suspend fun blockUser(
        blockedUserId: String,
        blockedUserDisplayName: String? = null,
        blockedUserUsername: String? = null
    ) {
        val blockerId = auth.currentUser?.uid
            ?: throw IllegalStateException("Sign in to block a user.")
        require(blockedUserId.isNotBlank()) { "Invalid user id." }
        require(blockedUserId != blockerId) { "You can't block yourself." }

        val data = mutableMapOf<String, Any>(
            "blockerId" to blockerId,
            "blockedUserId" to blockedUserId,
            "reason" to "user_initiated_block",
            "createdAt" to FieldValue.serverTimestamp()
        )
        blockedUserDisplayName?.let { data["blockedUserDisplayName"] = it }
        blockedUserUsername?.let { data["blockedUserUsername"] = it }

        firestore.collection(USERS)
            .document(blockerId)
            .collection(BLOCKED_USERS)
            .document(blockedUserId)
            .set(data)
            .await()
    }

    private fun deterministicReportId(reporterId: String, type: String, contentId: String): String {
        // Matches iOS: SHA-256 of reporterId␟type␟contentId (␟ = US, 0x1F).
        val raw = listOf(reporterId, type, contentId).joinToString(SEPARATOR)
        val digest = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    private companion object {
        const val CONTENT_REPORTS = "content_reports"
        const val VIDEOS = "videos"
        const val USERS = "users"
        const val BLOCKED_USERS = "blockedUsers"
        const val SEPARATOR = "\u001F" // Unit Separator, matches iOS "\u{1F}"
    }
}
