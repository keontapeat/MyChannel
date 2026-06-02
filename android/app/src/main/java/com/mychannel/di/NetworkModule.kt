package com.mychannel.di

import com.google.firebase.auth.FirebaseAuth
import com.mychannel.BuildConfig
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.CertificatePinner
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

/**
 * Hilt module providing networking dependencies.
 *
 * Security features:
 * - Auth interceptor attaches Firebase ID tokens to every request
 * - Certificate pinning for api.mychannel.live (REQ-19.3)
 * - Logging only in debug builds (REQ-19.1)
 */
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    private const val API_HOST = "api.mychannel.live"
    private const val TIMEOUT_SECONDS = 30L

    /**
     * Auth interceptor that attaches the current Firebase user's ID token
     * as a Bearer token on every outgoing request.
     */
    @Provides
    @Singleton
    fun provideAuthInterceptor(auth: FirebaseAuth): Interceptor = Interceptor { chain ->
        val original = chain.request()
        val user = auth.currentUser
        val request = if (user != null) {
            // Synchronously get the token (OkHttp runs on a background thread)
            val token = runCatching {
                com.google.android.gms.tasks.Tasks.await(user.getIdToken(false))?.token
            }.getOrNull()
            if (token != null) {
                original.newBuilder()
                    .header("Authorization", "Bearer $token")
                    .build()
            } else {
                original
            }
        } else {
            original
        }
        chain.proceed(request)
    }

    /**
     * Certificate pinner for api.mychannel.live.
     * Pins are placeholders — replace with real SHA-256 pins before production.
     * Use: `openssl s_client -connect api.mychannel.live:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64`
     */
    @Provides
    @Singleton
    fun provideCertificatePinner(): CertificatePinner = CertificatePinner.Builder()
        // TODO: Replace with real certificate pins before production release
        // .add(API_HOST, "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
        .build()

    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: Interceptor,
        certificatePinner: CertificatePinner
    ): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .certificatePinner(certificatePinner)
            .connectTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .readTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .writeTimeout(TIMEOUT_SECONDS, TimeUnit.SECONDS)

        if (BuildConfig.DEBUG) {
            val logging = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            builder.addInterceptor(logging)
        }

        return builder.build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(okHttpClient: OkHttpClient): Retrofit = Retrofit.Builder()
        .baseUrl("https://$API_HOST/")
        .client(okHttpClient)
        .addConverterFactory(GsonConverterFactory.create())
        .build()
}
