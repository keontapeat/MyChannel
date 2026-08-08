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

data class WalletTransaction(
    val id: String = "",
    val type: String = "", // deposit, withdrawal, wager, payout, tip, ad_revenue
    val amountCents: Long = 0L,
    val status: String = "completed",
    val description: String = "",
    val createdAt: Long = 0L
)

data class WalletUiState(
    val isLoading: Boolean = true,
    val balanceCents: Long = 0L,
    val pendingPayoutCents: Long = 0L,
    val lifetimeEarningsCents: Long = 0L,
    val transactions: List<WalletTransaction> = emptyList(),
    val error: String? = null
)

/**
 * MONEY NOTE: Wallet balances are read-only on client. All mutations
 * (deposit, withdraw, wager) route through Cloud Functions with
 * server-side compliance (KYC, daily limits, region checks).
 */
@HiltViewModel
class WalletViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(WalletUiState())
    val uiState: StateFlow<WalletUiState> = _uiState.asStateFlow()

    init { loadWallet() }

    private fun loadWallet() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in required") }
            return
        }
        viewModelScope.launch {
            runCatching {
                val walletDoc = firestore.collection("users").document(userId)
                    .collection("wallet").document("balance")
                    .get().await()
                val d = walletDoc.data ?: emptyMap()
                val balance = (d["balanceCents"] as? Number)?.toLong() ?: 0L
                val pending = (d["pendingPayoutCents"] as? Number)?.toLong() ?: 0L
                val lifetime = (d["lifetimeEarningsCents"] as? Number)?.toLong() ?: 0L

                val txSnap = firestore.collection("users").document(userId)
                    .collection("transactions")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()
                val transactions = txSnap.documents.mapNotNull { doc ->
                    val td = doc.data ?: return@mapNotNull null
                    WalletTransaction(
                        id = doc.id,
                        type = td["type"] as? String ?: "",
                        amountCents = (td["amountCents"] as? Number)?.toLong() ?: 0L,
                        status = td["status"] as? String ?: "completed",
                        description = td["description"] as? String ?: "",
                        createdAt = when (val ts = td["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            else -> 0L
                        }
                    )
                }
                Triple(balance, pending to lifetime, transactions)
            }.onSuccess { (balance, pendingLifetime, transactions) ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        balanceCents = balance,
                        pendingPayoutCents = pendingLifetime.first,
                        lifetimeEarningsCents = pendingLifetime.second,
                        transactions = transactions
                    )
                }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun retry() { loadWallet() }
}
