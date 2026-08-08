package com.mychannel.viewmodel

import android.content.Context
import android.content.res.Resources
import com.google.common.truth.Truth.assertThat
import com.mychannel.data.remote.GoogleAuthClient
import com.mychannel.domain.model.User
import com.mychannel.domain.repository.AuthRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever

/**
 * Unit tests for [AuthViewModel] (REQ-2.1 – REQ-2.6).
 *
 * Uses a hand-rolled fake [AuthRepository] (no Firebase) and an unconfigured
 * [GoogleAuthClient] (mocked Context whose resource lookups return 0). These
 * tests focus on the ViewModel's validation, state transitions, and auth-state
 * gating logic — the actual Firebase calls are out of scope for unit tests.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AuthViewModelTest {

    private val testDispatcher = StandardTestDispatcher()

    private lateinit var repository: FakeAuthRepository
    private lateinit var googleAuthClient: GoogleAuthClient
    private lateinit var viewModel: AuthViewModel

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        repository = FakeAuthRepository()

        // A Context whose resource lookups resolve to 0 → GoogleAuthClient is
        // "not configured", which is the safe default for unit tests.
        val resources = mock<Resources> {
            on { getIdentifier(any(), any(), any()) } doReturn 0
        }
        val context = mock<Context> {
            on { getResources() } doReturn resources
            on { packageName } doReturn "com.mychannel.test"
        }
        googleAuthClient = GoogleAuthClient(context)
        viewModel = AuthViewModel(repository, googleAuthClient)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `initial auth state resolves to unauthenticated when no user`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        assertThat(viewModel.uiState.value.status).isEqualTo(AuthStatus.Unauthenticated)
    }

    @Test
    fun `sign in with blank fields sets validation error without calling repository`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.signInWithEmail("", "")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.errorMessage).isNotNull()
        assertThat(repository.signInCalls).isEqualTo(0)
    }

    @Test
    fun `sign in with invalid email sets validation error`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.signInWithEmail("not-an-email", "password123")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.errorMessage).isNotNull()
        assertThat(repository.signInCalls).isEqualTo(0)
    }

    @Test
    fun `successful email sign in transitions to authenticated`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        repository.nextUser = User(uid = "u1", username = "creator")

        viewModel.signInWithEmail("user@example.com", "password123")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(repository.signInCalls).isEqualTo(1)
        val status = viewModel.uiState.value.status
        assertThat(status).isInstanceOf(AuthStatus.Authenticated::class.java)
        assertThat((status as AuthStatus.Authenticated).needsProfileSetup).isFalse()
        assertThat(viewModel.uiState.value.isProcessing).isFalse()
    }

    @Test
    fun `authenticated user with blank username needs profile setup`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        repository.emit(User(uid = "u2", username = ""))
        testDispatcher.scheduler.advanceUntilIdle()

        val status = viewModel.uiState.value.status
        assertThat(status).isInstanceOf(AuthStatus.Authenticated::class.java)
        assertThat((status as AuthStatus.Authenticated).needsProfileSetup).isTrue()
    }

    @Test
    fun `anonymous user does not need profile setup`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        repository.emit(User(uid = "guest", username = "", isAnonymous = true))
        testDispatcher.scheduler.advanceUntilIdle()

        val status = viewModel.uiState.value.status
        assertThat(status).isInstanceOf(AuthStatus.Authenticated::class.java)
        assertThat((status as AuthStatus.Authenticated).needsProfileSetup).isFalse()
    }

    @Test
    fun `register with mismatched passwords sets error and skips repository`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.register("user@example.com", "password123", "different")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.errorMessage).isNotNull()
        assertThat(repository.registerCalls).isEqualTo(0)
    }

    @Test
    fun `register with short password sets error`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.register("user@example.com", "123", "123")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.errorMessage).isNotNull()
        assertThat(repository.registerCalls).isEqualTo(0)
    }

    @Test
    fun `failed sign in surfaces error message`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        repository.nextResult = Result.failure(IllegalStateException("Invalid credentials"))

        viewModel.signInWithEmail("user@example.com", "password123")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.errorMessage).isEqualTo("Invalid credentials")
        assertThat(viewModel.uiState.value.isProcessing).isFalse()
    }

    @Test
    fun `reset password with invalid email sets error`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.resetPassword("bad")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.errorMessage).isNotNull()
        assertThat(repository.resetCalls).isEqualTo(0)
    }

    @Test
    fun `reset password success sets info message`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.resetPassword("user@example.com")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(repository.resetCalls).isEqualTo(1)
        assertThat(viewModel.uiState.value.infoMessage).isNotNull()
    }

    @Test
    fun `profile setup with short username sets error`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.completeProfileSetup("ab", "bio", "")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.errorMessage).isNotNull()
        assertThat(repository.updateProfileCalls).isEqualTo(0)
    }

    @Test
    fun `profile setup success clears setup requirement`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        repository.nextUser = User(uid = "u3", username = "newname")

        viewModel.completeProfileSetup("newname", "my bio", "")
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(repository.updateProfileCalls).isEqualTo(1)
        val status = viewModel.uiState.value.status
        assertThat(status).isInstanceOf(AuthStatus.Authenticated::class.java)
        assertThat((status as AuthStatus.Authenticated).needsProfileSetup).isFalse()
    }

    @Test
    fun `sign out returns to unauthenticated`() = runTest {
        testDispatcher.scheduler.advanceUntilIdle()
        repository.emit(User(uid = "u4", username = "creator"))
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.signOut()
        testDispatcher.scheduler.advanceUntilIdle()

        assertThat(viewModel.uiState.value.status).isEqualTo(AuthStatus.Unauthenticated)
    }

    /**
     * Hand-rolled fake repository. Emits auth state through a [MutableStateFlow]
     * and records call counts for verification.
     */
    private class FakeAuthRepository : AuthRepository {
        private val authState = MutableStateFlow<User?>(null)

        var nextUser: User = User(uid = "default", username = "creator")
        var nextResult: Result<User>? = null

        var signInCalls = 0
        var registerCalls = 0
        var resetCalls = 0
        var updateProfileCalls = 0

        fun emit(user: User?) {
            authState.value = user
        }

        override fun observeAuthState(): Flow<User?> = authState

        override val currentUserId: String?
            get() = authState.value?.uid

        override val currentUserDisplayName: String?
            get() = authState.value?.username

        override val currentUserAvatarUrl: String?
            get() = authState.value?.avatarUrl

        override suspend fun signInWithEmail(email: String, password: String): Result<User> {
            signInCalls++
            return resolve()
        }

        override suspend fun register(email: String, password: String): Result<User> {
            registerCalls++
            return resolve()
        }

        override suspend fun signInWithGoogle(idToken: String): Result<User> = resolve()

        override suspend fun signInAnonymously(): Result<User> {
            val result = Result.success(nextUser.copy(isAnonymous = true))
            authState.value = result.getOrNull()
            return result
        }

        override suspend fun sendPasswordReset(email: String): Result<Unit> {
            resetCalls++
            return Result.success(Unit)
        }

        override suspend fun fetchIdToken(forceRefresh: Boolean): Result<String> =
            Result.success("test-token")

        override suspend fun updateProfile(
            username: String,
            bio: String,
            avatarUrl: String
        ): Result<User> {
            updateProfileCalls++
            return Result.success(nextUser.copy(username = username, bio = bio))
        }

        override suspend fun signOut() {
            authState.value = null
        }

        private fun resolve(): Result<User> {
            val result = nextResult ?: Result.success(nextUser)
            result.getOrNull()?.let { authState.value = it }
            return result
        }
    }
}
