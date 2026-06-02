package com.mychannel.domain.model

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * Unit tests for [NotificationType.fromRaw] parsing of Firestore/FCM type
 * strings (REQ-14.3 notification types).
 */
class NotificationTypeTest {

    @Test
    fun `parses all known notification types case-insensitively`() {
        assertThat(NotificationType.fromRaw("new_subscriber"))
            .isEqualTo(NotificationType.NEW_SUBSCRIBER)
        assertThat(NotificationType.fromRaw("NEW_COMMENT"))
            .isEqualTo(NotificationType.NEW_COMMENT)
        assertThat(NotificationType.fromRaw("live_started"))
            .isEqualTo(NotificationType.LIVE_STARTED)
        assertThat(NotificationType.fromRaw("vs_match_challenge"))
            .isEqualTo(NotificationType.VS_MATCH_CHALLENGE)
        assertThat(NotificationType.fromRaw("vs_match_result"))
            .isEqualTo(NotificationType.VS_MATCH_RESULT)
        assertThat(NotificationType.fromRaw("payout_received"))
            .isEqualTo(NotificationType.PAYOUT_RECEIVED)
    }

    @Test
    fun `parses short aliases`() {
        assertThat(NotificationType.fromRaw("comment"))
            .isEqualTo(NotificationType.NEW_COMMENT)
        assertThat(NotificationType.fromRaw("live"))
            .isEqualTo(NotificationType.LIVE_STARTED)
        assertThat(NotificationType.fromRaw("payout"))
            .isEqualTo(NotificationType.PAYOUT_RECEIVED)
    }

    @Test
    fun `unknown or null defaults to UNKNOWN`() {
        assertThat(NotificationType.fromRaw("something_else"))
            .isEqualTo(NotificationType.UNKNOWN)
        assertThat(NotificationType.fromRaw(null))
            .isEqualTo(NotificationType.UNKNOWN)
    }
}
