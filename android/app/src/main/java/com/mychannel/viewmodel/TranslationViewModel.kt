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

data class TranslationJob(
    val id: String = "",
    val videoId: String = "",
    val videoTitle: String = "",
    val sourceLanguage: String = "en",
    val targetLanguage: String = "",
    val type: String = "captions", // captions, dubbing, metadata
    val status: String = "pending", // pending, processing, completed, failed
    val progress: Int = 0,
    val createdAt: Long = 0L
)

data class TranslationUiState(
    val isLoading: Boolean = true,
    val jobs: List<TranslationJob> = emptyList(),
    val supportedLanguages: List<String> = listOf(
        "Spanish", "French", "German", "Japanese", "Korean",
        "Portuguese", "Hindi", "Arabic", "Chinese", "Russian",
        "Italian", "Dutch", "Polish", "Turkish", "Vietnamese"
    ),
    val error: String? = null
)

/**
 * ViewModel for Translation & Dubbing management.
 * YouTube parity: multi-language captions, auto-translation, dubbing.
 */
@HiltViewModel
class TranslationViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(TranslationUiState())
    val uiState: StateFlow<TranslationUiState> = _uiState.asStateFlow()

    init {
        loadTranslationJobs()
    }

    private fun loadTranslationJobs() {
        val userId = authRepository.currentUserId ?: run {
            _uiState.update { it.copy(isLoading = false, error = "Sign in required") }
            return
        }
        viewModelScope.launch {
            runCatching {
                val snap = firestore.collection("creators").document(userId)
                    .collection("translations")
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()
                snap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    TranslationJob(
                        id = doc.id,
                        videoId = d["videoId"] as? String ?: "",
                        videoTitle = d["videoTitle"] as? String ?: "",
                        sourceLanguage = d["sourceLanguage"] as? String ?: "en",
                        targetLanguage = d["targetLanguage"] as? String ?: "",
                        type = d["type"] as? String ?: "captions",
                        status = d["status"] as? String ?: "pending",
                        progress = (d["progress"] as? Number)?.toInt() ?: 0,
                        createdAt = when (val ts = d["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            is Long -> ts
                            else -> 0L
                        }
                    )
                }
            }.onSuccess { jobs ->
                _uiState.update { it.copy(isLoading = false, jobs = jobs) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun requestTranslation(videoId: String, videoTitle: String, targetLanguage: String, type: String) {
        val userId = authRepository.currentUserId ?: return
        val newJob = TranslationJob(
            id = "temp_${System.currentTimeMillis()}",
            videoId = videoId,
            videoTitle = videoTitle,
            targetLanguage = targetLanguage,
            type = type,
            status = "pending",
            createdAt = System.currentTimeMillis()
        )
        _uiState.update { it.copy(jobs = listOf(newJob) + it.jobs) }

        viewModelScope.launch {
            runCatching {
                firestore.collection("creators").document(userId)
                    .collection("translations")
                    .add(mapOf(
                        "videoId" to videoId,
                        "videoTitle" to videoTitle,
                        "sourceLanguage" to "en",
                        "targetLanguage" to targetLanguage,
                        "type" to type,
                        "status" to "pending",
                        "progress" to 0,
                        "createdAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                    )).await()
            }.onSuccess {
                loadTranslationJobs()
            }.onFailure { e ->
                _uiState.update { it.copy(error = e.message) }
            }
        }
    }

    fun retry() { loadTranslationJobs() }
}
