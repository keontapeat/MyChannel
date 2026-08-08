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

data class ReferralCode(
    val id: String = "",
    val code: String = "",
    val currentUses: Int = 0,
    val maxUses: Int = 0,
    val referrerBonusCents: Long = 0L,
    val refereeBonusCents: Long = 0L,
    val createdAt: Long = 0L
)

data class ReferralConversion(
    val id: String = "",
    val code: String = "",
    val refereeEmail: String = "",
    val isValid: Boolean = true,
    val createdAt: Long = 0L
)

data class ReferralsUiState(
    val isLoading: Boolean = true,
    val totalEarningsCents: Long = 0L,
    val myCodes: List<ReferralCode> = emptyList(),
    val conversions: List<ReferralConversion> = emptyList(),
    val error: String? = null
)

@HiltViewModel
class ReferralsViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ReferralsUiState())
    val uiState: StateFlow<ReferralsUiState> = _uiState.asStateFlow()

    init { loadReferralData() }

    private fun loadReferralData() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in required") }
            return
        }
        viewModelScope.launch {
            runCatching {
                val codesSnap = firestore.collection("users").document(userId)
                    .collection("referralCodes")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .get().await()
                val codes = codesSnap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    ReferralCode(
                        id = doc.id,
                        code = d["code"] as? String ?: "",
                        currentUses = (d["currentUses"] as? Number)?.toInt() ?: 0,
                        maxUses = (d["maxUses"] as? Number)?.toInt() ?: 0,
                        referrerBonusCents = (d["referrerBonusCents"] as? Number)?.toLong() ?: 500L,
                        refereeBonusCents = (d["refereeBonusCents"] as? Number)?.toLong() ?: 500L,
                        createdAt = when (val ts = d["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            else -> 0L
                        }
                    )
                }

                val conversionsSnap = firestore.collection("users").document(userId)
                    .collection("referralConversions")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(20)
                    .get().await()
                val conversions = conversionsSnap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    ReferralConversion(
                        id = doc.id,
                        code = d["code"] as? String ?: "",
                        refereeEmail = d["refereeEmail"] as? String ?: "",
                        isValid = d["isValid"] as? Boolean ?: true,
                        createdAt = when (val ts = d["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            else -> 0L
                        }
                    )
                }

                val earningsDoc = firestore.collection("users").document(userId)
                    .collection("earnings").document("referrals")
                    .get().await()
                val totalCents = (earningsDoc.data?.get("totalCents") as? Number)?.toLong() ?: 0L

                Triple(codes, conversions, totalCents)
            }.onSuccess { (codes, conversions, totalCents) ->
                _uiState.update { it.copy(isLoading = false, myCodes = codes, conversions = conversions, totalEarningsCents = totalCents) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun shareCode(code: ReferralCode): String = "https://mychannel.live/ref/${code.code}"

    fun retry() { loadReferralData() }
}
