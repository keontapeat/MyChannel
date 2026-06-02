package com.mychannel.domain.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.Exclude

/**
 * User domain model — mirrors the Firestore `users/{uid}` document.
 *
 * Compliance-relevant fields (`age`, `isKycVerified`, `termsAccepted`, `region`)
 * are read-only hints for client-side UX gating. The authoritative compliance
 * checks are always enforced server-side by Cloud Functions and Firestore Rules.
 */
data class User(
    val uid: String = "",
    val username: String = "",
    val displayName: String = "",
    val email: String = "",
    val avatarUrl: String = "",
    val bio: String = "",
    val subscriberCount: Long = 0L,
    val videoCount: Long = 0L,
    val isVerified: Boolean = false,
    val isPremium: Boolean = false,
    // Compliance hints (server is authoritative)
    val age: Int = 0,
    val isKycVerified: Boolean = false,
    val termsAccepted: Boolean = false,
    val region: String = "",
    val createdAt: Timestamp = Timestamp(0, 0),
    // Transient auth flag — not persisted to Firestore. True for guest sessions
    // signed in via anonymous auth (REQ-2.3), used to skip profile setup.
    @get:Exclude val isAnonymous: Boolean = false
)
