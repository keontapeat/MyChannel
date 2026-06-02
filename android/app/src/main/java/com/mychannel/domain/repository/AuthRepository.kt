package com.mychannel.domain.repository

import com.mychannel.domain.model.User
import kotlinx.coroutines.flow.Flow

/**
 * Repository for authentication and the current user's profile (REQ-2.x).
 *
 * Real-time auth state is exposed via [observeAuthState] (a [Flow] backed by
 * Firebase's auth state listener). One-shot operations are suspend functions
 * and return [Result] so callers can handle failures explicitly.
 */
interface AuthRepository {

    /** Emits the current [User] (or null when signed out) on every auth change. */
    fun observeAuthState(): Flow<User?>

    /** The currently signed-in user's uid, or null if unauthenticated. */
    val currentUserId: String?

    suspend fun signInWithEmail(email: String, password: String): Result<User>

    suspend fun register(email: String, password: String): Result<User>

    suspend fun signInWithGoogle(idToken: String): Result<User>

    suspend fun signInAnonymously(): Result<User>

    suspend fun sendPasswordReset(email: String): Result<Unit>

    /**
     * Returns the current Firebase ID token, refreshing it when [forceRefresh]
     * is true. Implementations also persist the token securely (REQ-19.4).
     */
    suspend fun fetchIdToken(forceRefresh: Boolean = false): Result<String>

    /** Persists profile fields collected during first-time setup (REQ-2.6). */
    suspend fun updateProfile(username: String, bio: String, avatarUrl: String): Result<User>

    fun signOut()
}
