package com.mychannel

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import com.google.firebase.FirebaseApp
import dagger.hilt.android.HiltAndroidApp
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

    override fun onCreate() {
        super.onCreate()
        // Initialize Firebase
        FirebaseApp.initializeApp(this)
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
