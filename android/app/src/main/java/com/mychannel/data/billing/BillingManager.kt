package com.mychannel.data.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.*
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

/**
 * Manages Google Play Billing for:
 * - MyChannel Plus subscription (premium_monthly / premium_annual)
 * - Channel membership tiers (membership_tier_1 / membership_tier_2 / membership_tier_3)
 *
 * Mirrors the iOS StoreKitService pattern.
 */
@Singleton
class BillingManager @Inject constructor(
    @ApplicationContext private val context: Context
) : PurchasesUpdatedListener {

    companion object {
        const val SKU_PREMIUM_MONTHLY = "mychannel_premium_monthly"
        const val SKU_PREMIUM_ANNUAL  = "mychannel_premium_annual"
        val MEMBERSHIP_SKUS = listOf("membership_tier_1", "membership_tier_2", "membership_tier_3")
        val ALL_SUBS = listOf(SKU_PREMIUM_MONTHLY, SKU_PREMIUM_ANNUAL) + MEMBERSHIP_SKUS
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _isPremium = MutableStateFlow(false)
    val isPremium: StateFlow<Boolean> = _isPremium.asStateFlow()

    private val _activeMembershipSku = MutableStateFlow<String?>(null)
    val activeMembershipSku: StateFlow<String?> = _activeMembershipSku.asStateFlow()

    private val _products = MutableStateFlow<List<ProductDetails>>(emptyList())
    val products: StateFlow<List<ProductDetails>> = _products.asStateFlow()

    private val billingClient: BillingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases()
        .build()

    init {
        connect()
    }

    // MARK: - Connection

    private fun connect() {
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    scope.launch {
                        queryProducts()
                        queryPurchases()
                    }
                }
            }
            override fun onBillingServiceDisconnected() {
                // Reconnect on next purchase attempt
            }
        })
    }

    // MARK: - Product Details

    private suspend fun queryProducts() {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                ALL_SUBS.map { sku ->
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(sku)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                }
            )
            .build()

        val result = suspendCancellableCoroutine { cont ->
            billingClient.queryProductDetailsAsync(params) { billingResult, productDetailsList ->
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    cont.resume(productDetailsList)
                } else {
                    cont.resume(emptyList())
                }
            }
        }
        _products.value = result
    }

    // MARK: - Active Purchases

    suspend fun queryPurchases() {
        if (!billingClient.isReady) return
        val result = billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        )
        if (result.billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
            processPurchases(result.purchasesList)
        }
    }

    // MARK: - Launch Purchase Flow

    fun launchPurchaseFlow(activity: Activity, productDetails: ProductDetails) {
        val offerToken = productDetails.subscriptionOfferDetails
            ?.firstOrNull()?.offerToken ?: return

        val productDetailsParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(productDetails)
            .setOfferToken(offerToken)
            .build()

        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productDetailsParams))
            .build()

        billingClient.launchBillingFlow(activity, params)
    }

    // MARK: - Purchase Updates

    override fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            scope.launch { processPurchases(purchases) }
        }
    }

    private suspend fun processPurchases(purchases: List<Purchase>) {
        for (purchase in purchases) {
            if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) continue

            // Acknowledge if not yet acknowledged
            if (!purchase.isAcknowledged) {
                val ackParams = AcknowledgePurchaseParams.newBuilder()
                    .setPurchaseToken(purchase.purchaseToken)
                    .build()
                billingClient.acknowledgePurchase(ackParams)
            }

            // Update premium state
            if (purchase.products.any { it == SKU_PREMIUM_MONTHLY || it == SKU_PREMIUM_ANNUAL }) {
                _isPremium.value = true
                syncPremiumToFirestore(true)
            }

            // Update membership state
            purchase.products.firstOrNull { MEMBERSHIP_SKUS.contains(it) }?.let { sku ->
                _activeMembershipSku.value = sku
                syncMembershipToFirestore(sku, purchase.purchaseToken)
            }
        }

        // Clear premium if no active premium subscription
        val hasPremium = purchases.any { p ->
            p.purchaseState == Purchase.PurchaseState.PURCHASED &&
            p.products.any { it == SKU_PREMIUM_MONTHLY || it == SKU_PREMIUM_ANNUAL }
        }
        if (!hasPremium) {
            _isPremium.value = false
        }
    }

    // MARK: - Firestore sync

    private fun syncPremiumToFirestore(isPremium: Boolean) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        FirebaseFirestore.getInstance()
            .collection("users").document(uid)
            .update("isPremium", isPremium)
    }

    private fun syncMembershipToFirestore(sku: String, token: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        FirebaseFirestore.getInstance()
            .collection("memberships").document(uid)
            .set(mapOf("sku" to sku, "token" to token, "platform" to "android"))
    }

    // MARK: - Product lookup helpers

    fun premiumMonthlyProduct() = _products.value.firstOrNull { it.productId == SKU_PREMIUM_MONTHLY }
    fun premiumAnnualProduct()  = _products.value.firstOrNull { it.productId == SKU_PREMIUM_ANNUAL }
    fun membershipProduct(sku: String) = _products.value.firstOrNull { it.productId == sku }
}
