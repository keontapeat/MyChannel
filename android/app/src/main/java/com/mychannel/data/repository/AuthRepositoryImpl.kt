package com.mychannel.data.repository

import com.mychannel.data.local.AuthTokenStore
import com.mychannel.data.remote.FirebaseAuthDataSource
import com.mychannel.domain.model.User
import com.mychannel.domain.repository.AuthRepository
import kotlinx.coroutines.flow.Flow
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
    private val tokenStore: AuthTokenStore
) : AuthRepository {

    override fun observeAuthState(): Flow<User?> = authDataSource.observeAuthState()

    override val currentUserId: String?
        get() = authDataSource.currentUserId

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

    override fun signOut() {
        authDataSource.signOut()
        tokenStore.clear()
    }

    /** Best-effort token cache; failures here must not fail the sign-in. */
    private suspend fun cacheIdToken() {
        runCatching { authDataSource.fetchIdToken(forceRefresh = false) }
            .onSuccess { token -> tokenStore.saveIdToken(token) }
    }
}
