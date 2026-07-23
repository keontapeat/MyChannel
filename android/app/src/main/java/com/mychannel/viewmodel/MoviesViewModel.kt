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

data class MoviesUiState(
    val isLoading: Boolean = true,
    val featured: Video? = null,
    // Map of genre label → movies in that genre
    val genres: Map<String, List<Video>> = emptyMap(),
    val error: String? = null
)

@HiltViewModel
class MoviesViewModel @Inject constructor(
    private val videoRepository: VideoRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(MoviesUiState())
    val uiState: StateFlow<MoviesUiState> = _uiState.asStateFlow()

    init {
        loadMovies()
    }

    private fun loadMovies() {
        viewModelScope.launch {
            try {
                val movies = videoRepository.fetchMovies(limit = 80)
                val featured = movies.maxByOrNull { it.viewCount }
                val byGenre = movies
                    .groupBy { it.category.ifBlank { "Other" } }
                    .toSortedMap()
                _uiState.update {
                    it.copy(isLoading = false, featured = featured, genres = byGenre)
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }
}
