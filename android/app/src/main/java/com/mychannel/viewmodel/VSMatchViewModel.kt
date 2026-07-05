package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.ChampionshipDivision
import com.mychannel.domain.model.VSMatch
import com.mychannel.domain.repository.VSMatchRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class VSMatchUiState(
    val openMatches: List<VSMatch> = emptyList(),
    val myMatches: List<VSMatch> = emptyList(),
    val isLoading: Boolean = true,
    val isCreating: Boolean = false,
    val successMessage: String? = null,
    val error: String? = null
)

/**
 * MONEY NOTE: wager creation is routed through the Cloud Function callable
 * via [VSMatchRepository.createMatch]. The client never writes money fields
 * directly to Firestore. All amounts are integer cents.
 */
@HiltViewModel
class VSMatchViewModel @Inject constructor(
    private val vsMatchRepository: VSMatchRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(VSMatchUiState())
    val uiState: StateFlow<VSMatchUiState> = _uiState.asStateFlow()

    init {
        vsMatchRepository.observeOpenMatches()
            .onEach { matches -> _uiState.update { it.copy(openMatches = matches, isLoading = false) } }
            .launchIn(viewModelScope)

        vsMatchRepository.observeMyMatches()
            .onEach { matches -> _uiState.update { it.copy(myMatches = matches) } }
            .launchIn(viewModelScope)
    }

    /**
     * Create a VS match. [wagerCents] is integer cents — never floating point.
     * The division is derived from the wager tier; both are sent to the Cloud
     * Function for server-side compliance enforcement.
     *
     * MONEY NOTE: compliance (age 18+, KYC ≥$500, terms, region, daily limit)
     * is enforced server-side by the `createVSMatch` Cloud Function. Do not
     * bypass or stub any of these checks.
     */
    fun createMatch(wagerCents: Long) {
        if (wagerCents < 100L) {
            _uiState.update { it.copy(error = "Minimum wager is $1.00") }
            return
        }
        val division = ChampionshipDivision.fromWagerCents(wagerCents).raw
        _uiState.update { it.copy(isCreating = true, error = null) }
        viewModelScope.launch {
            vsMatchRepository.createMatch(wagerCents, division)
                .onSuccess { matchId ->
                    _uiState.update {
                        it.copy(
                            isCreating = false,
                            successMessage = "Challenge posted! Match ID: $matchId"
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isCreating = false, error = e.message) }
                }
        }
    }

    fun acceptMatch(matchId: String) {
        viewModelScope.launch {
            vsMatchRepository.acceptMatch(matchId)
                .onSuccess { _uiState.update { it.copy(successMessage = "Match accepted!") } }
                .onFailure { e -> _uiState.update { it.copy(error = e.message) } }
        }
    }

    fun consumeMessages() {
        _uiState.update { it.copy(successMessage = null, error = null) }
    }
}
