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

data class Product(
    val id: String = "",
    val title: String = "",
    val description: String = "",
    val priceCents: Long = 0L,
    val imageUrl: String = "",
    val creatorId: String = "",
    val creatorName: String = "",
    val category: String = "",
    val inStock: Boolean = true,
    val rating: Double = 0.0,
    val reviewCount: Long = 0L
)

data class CartItem(
    val product: Product,
    val quantity: Int = 1
)

data class ShoppingUiState(
    val isLoading: Boolean = true,
    val products: List<Product> = emptyList(),
    val cart: List<CartItem> = emptyList(),
    val selectedTab: Int = 0, // 0=browse, 1=cart
    val error: String? = null
)

/**
 * ViewModel for the Shopping/Commerce feature.
 * YouTube parity: integrated product shelf, creator merch, live shopping.
 */
@HiltViewModel
class ShoppingViewModel @Inject constructor(
    private val firestore: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ShoppingUiState())
    val uiState: StateFlow<ShoppingUiState> = _uiState.asStateFlow()

    init {
        loadProducts()
        loadCart()
    }

    private fun loadProducts() {
        viewModelScope.launch {
            runCatching {
                val snap = firestore.collection("products")
                    .whereEqualTo("active", true)
                    .orderBy("createdAt", Query.Direction.DESCENDING)
                    .limit(50)
                    .get().await()
                snap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    Product(
                        id = doc.id,
                        title = d["title"] as? String ?: "",
                        description = d["description"] as? String ?: "",
                        priceCents = (d["priceCents"] as? Number)?.toLong() ?: 0L,
                        imageUrl = d["imageUrl"] as? String ?: "",
                        creatorId = d["creatorId"] as? String ?: "",
                        creatorName = d["creatorName"] as? String ?: "",
                        category = d["category"] as? String ?: "",
                        inStock = d["inStock"] as? Boolean ?: true,
                        rating = (d["rating"] as? Number)?.toDouble() ?: 0.0,
                        reviewCount = (d["reviewCount"] as? Number)?.toLong() ?: 0L
                    )
                }
            }.onSuccess { products ->
                _uiState.update { it.copy(isLoading = false, products = products) }
            }.onFailure { e ->
                _uiState.update { it.copy(isLoading = false, error = e.message) }
            }
        }
    }

    private fun loadCart() {
        val userId = authRepository.currentUserId ?: return
        viewModelScope.launch {
            runCatching {
                val snap = firestore.collection("users").document(userId)
                    .collection("cart").get().await()
                snap.documents.mapNotNull { doc ->
                    val d = doc.data ?: return@mapNotNull null
                    val productId = d["productId"] as? String ?: return@mapNotNull null
                    val productDoc = firestore.collection("products").document(productId).get().await()
                    val pd = productDoc.data ?: return@mapNotNull null
                    CartItem(
                        product = Product(
                            id = productDoc.id,
                            title = pd["title"] as? String ?: "",
                            priceCents = (pd["priceCents"] as? Number)?.toLong() ?: 0L,
                            imageUrl = pd["imageUrl"] as? String ?: ""
                        ),
                        quantity = (d["quantity"] as? Number)?.toInt() ?: 1
                    )
                }
            }.onSuccess { items ->
                _uiState.update { it.copy(cart = items) }
            }
        }
    }

    fun addToCart(product: Product) {
        val userId = authRepository.currentUserId ?: return
        _uiState.update { state ->
            val existing = state.cart.find { it.product.id == product.id }
            val newCart = if (existing != null) {
                state.cart.map { if (it.product.id == product.id) it.copy(quantity = it.quantity + 1) else it }
            } else {
                state.cart + CartItem(product, 1)
            }
            state.copy(cart = newCart)
        }
        viewModelScope.launch {
            runCatching {
                firestore.collection("users").document(userId)
                    .collection("cart").document(product.id)
                    .set(mapOf(
                        "productId" to product.id,
                        "quantity" to (_uiState.value.cart.find { it.product.id == product.id }?.quantity ?: 1),
                        "addedAt" to com.google.firebase.firestore.FieldValue.serverTimestamp()
                    )).await()
            }
        }
    }

    fun removeFromCart(productId: String) {
        val userId = authRepository.currentUserId ?: return
        _uiState.update { state -> state.copy(cart = state.cart.filter { it.product.id != productId }) }
        viewModelScope.launch {
            runCatching {
                firestore.collection("users").document(userId)
                    .collection("cart").document(productId).delete().await()
            }
        }
    }

    fun selectTab(index: Int) {
        _uiState.update { it.copy(selectedTab = index) }
    }

    fun retry() { loadProducts() }
}
