package com.mychannel.viewmodel

import android.content.Context
import android.content.Intent
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.mychannel.data.remote.GoogleAuthClient
import com.mychannel.domain.model.User
import com.mychannel.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * The high-level authentication state observed by the navigation root (REQ-2.5).
 */
sealed interface AuthStatus {
    /** Initial state while the persisted Firebase session is being resolved. */
    data object Loading : AuthStatus

    /** No signed-in user — the auth flow should be shown. */
    data object Unauthenticated : AuthStatus

    /**
     * A user is signed in.
     *
     * @param needsProfileSetup true on first sign-in when the profile is
     *   incomplete (blank username), routing the user to ProfileSetup (REQ-2.6).
     */
    data class Authenticated(
        val user: User,
        val needsProfileSetup: Boolean
    ) : AuthStatus
}

/**
 * UI state for the authentication flow.
 *
 * @param status the resolved auth status driving navigation.
 * @param isProcessing true while a sign-in / register / reset call is in flight.
 * @param errorMessage a user-facing error to display, or null.
 * @param infoMessage a transient informational message (e.g. reset email sent).
 */
data class AuthUiState(
    val status: AuthStatus = AuthStatus.Loading,
    val isProcessing: Boolean = false,
    val errorMessage: String? = null,
    val infoMessage: String? = null
) {
    val isAuthenticated: Boolean get() = status is AuthStatus.Authenticated
}

/**
 * ViewModel for the authentication flow (REQ-2.1 – REQ-2.6).
 *
 * Observes the Firebase auth state to keep [AuthUiState.status] in sync across
 * app restarts and exposes one-shot operations for email/password, Google,
 * and anonymous sign-in, registration, password reset, profile setup, and
 * sign-out. Google Sign-In uses the Credential Manager API with a legacy
 * GoogleSignInClient fallback.
 */
@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val googleAuthClient: GoogleAuthClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    /** Exposes whether Google Sign-In is configured so the UI can adapt. */
    val isGoogleSignInAvailable: Boolean get() = googleAuthClient.isConfigured

    init {
        observeAuthState()
    }

    /**
     * Keeps [AuthUiState.status] aligned with Firebase's persisted session.
     * Firebase restores the session on cold start, so this also satisfies the
     * "auth state persistence" requirement (REQ-2.5).
     */
    private fun observeAuthState() {
        authRepository.observeAuthState()
            .onEach { user ->
                _uiState.update { current ->
                    val status = if (user == null) {
                        AuthStatus.Unauthenticated
                    } else {
                        AuthStatus.Authenticated(
                            user = user,
                            // Anonymous guests browse without a profile (REQ-2.3);
                            // only real accounts with a blank username need setup.
                            needsProfileSetup = !user.isAnonymous && user.username.isBlank()
                        )
                    }
                    current.copy(status = status)
                }
                // Refresh and securely cache the ID token for signed-in users.
                if (user != null) {
                    authRepository.fetchIdToken(forceRefresh = false)
                }
            }
            .launchIn(viewModelScope)
    }

    fun signInWithEmail(email: String, password: String) {
        val trimmedEmail = email.trim()
        val validationError = validateCredentials(trimmedEmail, password)
        if (validationError != null) {
            setError(validationError)
            return
        }
        runAuthOperation { authRepository.signInWithEmail(trimmedEmail, password) }
    }

    fun register(email: String, password: String, confirmPassword: String) {
        val trimmedEmail = email.trim()
        val validationError = validateRegistration(trimmedEmail, password, confirmPassword)
        if (validationError != null) {
            setError(validationError)
            return
        }
        runAuthOperation { authRepository.register(trimmedEmail, password) }
    }

    /**
     * Google Sign-In via the Credential Manager (REQ-2.2). On failure (no
     * credential, unsupported device), the caller should fall back to the
     * legacy intent flow via [legacyGoogleSignInIntent] / [onLegacyGoogleResult].
     *
     * @param activityContext an Activity context for the credential UI.
     * @param onFallbackRequired invoked when the caller should launch the
     *   legacy GoogleSignInClient intent instead.
     */
    fun signInWithGoogle(activityContext: Context, onFallbackRequired: () -> Unit) {
        if (!googleAuthClient.isConfigured) {
            setError("Google Sign-In is not configured.")
            return
        }
        viewModelScope.launch {
            startProcessing()
            googleAuthClient.getIdTokenViaCredentialManager(activityContext)
                .onSuccess { idToken -> authenticateWithGoogleToken(idToken) }
                .onFailure {
                    // Defer to the legacy GoogleSignInClient intent flow.
                    stopProcessing()
                    onFallbackRequired()
                }
        }
    }

    /** Returns the legacy Google Sign-In intent for the fallback flow. */
    fun legacyGoogleSignInIntent(): Intent = googleAuthClient.legacySignInIntent()

    /** Handles the result of the legacy Google Sign-In intent. */
    fun onLegacyGoogleResult(data: Intent?) {
        viewModelScope.launch {
            startProcessing()
            googleAuthClient.idTokenFromIntent(data)
                .onSuccess { idToken -> authenticateWithGoogleToken(idToken) }
                .onFailure { error ->
                    setError(error.toAuthMessage("Google Sign-In failed. Please try again."))
                }
        }
    }

    private suspend fun authenticateWithGoogleToken(idToken: String) {
        authRepository.signInWithGoogle(idToken)
            .onSuccess { stopProcessing() }
            .onFailure { error ->
                setError(error.toAuthMessage("Google Sign-In failed. Please try again."))
            }
    }

    fun signInAnonymously() {
        runAuthOperation { authRepository.signInAnonymously() }
    }

    fun resetPassword(email: String) {
        val trimmedEmail = email.trim()
        if (!isValidEmail(trimmedEmail)) {
            setError("Enter a valid email address to reset your password.")
            return
        }
        viewModelScope.launch {
            startProcessing()
            authRepository.sendPasswordReset(trimmedEmail)
                .onSuccess {
                    _uiState.update {
                        it.copy(
                            isProcessing = false,
                            errorMessage = null,
                            infoMessage = "Password reset email sent to $trimmedEmail."
                        )
                    }
                }
                .onFailure { error ->
                    setError(error.toAuthMessage("Couldn't send the reset email. Please try again."))
                }
        }
    }

    /** Completes first-time profile setup (REQ-2.6). */
    fun completeProfileSetup(username: String, bio: String, avatarUrl: String) {
        val trimmedUsername = username.trim()
        if (trimmedUsername.length < MIN_USERNAME_LENGTH) {
            setError("Username must be at least $MIN_USERNAME_LENGTH characters.")
            return
        }
        viewModelScope.launch {
            startProcessing()
            authRepository.updateProfile(trimmedUsername, bio.trim(), avatarUrl.trim())
                .onSuccess { user ->
                    _uiState.update {
                        it.copy(
                            isProcessing = false,
                            errorMessage = null,
                            status = AuthStatus.Authenticated(user = user, needsProfileSetup = false)
                        )
                    }
                }
                .onFailure { error ->
                    setError(error.toAuthMessage("Couldn't save your profile. Please try again."))
                }
        }
    }

    fun signOut(onComplete: () -> Unit = {}) {
        viewModelScope.launch {
            authRepository.signOut()
            googleAuthClient.signOutLegacy()
            _uiState.update {
                it.copy(status = AuthStatus.Unauthenticated, errorMessage = null, infoMessage = null)
            }
            onComplete()
        }
    }

    /**
     * Permanently deletes the current account and all associated data (required
     * by the App Store and Google Play). On success the local session is
     * cleared and [onComplete] runs so the caller can route back to the start.
     */
    fun deleteAccount(onComplete: () -> Unit = {}) {
        viewModelScope.launch {
            startProcessing()
            authRepository.deleteAccount()
                .onSuccess {
                    googleAuthClient.signOutLegacy()
                    _uiState.update {
                        it.copy(
                            isProcessing = false,
                            status = AuthStatus.Unauthenticated,
                            errorMessage = null,
                            infoMessage = "Your account has been deleted."
                        )
                    }
                    onComplete()
                }
                .onFailure { error ->
                    setError(error.toAuthMessage("Couldn't delete your account. Please try again."))
                }
        }
    }

    /** Clears any transient error / info message after it has been shown. */
    fun consumeMessages() {
        _uiState.update { it.copy(errorMessage = null, infoMessage = null) }
    }

    private fun runAuthOperation(operation: suspend () -> Result<User>) {
        viewModelScope.launch {
            startProcessing()
            operation()
                .onSuccess { stopProcessing() }
                .onFailure { error ->
                    setError(error.toAuthMessage("Authentication failed. Please try again."))
                }
        }
    }

    private fun startProcessing() {
        _uiState.update { it.copy(isProcessing = true, errorMessage = null, infoMessage = null) }
    }

    private fun stopProcessing() {
        _uiState.update { it.copy(isProcessing = false) }
    }

    private fun setError(message: String) {
        _uiState.update { it.copy(isProcessing = false, errorMessage = message) }
    }

    private fun validateCredentials(email: String, password: String): String? = when {
        email.isBlank() || password.isBlank() -> "Email and password are required."
        !isValidEmail(email) -> "Enter a valid email address."
        else -> null
    }

    private fun validateRegistration(
        email: String,
        password: String,
        confirmPassword: String
    ): String? = when {
        email.isBlank() -> "Email is required."
        !isValidEmail(email) -> "Enter a valid email address."
        password.length < MIN_PASSWORD_LENGTH ->
            "Password must be at least $MIN_PASSWORD_LENGTH characters."
        password != confirmPassword -> "Passwords do not match."
        else -> null
    }

    private fun isValidEmail(email: String): Boolean =
        EMAIL_REGEX.matches(email)

    private fun Throwable.toAuthMessage(fallback: String): String =
        message?.takeIf { it.isNotBlank() } ?: fallback

    private companion object {
        const val MIN_PASSWORD_LENGTH = 6
        const val MIN_USERNAME_LENGTH = 3

        // Pragmatic email pattern (framework-independent so it is unit-testable).
        val EMAIL_REGEX = Regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
    }
}
