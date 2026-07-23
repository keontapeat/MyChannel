package com.mychannel.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.domain.model.EndScreenElement
import com.mychannel.domain.repository.VideoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class EndScreenUiState(
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val thumbnailUrl: String = "",
    val elements: List<EndScreenElement> = emptyList(),
    val selectedElementId: String? = null,
    val error: String? = null
)

@HiltViewModel
class EndScreenViewModel @Inject constructor(
    private val videoRepository: VideoRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(EndScreenUiState())
    val uiState: StateFlow<EndScreenUiState> = _uiState.asStateFlow()

    private var videoId: String = ""
    private var videoDuration: Double = 0.0

    fun loadForVideo(videoId: String) {
        this.videoId = videoId
        _uiState.update { it.copy(isLoading = true) }
        viewModelScope.launch {
            try {
                val video = videoRepository.getVideo(videoId).getOrNull()
                val elements = videoRepository.fetchEndScreenElements(videoId)
                videoDuration = video?.duration?.toDouble() ?: 0.0
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        thumbnailUrl = video?.thumbnailUrl ?: "",
                        elements = elements
                    )
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun addElement(type: String) {
        if (_uiState.value.elements.size >= 4) return
        val startSec = (videoDuration - 20.0).coerceAtLeast(0.0)
        val newElement = EndScreenElement(
            id = java.util.UUID.randomUUID().toString(),
            type = type,
            startSeconds = startSec,
            endSeconds = videoDuration
        )
        _uiState.update { it.copy(elements = it.elements + newElement) }
    }

    fun removeElement(id: String) {
        _uiState.update { it.copy(elements = it.elements.filter { e -> e.id != id }) }
    }

    fun selectElement(id: String?) {
        _uiState.update { it.copy(selectedElementId = if (it.selectedElementId == id) null else id) }
    }

    fun moveElement(id: String, xPct: Float, yPct: Float) {
        _uiState.update {
            it.copy(elements = it.elements.map { e ->
                if (e.id == id) e.copy(xPct = xPct, yPct = yPct) else e
            })
        }
    }

    fun updateElementTitle(id: String, title: String) {
        _uiState.update {
            it.copy(elements = it.elements.map { e ->
                if (e.id == id) e.copy(title = title) else e
            })
        }
    }

    fun updateElementTarget(id: String, target: String) {
        _uiState.update {
            it.copy(elements = it.elements.map { e ->
                if (e.id == id) e.copy(targetId = target) else e
            })
        }
    }

    fun save() {
        _uiState.update { it.copy(isSaving = true) }
        viewModelScope.launch {
            try {
                videoRepository.saveEndScreenElements(videoId, _uiState.value.elements)
                _uiState.update { it.copy(isSaving = false) }
            } catch (e: Exception) {
                _uiState.update { it.copy(isSaving = false, error = e.message) }
            }
        }
    }
}
