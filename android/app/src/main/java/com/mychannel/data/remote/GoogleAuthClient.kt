package com.mychannel.data.remote

import android.content.Context
import android.content.Intent
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Obtains a Google ID token for Firebase Auth (REQ-2.2).
 *
 * Primary path: the Jetpack [CredentialManager] API with [GetGoogleIdOption].
 * Fallback path: the legacy [GoogleSignInClient] intent flow, used when the
 * Credential Manager has no credential available or the device/Play Services
 * version does not support it.
 *
 * The OAuth web client ID is never hardcoded — it is read from the
 * google-services-generated `default_web_client_id` string resource (or an
 * optional `google_web_client_id` override), resolved by name so the project
 * still compiles before `google-services.json` is added (REQ-19.1).
 */
@Singleton
class GoogleAuthClient @Inject constructor(
    @ApplicationContext private val context: Context
) {

    private val credentialManager: CredentialManager by lazy {
        CredentialManager.create(context)
    }

    /** The OAuth 2.0 web client ID, or empty when not yet configured. */
    val webClientId: String by lazy { resolveWebClientId() }

    /** True when a web client ID is configured and Google Sign-In can run. */
    val isConfigured: Boolean
        get() = webClientId.isNotBlank()

    /**
     * Attempts to obtain a Google ID token via the Credential Manager.
     *
     * @param activityContext an Activity context used to display the credential
     *   selection UI.
     * @return a [Result] wrapping the ID token on success. A failure indicates
     *   the caller should attempt the [GoogleSignInClient] fallback via
     *   [legacySignInIntent] / [idTokenFromIntent].
     */
    suspend fun getIdTokenViaCredentialManager(activityContext: Context): Result<String> = runCatching {
        check(isConfigured) { "Google web client ID is not configured" }

        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(webClientId)
            .setAutoSelectEnabled(false)
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        val response = credentialManager.getCredential(activityContext, request)
        val credential = response.credential

        if (credential is CustomCredential &&
            credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
        ) {
            val googleCredential = GoogleIdTokenCredential.createFrom(credential.data)
            googleCredential.idToken
        } else {
            throw IllegalStateException("Unexpected credential type from Credential Manager")
        }
    }

    /**
     * Builds the legacy [GoogleSignInClient] intent for the fallback flow.
     * The caller launches this via an Activity Result contract and passes the
     * returned data to [idTokenFromIntent].
     */
    fun legacySignInIntent(): Intent = legacyClient().signInIntent

    /** Extracts the ID token from a legacy Google Sign-In result intent. */
    fun idTokenFromIntent(data: Intent?): Result<String> = runCatching {
        val account = GoogleSignIn.getSignedInAccountFromIntent(data).getResult(ApiException::class.java)
        requireNotNull(account.idToken) { "Google Sign-In returned no ID token" }
    }

    /** Signs the legacy client out so the next sign-in re-prompts for account. */
    fun signOutLegacy() {
        runCatching { legacyClient().signOut() }
    }

    private fun legacyClient(): GoogleSignInClient {
        val options = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(webClientId)
            .requestEmail()
            .build()
        return GoogleSignIn.getClient(context, options)
    }

    /**
     * Resolves the web client ID by resource name at runtime. This avoids a
     * compile-time dependency on the google-services-generated resource, which
     * does not exist until `google-services.json` is added to the module.
     */
    private fun resolveWebClientId(): String {
        // Optional developer-provided override.
        val overrideId = context.resources.getIdentifier(
            "google_web_client_id", "string", context.packageName
        )
        if (overrideId != 0) {
            val value = context.getString(overrideId)
            if (value.isNotBlank()) return value
        }
        // google-services-generated value.
        val defaultId = context.resources.getIdentifier(
            "default_web_client_id", "string", context.packageName
        )
        return if (defaultId != 0) context.getString(defaultId) else ""
    }
}
