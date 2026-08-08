package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.mychannel.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

data class AdCampaign(
    val id: String = "",
    val title: String = "",
    val type: String = "pre-roll", // pre-roll, mid-roll, post-roll, banner
    val status: String = "draft", // draft, active, paused, completed
    val budgetCents: Long = 0L,
    val spentCents: Long = 0L,
    val impressions: Long = 0L,
    val clicks: Long = 0L,
    val ctr: Double = 0.0,
    val startDate: Long = 0L,
    val endDate: Long = 0L,
    val createdAt: Long = 0L
)

data class MonetizationStats(
    val totalRevenueCents: Long = 0L,
    val adRevenueCents: Long = 0L,
    val membershipRevenueCents: Long = 0L,
    val superThanksRevenueCents: Long = 0L,
    val estimatedPayoutCents: Long = 0L,
    val thisMonthViewCount: Long = 0L,
    val cpm: Double = 0.0
)

data class AdsMonetizationUiState(
    val isLoading: Boolean = true,
    val campaigns: List<AdCampaign> = emptyList(),
    val stats: MonetizationStats = MonetizationStats(),
    val selectedTab: Int = 0, // 0=overview, 1=campaigns, 2=settings
    val error: String? = null
)

/**
 * ViewModel for the Ads & Monetization dashboard (creator-facing).
 * YouTube parity: Shows ad revenue, campaign management, and monetization settings.
 */
@HiltViewModel
class AdsMonetizationViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(AdsMonetizationUiState())
    val uiState: StateFlow<AdsMonetizationUiState> = _uiState.asStateFlow()

    init {
        loadMonetizationData()
    }

    private fun loadMonetizationData() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in required") }
            return
        }
        viewModelScope.launch {
            runCatching {
                val statsDoc = firestore.collection("creators").document(userId)
                    .collection("monetization").document("stats")
                    .get().await()
                val data = statsDoc.data
                val stats = if (data != null) MonetizationStats(
                    totalRevenueCents = (data["totalRevenueCents"] as? Number)?.toLong() ?: 0L,
                    adRevenueCents = (data["adRevenueCents"] as? Number)?.toLong() ?: 0L,
                    membershipRevenueCents = (data["membershipRevenueCents"] as? Number)?.toLong() ?: 0L,
                    superThanksRevenueCents = (data["superThanksRevenueCents"] as? Number)?.toLong() ?: 0L,
                    estimatedPayoutCents = (data["estimatedPayoutCents"] as? Number)?.toLong() ?: 0L,
                    thisMonthViewCount = (data["thisMonthViewCount"] as? Number)?.toLong() ?: 0L,
                    cpm = (data["cpm"] as? Number)?.toDouble() ?: 0.0
                ) else MonetizationStats()

                val campaignsSnap = firestore.collection("creators").document(userId)
                    .collection("adCampaigns")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()
                val campaigns = campaignsSnap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    AdCampaign(
                        id = doc.id,
                        title = d["title"] as? String ?: "",
                        type = d["type"] as? String ?: "pre-roll",
                        status = d["status"] as? String ?: "draft",
                        budgetCents = (d["budgetCents"] as? Number)?.toLong() ?: 0L,
                        spentCents = (d["spentCents"] as? Number)?.toLong() ?: 0L,
                        impressions = (d["impressions"] as? Number)?.toLong() ?: 0L,
                        clicks = (d["clicks"] as? Number)?.toLong() ?: 0L,
                        ctr = (d["ctr"] as? Number)?.toDouble() ?: 0.0,
                        createdAt = when (val ts = d["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            is Long -> ts
                            else -> 0L
                        }
                    )
                }
                Pair(stats, campaigns)
            }.onSuccess { (stats, campaigns) ->
                _uiState.update { it.copy(isLoading = false, stats = stats, campaigns = campaigns) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun selectTab(index: Int) {
        _uiState.update { it.copy(selectedTab = index) }
    }

    fun pauseCampaign(campaignId: String) {
        updateCampaignStatus(campaignId, "paused")
    }

    fun resumeCampaign(campaignId: String) {
        updateCampaignStatus(campaignId, "active")
    }

    private fun updateCampaignStatus(campaignId: String, status: String) {
        val userId = authRepository.currentUserId ?: return
        _uiState.update { state ->
            state.copy(campaigns = state.campaigns.map { c ->
                if (c.id == campaignId) c.copy(status = status) else c
            })
        }
        viewModelScope.launch {
            runCatching {
                firestore.collection("creators").document(userId)
                    .collection("adCampaigns").document(campaignId)
                    .update("status", status).await()
            }
        }
    }

    fun retry() { loadMonetizationData() }
}
