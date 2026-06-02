package com.mychannel.data.remote

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.auth.ktx.userProfileChangeRequest
import com.google.firebase.firestore.FirebaseFirestore
import com.mychannel.domain.model.User
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Remote data source for Firebase Authentication and the backing user profile
 * document in Firestore.
 *
 * - Real-time auth state uses [callbackFlow] wrapping Firebase's auth listener.
 * - One-shot reads/writes run on [Dispatchers.IO].
 */
@Singleton
class FirebaseAuthDataSource @Inject constructor(
    private val auth: FirebaseAuth,
    private val firestore: FirebaseFirestore
) {

    val currentUserId: String?
        get() = auth.currentUser?.uid

    /** Emits the current [User] profile (or null) on every auth state change. */
    fun observeAuthState(): Flow<User?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { firebaseAuth ->
            val firebaseUser = firebaseAuth.currentUser
            if (firebaseUser == null) {
                trySend(null)
            } else {
                // Emit a lightweight User immediately; the profile doc is loaded
                // separately by the repository when full data is required.
                trySend(
                    User(
                        uid = firebaseUser.uid,
                        username = firebaseUser.displayName.orEmpty(),
                        displayName = firebaseUser.displayName.orEmpty(),
                        email = firebaseUser.email.orEmpty(),
                        avatarUrl = firebaseUser.photoUrl?.toString().orEmpty(),
                        isAnonymous = firebaseUser.isAnonymous
                    )
                )
            }
        }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }

    suspend fun signInWithEmail(email: String, password: String): User =
        withContext(Dispatchers.IO) {
            val result = auth.signInWithEmailAndPassword(email, password).await()
            loadOrCreateProfile(requireNotNull(result.user).uid)
        }

    suspend fun register(email: String, password: String): User =
        withContext(Dispatchers.IO) {
            val result = auth.createUserWithEmailAndPassword(email, password).await()
            loadOrCreateProfile(requireNotNull(result.user).uid, email = email)
        }

    suspend fun signInWithGoogle(idToken: String): User = withContext(Dispatchers.IO) {
        val credential = GoogleAuthProvider.getCredential(idToken, null)
        val result = auth.signInWithCredential(credential).await()
        loadOrCreateProfile(requireNotNull(result.user).uid)
    }

    suspend fun signInAnonymously(): User = withContext(Dispatchers.IO) {
        val result = auth.signInAnonymously().await()
        User(uid = requireNotNull(result.user).uid, isAnonymous = true)
    }

    suspend fun sendPasswordReset(email: String): Unit = withContext(Dispatchers.IO) {
        auth.sendPasswordResetEmail(email).await()
    }

    /** Returns the current user's Firebase ID token (REQ-19.4). */
    suspend fun fetchIdToken(forceRefresh: Boolean): String = withContext(Dispatchers.IO) {
        val firebaseUser = requireNotNull(auth.currentUser) { "Not authenticated" }
        val result = firebaseUser.getIdToken(forceRefresh).await()
        result.token.orEmpty()
    }

    suspend fun updateProfile(username: String, bio: String, avatarUrl: String): User =
        withContext(Dispatchers.IO) {
            val firebaseUser = requireNotNull(auth.currentUser) { "Not authenticated" }
            firebaseUser.updateProfile(
                userProfileChangeRequest {
                    displayName = username
                    if (avatarUrl.isNotBlank()) photoUri = android.net.Uri.parse(avatarUrl)
                }
            ).await()

            val updates = mapOf(
                "username" to username,
                "displayName" to username,
                "bio" to bio,
                "avatarUrl" to avatarUrl
            )
            firestore.collection(USERS).document(firebaseUser.uid)
                .set(updates, com.google.firebase.firestore.SetOptions.merge())
                .await()

            loadOrCreateProfile(firebaseUser.uid)
        }

    fun signOut() = auth.signOut()

    /** Loads the Firestore user profile, creating a minimal doc if absent. */
    private suspend fun loadOrCreateProfile(uid: String, email: String = ""): User {
        val docRef = firestore.collection(USERS).document(uid)
        val snapshot = docRef.get().await()
        val existing = snapshot.toObject(User::class.java)
        if (existing != null) {
            return existing.copy(uid = uid)
        }
        // First sign-in: create a minimal profile (REQ-2.6 setup completes it later).
        val newUser = User(
            uid = uid,
            email = email.ifBlank { auth.currentUser?.email.orEmpty() }
        )
        docRef.set(newUser).await()
        return newUser
    }

    private companion object {
        const val USERS = "users"
    }
}
