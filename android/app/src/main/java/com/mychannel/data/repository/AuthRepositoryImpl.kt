package com.mychannel.data.repository

import com.google.firebase.messaging.FirebaseMessaging
import com.mychannel.data.local.AuthTokenStore
import com.mychannel.data.remote.FirebaseAuthDataSource
import com.mychannel.domain.model.User
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.NotificationRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import javax.inject.Inject
import javax.inject.Singleton

/**
 * [AuthRepository] backed by [FirebaseAuthDataSource].
 *
 * One-shot operations are wrapped in [runCatching] to surface failures as
 * [Result] without throwing across the domain boundary. On every successful
 * authentication the Firebase ID token is cached in [AuthTokenStore]
 * (EncryptedSharedPreferences / Android Keystore) per REQ-19.4, and cleared on
 * sign-out.
 */
@Singleton
class AuthRepositoryImpl @Inject constructor(
    private val authDataSource: FirebaseAuthDataSource,
    private val tokenStore: AuthTokenStore,
    private val notificationRepository: NotificationRepository,
    private val firebaseMessaging: FirebaseMessaging,
    private val okHttpClient: OkHttpClient
) : AuthRepository {

    override fun observeAuthState(): Flow<User?> = authDataSource.observeAuthState()

    override val currentUserId: String?
        get() = authDataSource.currentUserId

    override val currentUserDisplayName: String?
        get() = authDataSource.currentUserDisplayName

    override val currentUserAvatarUrl: String?
        get() = authDataSource.currentUserAvatarUrl

    override suspend fun signInWithEmail(email: String, password: String): Result<User> =
        runCatching { authDataSource.signInWithEmail(email, password) }
            .onSuccess { cacheIdToken() }

    override suspend fun register(email: String, password: String): Result<User> =
        runCatching { authDataSource.register(email, password) }
            .onSuccess { cacheIdToken() }

    override suspend fun signInWithGoogle(idToken: String): Result<User> =
        runCatching { authDataSource.signInWithGoogle(idToken) }
            .onSuccess { cacheIdToken() }

    override suspend fun signInAnonymously(): Result<User> =
        runCatching { authDataSource.signInAnonymously() }
            .onSuccess { cacheIdToken() }

    override suspend fun sendPasswordReset(email: String): Result<Unit> =
        runCatching { authDataSource.sendPasswordReset(email) }

    override suspend fun fetchIdToken(forceRefresh: Boolean): Result<String> =
        runCatching { authDataSource.fetchIdToken(forceRefresh) }
            .onSuccess { token -> tokenStore.saveIdToken(token) }

    override suspend fun updateProfile(
        username: String,
        bio: String,
        avatarUrl: String
    ): Result<User> = runCatching { authDataSource.updateProfile(username, bio, avatarUrl) }

    override suspend fun signOut() {
        val token = runCatching { firebaseMessaging.token.await() }.getOrNull()
        if (!token.isNullOrBlank()) {
            notificationRepository.unregisterFcmToken(token)
        }
        authDataSource.signOut()
        tokenStore.clear()
    }

    override suspend fun deleteAccount(): Result<Unit> = runCatching {
        withContext(Dispatchers.IO) {
            // Force a fresh ID token so the auth interceptor authorizes the call.
            authDataSource.fetchIdToken(forceRefresh = true)
            val request = Request.Builder()
                .url(DELETE_ACCOUNT_URL)
                .post(ByteArray(0).toRequestBody(null))
                .build()
            okHttpClient.newCall(request).execute().use { response ->
                check(response.isSuccessful) {
                    "Account deletion failed (HTTP ${response.code})."
                }
            }
        }
        // Server removed the Auth user + user doc; clear the local session.
        signOut()
    }

    /** Best-effort token cache; failures here must not fail the sign-in. */
    private suspend fun cacheIdToken() {
        runCatching { authDataSource.fetchIdToken(forceRefresh = false) }
            .onSuccess { token -> tokenStore.saveIdToken(token) }
    }

    private companion object {
        const val DELETE_ACCOUNT_URL =
            "https://us-east1-mychannel-ca26d.cloudfunctions.net/delete_account"
    }
}
