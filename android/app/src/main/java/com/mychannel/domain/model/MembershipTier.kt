package com.mychannel.domain.model

/**
 * A channel membership tier with pricing and perks.
 * priceMonthly is in integer cents — never raw floating-point dollars.
 */
data class MembershipTier(
    val id: String = "",
    val name: String = "",
    val priceMonthly: Long = 499L,  // cents
    val perks: List<String> = emptyList(),
    val memberCount: Int = 0,
    val badgeEmoji: String = "⭐"
)
