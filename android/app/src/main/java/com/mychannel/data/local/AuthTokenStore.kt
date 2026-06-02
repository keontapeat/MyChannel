package com.mychannel.data.local

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Secure persistence for the current Firebase ID token (REQ-19.4).
 *
 * Backed by [EncryptedSharedPreferences] with an Android Keystore master key
 * (AES-256-GCM). The token is hardware-backed where the device supports it and
 * is isolated per-app. This store never logs token values.
 *
 * The Firebase SDK already persists the auth session across restarts; this
 * store keeps an encrypted copy of the ID token available for components that
 * need to attach it to outbound requests (e.g. the OkHttp auth interceptor)
 * without a round-trip to [com.google.firebase.auth.FirebaseAuth].
 */
@Singleton
class AuthTokenStore @Inject constructor(
    @ApplicationContext private val context: Context
) {

    private val prefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        EncryptedSharedPreferences.create(
            context,
            PREFS_FILE_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    /** Persists the Firebase ID token. A blank token clears the stored value. */
    fun saveIdToken(token: String) {
        if (token.isBlank()) {
            clear()
            return
        }
        prefs.edit().putString(KEY_ID_TOKEN, token).apply()
    }

    /** Returns the stored Firebase ID token, or null when none is persisted. */
    fun getIdToken(): String? = prefs.getString(KEY_ID_TOKEN, null)

    /** True when a token is currently persisted. */
    fun hasToken(): Boolean = prefs.contains(KEY_ID_TOKEN)

    /** Removes any stored token (called on sign-out). */
    fun clear() {
        prefs.edit().remove(KEY_ID_TOKEN).apply()
    }

    private companion object {
        const val PREFS_FILE_NAME = "mychannel_auth_secure_prefs"
        const val KEY_ID_TOKEN = "firebase_id_token"
    }
}
