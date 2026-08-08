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

data class Course(
    val id: String = "",
    val title: String = "",
    val description: String = "",
    val category: String = "",
    val creatorName: String = "",
    val thumbnailUrl: String = "",
    val videoCount: Int = 0,
    val totalMinutes: Int = 0,
    val enrolledCount: Long = 0L,
    val rating: Double = 0.0
)

data class Certificate(
    val id: String = "",
    val title: String = "",
    val courseId: String = "",
    val earnedAt: Long = 0L,
    val verificationId: String = ""
)

data class LearningProgress(
    val totalHours: Double = 0.0,
    val videosCompleted: Int = 0,
    val coursesCompleted: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val certificates: Int = 0,
    val globalRank: Int = 0,
    val points: Long = 0L
)

data class UniversityUiState(
    val isLoading: Boolean = true,
    val progress: LearningProgress = LearningProgress(),
    val featuredCourses: List<Course> = emptyList(),
    val myCourses: List<Course> = emptyList(),
    val certificates: List<Certificate> = emptyList(),
    val selectedTab: Int = 0, // 0=dashboard, 1=courses, 2=certificates
    val error: String? = null
)

@HiltViewModel
class UniversityViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(UniversityUiState())
    val uiState: StateFlow<UniversityUiState> = _uiState.asStateFlow()

    init { loadUniversityData() }

    private fun loadUniversityData() {
        val userId = authRepository.currentUserId
        viewModelScope.launch {
            runCatching {
                val coursesSnap = firestore.collection("university_courses")
                    .orderBy("enrolledCount", Query.Direction.DESCENDING)
                    .limit(20)
                    .get().await()
                val featured = coursesSnap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    Course(
                        id = doc.id,
                        title = d["title"] as? String ?: "",
                        description = d["description"] as? String ?: "",
                        category = d["category"] as? String ?: "",
                        creatorName = d["creatorName"] as? String ?: "",
                        thumbnailUrl = d["thumbnailUrl"] as? String ?: "",
                        videoCount = (d["videoCount"] as? Number)?.toInt() ?: 0,
                        totalMinutes = (d["totalMinutes"] as? Number)?.toInt() ?: 0,
                        enrolledCount = (d["enrolledCount"] as? Number)?.toLong() ?: 0L,
                        rating = (d["rating"] as? Number)?.toDouble() ?: 0.0
                    )
                }

                var progress = LearningProgress()
                var certs = emptyList<Certificate>()
                var myCourses = emptyList<Course>()

                if (userId != null) {
                    val progressDoc = firestore.collection("users").document(userId)
                        .collection("university").document("progress")
                        .get().await()
                    progressDoc.data?.let { d ->
                        progress = LearningProgress(
                            totalHours = (d["totalHours"] as? Number)?.toDouble() ?: 0.0,
                            videosCompleted = (d["videosCompleted"] as? Number)?.toInt() ?: 0,
                            coursesCompleted = (d["coursesCompleted"] as? Number)?.toInt() ?: 0,
                            currentStreak = (d["currentStreak"] as? Number)?.toInt() ?: 0,
                            longestStreak = (d["longestStreak"] as? Number)?.toInt() ?: 0,
                            certificates = (d["certificates"] as? Number)?.toInt() ?: 0,
                            globalRank = (d["globalRank"] as? Number)?.toInt() ?: 0,
                            points = (d["points"] as? Number)?.toLong() ?: 0L
                        )
                    }

                    val certsSnap = firestore.collection("users").document(userId)
                        .collection("university_certificates")
                        .orderBy("earnedAt", Query.Direction.DESCENDING)
                        .get().await()
                    certs = certsSnap.documents.mapNotNull { doc ->
                        val d = doc.data ?: return@mapNotNull null
                        Certificate(
                            id = doc.id,
                            title = d["title"] as? String ?: "",
                            courseId = d["courseId"] as? String ?: "",
                            earnedAt = when (val ts = d["earnedAt"]) {
                                is com.google.firebase.Timestamp -> ts.toDate().time
                                else -> 0L
                            },
                            verificationId = d["verificationId"] as? String ?: ""
                        )
                    }
                }

                Triple(featured, certs, progress)
            }.onSuccess { (featured, certs, progress) ->
                _uiState.update { it.copy(isLoading = false, featuredCourses = featured, certificates = certs, progress = progress) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun selectTab(index: Int) { _uiState.update { it.copy(selectedTab = index) } }
    fun retry() { loadUniversityData() }
}
