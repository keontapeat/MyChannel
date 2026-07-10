package com.mychannel.services.escrow

import com.mychannel.util.MoneyMath

/**
 * Escrow Cloud Function client stub — mirrors iOS MoneyEscrowService.
 * All amounts in integer cents; server is authoritative.
 *
 * @see docs/escrow-cf-schema.md
 */
object EscrowPaymentsClient {

    const val API_BASE =
        "https://us-central1-mychannel-ca26d.cloudfunctions.net/escrow-payments"

    data class CreatePaymentRequest(
        val amountCents: Int,
        val matchId: String,
        val captureMethod: String = "manual"
    )

    data class CreatePaymentResponse(
        val paymentIntentId: String?,
        val clientSecret: String?,
        val error: String? = null
    )

    /**
     * Stub — does not perform network I/O. Wire OkHttp + Firebase ID token for production.
     */
    suspend fun createEscrowPayment(
        idToken: String,
        request: CreatePaymentRequest
    ): CreatePaymentResponse {
        if (idToken.isBlank()) {
            return CreatePaymentResponse(null, null, "Sign in required")
        }
        if (request.amountCents < 100 || request.amountCents > 10_000_000) {
            return CreatePaymentResponse(null, null, "Invalid amount")
        }
        val payout = MoneyMath.winnerPayoutCents(request.amountCents * 2)
        return CreatePaymentResponse(
            paymentIntentId = "pi_stub_${request.matchId.take(12)}",
            clientSecret = "stub_cs_payout_${payout}"
        )
    }
}
