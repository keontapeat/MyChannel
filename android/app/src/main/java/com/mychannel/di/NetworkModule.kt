package com.mychannel.di

import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.auth.FirebaseAuth
import com.google.android.gms.tasks.Tasks
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
 * - App Check interceptor attests requests to custom MyChannel services
 * - Certificate pinning for api.mychannel.live (REQ-19.3)
 * - Logging only in debug builds (REQ-19.1)
 */
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    private const val API_HOST = "api.mychannel.live"
    private const val TIMEOUT_SECONDS = 30L

    /**
     * Attaches Firebase Auth and App Check tokens. OkHttp invokes application
     * interceptors off the main thread, so bounded task waits are safe here.
     */
    @Provides
    @Singleton
    fun provideAuthInterceptor(auth: FirebaseAuth): Interceptor = Interceptor { chain ->
        val requestBuilder = chain.request().newBuilder()
        auth.currentUser?.let { user ->
            val authToken = runCatching {
                Tasks.await(
                    user.getIdToken(false),
                    5,
                    TimeUnit.SECONDS
                ).token
            }.getOrNull()
            if (!authToken.isNullOrBlank()) {
                requestBuilder.header("Authorization", "Bearer $authToken")
            }
        }

        val appCheckToken = runCatching {
            Tasks.await(
                FirebaseAppCheck.getInstance().getAppCheckToken(false),
                5,
                TimeUnit.SECONDS
            ).token
        }.getOrNull()
        if (!appCheckToken.isNullOrBlank()) {
            requestBuilder.header("X-Firebase-AppCheck", appCheckToken)
        }

        chain.proceed(requestBuilder.build())
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
                redactHeader("Authorization")
                redactHeader("X-Firebase-AppCheck")
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

    @Provides
    @Singleton
    fun provideRecommendationApi(retrofit: Retrofit): com.mychannel.data.remote.RecommendationApi =
        retrofit.create(com.mychannel.data.remote.RecommendationApi::class.java)
}
