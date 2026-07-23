package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.Video
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class TrendingUiState(
    val isLoading: Boolean = true,
    val selectedCategory: TrendingCategory = TrendingCategory.ALL,
    val videos: List<Video> = emptyList(),
    val error: String? = null
)

enum class TrendingCategory(val label: String) {
    ALL("All"),
    GAMING("Gaming"),
    MUSIC("Music"),
    SPORTS("Sports"),
    ENTERTAINMENT("Entertainment"),
    TECH("Tech & Science"),
    NEWS("News"),
    MOVIES("Movies")
}

@HiltViewModel
class TrendingViewModel @Inject constructor(
    private val videoRepository: VideoRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(TrendingUiState())
    val uiState: StateFlow<TrendingUiState> = _uiState.asStateFlow()

    init {
        loadTrending(TrendingCategory.ALL)
    }

    fun selectCategory(category: TrendingCategory) {
        if (_uiState.value.selectedCategory == category) return
        _uiState.update { it.copy(selectedCategory = category, isLoading = true) }
        loadTrending(category)
    }

    private fun loadTrending(category: TrendingCategory) {
        viewModelScope.launch {
            try {
                val videos = videoRepository.fetchTrending(
                    category = if (category == TrendingCategory.ALL) null else category.label,
                    limit = 50
                )
                _uiState.update { it.copy(isLoading = false, videos = videos) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun refresh() {
        _uiState.update { it.copy(isLoading = true) }
        loadTrending(_uiState.value.selectedCategory)
    }
}
