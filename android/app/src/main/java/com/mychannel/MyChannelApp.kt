package com.mychannel

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.google.android.gms.cast.framework.CastContext
import com.google.firebase.FirebaseApp
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory
import com.google.firebase.messaging.FirebaseMessaging
import com.mychannel.domain.repository.AuthRepository
import com.mychannel.domain.repository.NotificationRepository
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

/**
 * Application entry point for MyChannel.
 *
 * Annotated with @HiltAndroidApp to trigger Hilt's code generation and
 * initialize the dependency injection graph.
 *
 * Implements [Configuration.Provider] so WorkManager uses Hilt's
 * [HiltWorkerFactory], enabling `@HiltWorker` workers (e.g.
 * [com.mychannel.services.UploadWorker]) to receive injected dependencies
 * (REQ-8.6). The default WorkManager initializer is removed in the manifest so
 * this on-demand configuration is used instead.
 */
@HiltAndroidApp
class MyChannelApp : Application(), Configuration.Provider {

    @Inject
    lateinit var workerFactory: HiltWorkerFactory

    @Inject
    lateinit var authRepository: AuthRepository

    @Inject
    lateinit var notificationRepository: NotificationRepository

    @Inject
    lateinit var firebaseMessaging: FirebaseMessaging

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate() {
        super.onCreate()
        val firebaseApp = FirebaseApp.initializeApp(this) ?: return
        val appCheck = FirebaseAppCheck.getInstance(firebaseApp)
        if (BuildConfig.DEBUG) {
            appCheck.installAppCheckProviderFactory(
                DebugAppCheckProviderFactory.getInstance()
            )
        } else {
            appCheck.installAppCheckProviderFactory(
                PlayIntegrityAppCheckProviderFactory.getInstance()
            )
        }
        startFcmTokenRegistration()

        // Initialize Google Cast SDK
        try {
            CastContext.getSharedInstance(this)
        } catch (e: Exception) {
            // Cast not available on this device (no Play Services)
        }

        // Schedule periodic feed refresh (every 15 min, network-gated)
        com.mychannel.services.FeedRefreshWorker.schedule(this)
    }

    private fun startFcmTokenRegistration() {
        applicationScope.launch {
            authRepository.observeAuthState()
                .filterNotNull()
                .collectLatest {
                    val token = runCatching { firebaseMessaging.token.await() }.getOrNull()
                    if (!token.isNullOrBlank()) {
                        notificationRepository.updateFcmToken(token)
                    }
                }
        }
    }

    /**
     * WorkManager 2.9 exposes configuration via this overridable method (the
     * `Configuration.Provider` interface is Java, so it is a method, not a
     * Kotlin property). Wires in the Hilt worker factory.
     */
    override fun getWorkManagerConfiguration(): Configuration =
        Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()
}
