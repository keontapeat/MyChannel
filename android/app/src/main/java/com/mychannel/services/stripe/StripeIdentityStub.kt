package com.mychannel.services.stripe

/**
 * Stripe Identity KYC stub — mirrors iOS VSMatchComplianceService KYC flow.
 * Production: wire Stripe Identity SDK + server session creation.
 *
 * @see docs/android-money-parity.md phase-491
 */
object StripeIdentityStub {

    data class VerificationSession(
        val sessionId: String,
        val clientSecret: String,
        val status: String = "requires_input"
    )

    /**
     * Stub — returns a fake session. Real implementation calls escrow CF
     * with Firebase ID token to create a Stripe Identity VerificationSession.
     */
    suspend fun createVerificationSession(userId: String): Result<VerificationSession> {
        if (userId.isBlank()) {
            return Result.failure(IllegalArgumentException("userId required"))
        }
        return Result.success(
            VerificationSession(
                sessionId = "vs_stub_${userId.take(8)}",
                clientSecret = "stub_secret_not_for_production"
            )
        )
    }

    fun isKYCApproved(status: String?): Boolean = status == "approved"
}
