package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import android.app.Activity
import com.google.firebase.firestore.FirebaseFirestore
import com.mychannel.data.billing.BillingManager
import com.mychannel.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

data class PremiumPlan(
    val id: String = "",
    val name: String = "",
    val priceCents: Long = 0L,
    val interval: String = "month", // month, year
    val features: List<String> = emptyList()
)

data class PremiumUiState(
    val isLoading: Boolean = true,
    val isPremium: Boolean = false,
    val currentPlanId: String? = null,
    val expiresAt: Long? = null,
    val plans: List<PremiumPlan> = listOf(
        PremiumPlan("monthly", "MyChannel Premium", 1199, "month", listOf(
            "Ad-free viewing",
            "Background playback",
            "Offline downloads",
            "Exclusive content",
            "Higher quality streaming (4K)",
            "Priority support"
        )),
        PremiumPlan("yearly", "MyChannel Premium (Annual)", 11999, "year", listOf(
            "Everything in monthly",
            "2 months free",
            "Early access to features",
            "Creator analytics boost",
            "Exclusive badges"
        ))
    ),
    val error: String? = null
)

@HiltViewModel
class PremiumViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository,
    private val billingManager: BillingManager
) : ViewModel() {

    private val _uiState = MutableStateFlow(PremiumUiState())
    val uiState: StateFlow<PremiumUiState> = _uiState.asStateFlow()

    init {
        checkPremiumStatus()
        // Mirror billing state into UI
        viewModelScope.launch {
            billingManager.isPremium.collect { premium ->
                _uiState.update { it.copy(isPremium = premium) }
            }
        }
    }

    private fun checkPremiumStatus() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false) }
            return
        }
        viewModelScope.launch {
            runCatching {
                val subDoc = firestore.collection("users").document(userId)
                    .collection("subscriptions").document("premium")
                    .get().await()
                val d = subDoc.data
                if (d != null) {
                    val active = d["active"] as? Boolean ?: false
                    val planId = d["planId"] as? String
                    val expires = when (val ts = d["expiresAt"]) {
                        is com.google.firebase.Timestamp -> ts.toDate().time
                        else -> null
                    }
                    Triple(active, planId, expires)
                } else {
                    Triple(false, null, null)
                }
            }.onSuccess { (isPremium, planId, expires) ->
                _uiState.update { it.copy(isLoading = false, isPremium = isPremium, currentPlanId = planId, expiresAt = expires) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun retry() { checkPremiumStatus() }

    /** Launch Play Billing purchase sheet for a plan. */
    fun subscribe(activity: Activity, planId: String) {
        val sku = if (planId == "yearly") BillingManager.SKU_PREMIUM_ANNUAL
                  else BillingManager.SKU_PREMIUM_MONTHLY
        val product = billingManager.premiumMonthlyProduct()
            .takeIf { planId != "yearly" } ?: billingManager.premiumAnnualProduct()
        product?.let { billingManager.launchPurchaseFlow(activity, it) }
    }
}
