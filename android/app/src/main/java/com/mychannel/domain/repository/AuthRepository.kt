package com.mychannel.domain.repository

import com.mychannel.domain.model.User
import kotlinx.coroutines.flow.Flow

/**
 * Repository for authentication and the current user's profile (REQ-2.x).
 */
interface AuthRepository {

    fun observeAuthState(): Flow<User?>

    val currentUserId: String?

    /** Display name of the currently authenticated user, or null. */
    val currentUserDisplayName: String?

    /** Avatar URL of the currently authenticated user, or null. */
    val currentUserAvatarUrl: String?

    suspend fun signInWithEmail(email: String, password: String): Result<User>
    suspend fun register(email: String, password: String): Result<User>
    suspend fun signInWithGoogle(idToken: String): Result<User>
    suspend fun signInAnonymously(): Result<User>
    suspend fun sendPasswordReset(email: String): Result<Unit>
    suspend fun fetchIdToken(forceRefresh: Boolean = false): Result<String>
    suspend fun updateProfile(username: String, bio: String, avatarUrl: String): Result<User>
    fun signOut()
}
