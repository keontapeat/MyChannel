package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.MembershipTier
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.ChannelRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class MembershipsUiState(
    val isLoading: Boolean = true,
    val tiers: List<com.mychannel.domain.model.MembershipTier> = emptyList(),
    val activeMembershipChannelId: String? = null,  // channel user is currently member of
    val activeTierId: String? = null,
    val error: String? = null
)

@HiltViewModel
class MembershipsViewModel @Inject constructor(
    private val channelRepository: ChannelRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(MembershipsUiState())
    val uiState: StateFlow<MembershipsUiState> = _uiState.asStateFlow()

    fun loadTiersForChannel(channelId: String) {
        _uiState.update { it.copy(isLoading = true) }
        viewModelScope.launch {
            try {
                val tiers = channelRepository.fetchMembershipTiers(channelId)
                val uid = authRepository.currentUserId
                val activeTier = if (uid != null) {
                    channelRepository.fetchActiveMembership(uid, channelId)
                } else null
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        tiers = tiers,
                        activeMembershipChannelId = if (activeTier != null) channelId else null,
                        activeTierId = activeTier
                    )
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    /** 💰 Money note: actual charge happens server-side via Cloud Function — this only initiates the flow. */
    fun joinTier(channelId: String, tierId: String) {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            try {
                channelRepository.joinMembershipTier(uid, channelId, tierId)
                _uiState.update {
                    it.copy(activeMembershipChannelId = channelId, activeTierId = tierId)
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message) }
            }
        }
    }

    fun cancelMembership(channelId: String) {
        val uid = authRepository.currentUserId ?: return
        viewModelScope.launch {
            try {
                channelRepository.cancelMembership(uid, channelId)
                _uiState.update { it.copy(activeMembershipChannelId = null, activeTierId = null) }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message) }
            }
        }
    }
}
