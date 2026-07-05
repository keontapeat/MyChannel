package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.Channel
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.SearchRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SearchUiState(
    val query: String = "",
    val videoResults: List<Video> = emptyList(),
    val channelResults: List<Channel> = emptyList(),
    val searchHistory: List<String> = emptyList(),
    val trendingSearches: List<String> = emptyList(),
    val isSearching: Boolean = false,
    val error: String? = null
) {
    val hasResults: Boolean get() = videoResults.isNotEmpty() || channelResults.isNotEmpty()
    val showSuggestions: Boolean get() = query.isBlank()
}

@OptIn(FlowPreview::class)
@HiltViewModel
class SearchViewModel @Inject constructor(
    private val searchRepository: SearchRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(SearchUiState())
    val uiState: StateFlow<SearchUiState> = _uiState.asStateFlow()

    private val queryFlow = MutableStateFlow("")

    init {
        // Observe local search history
        searchRepository.observeSearchHistory()
            .onEach { history -> _uiState.update { it.copy(searchHistory = history) } }
            .launchIn(viewModelScope)

        // Load trending searches on init
        viewModelScope.launch {
            searchRepository.getTrendingSearches()
                .onSuccess { trending -> _uiState.update { it.copy(trendingSearches = trending) } }
        }

        // Debounced live search
        queryFlow
            .debounce(300)
            .distinctUntilChanged()
            .filter { it.length >= 2 }
            .onEach { query -> performSearch(query) }
            .launchIn(viewModelScope)
    }

    fun onQueryChange(query: String) {
        _uiState.update { it.copy(query = query, error = null) }
        queryFlow.value = query
        if (query.isBlank()) {
            _uiState.update { it.copy(videoResults = emptyList(), channelResults = emptyList()) }
        }
    }

    fun search(query: String) {
        if (query.isBlank()) return
        _uiState.update { it.copy(query = query) }
        viewModelScope.launch {
            searchRepository.addToHistory(query)
            performSearch(query)
        }
    }

    private suspend fun performSearch(query: String) {
        _uiState.update { it.copy(isSearching = true, error = null) }
        val videosResult = searchRepository.searchVideos(query)
        val channelsResult = searchRepository.searchChannels(query)
        _uiState.update {
            it.copy(
                videoResults = videosResult.getOrDefault(emptyList()),
                channelResults = channelsResult.getOrDefault(emptyList()),
                isSearching = false,
                error = videosResult.exceptionOrNull()?.message
            )
        }
    }

    fun removeFromHistory(query: String) {
        viewModelScope.launch { searchRepository.removeFromHistory(query) }
    }

    fun clearHistory() {
        viewModelScope.launch { searchRepository.clearHistory() }
    }
}
