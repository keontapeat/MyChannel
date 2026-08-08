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

data class MarketplaceListing(
    val id: String = "",
    val title: String = "",
    val description: String = "",
    val category: String = "", // editing, thumbnail, music, voiceover, consulting
    val creatorId: String = "",
    val creatorName: String = "",
    val creatorAvatar: String = "",
    val priceCents: Long = 0L,
    val priceType: String = "fixed", // fixed, hourly, custom
    val rating: Double = 0.0,
    val reviewCount: Long = 0L,
    val deliveryDays: Int = 0,
    val imageUrl: String = "",
    val isActive: Boolean = true,
    val createdAt: Long = 0L
)

data class MarketplaceUiState(
    val isLoading: Boolean = true,
    val listings: List<MarketplaceListing> = emptyList(),
    val selectedCategory: String = "All",
    val categories: List<String> = listOf(
        "All", "Editing", "Thumbnails", "Music", "Voiceover",
        "Consulting", "Animation", "Graphics", "SEO", "Scripting"
    ),
    val error: String? = null
)

/**
 * ViewModel for the Creator Marketplace.
 * Allows creators to offer and purchase creative services from each other.
 */
@HiltViewModel
class MarketplaceViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(MarketplaceUiState())
    val uiState: StateFlow<MarketplaceUiState> = _uiState.asStateFlow()

    init {
        loadListings()
    }

    private fun loadListings() {
        viewModelScope.launch {
            runCatching {
                var query = firestore.collection("marketplace")
                    .whereEqualTo("isActive", true)
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)

                val category = _uiState.value.selectedCategory
                if (category != "All") {
                    query = firestore.collection("marketplace")
                        .whereEqualTo("isActive", true)
                        .whereEqualTo("category", category.lowercase())
                        .orderBy("createdAt", Query.Direction.DESCENDING)
                        .limit(50)
                }

                val snap = query.get().await()
                snap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    MarketplaceListing(
                        id = doc.id,
                        title = d["title"] as? String ?: "",
                        description = d["description"] as? String ?: "",
                        category = d["category"] as? String ?: "",
                        creatorId = d["creatorId"] as? String ?: "",
                        creatorName = d["creatorName"] as? String ?: "",
                        creatorAvatar = d["creatorAvatar"] as? String ?: "",
                        priceCents = (d["priceCents"] as? Number)?.toLong() ?: 0L,
                        priceType = d["priceType"] as? String ?: "fixed",
                        rating = (d["rating"] as? Number)?.toDouble() ?: 0.0,
                        reviewCount = (d["reviewCount"] as? Number)?.toLong() ?: 0L,
                        deliveryDays = (d["deliveryDays"] as? Number)?.toInt() ?: 0,
                        imageUrl = d["imageUrl"] as? String ?: "",
                        createdAt = when (val ts = d["createdAt"]) {
                            is com.google.firebase.Timestamp -> ts.toDate().time
                            is Long -> ts
                            else -> 0L
                        }
                    )
                }
            }.onSuccess { listings ->
                _uiState.update { it.copy(isLoading = false, listings = listings) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    fun selectCategory(category: String) {
        _uiState.update { it.copy(selectedCategory = category, isLoading = true) }
        loadListings()
    }

    fun retry() { loadListings() }
}
