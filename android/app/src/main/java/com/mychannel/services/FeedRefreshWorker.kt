package com.mychannel.services

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.*
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import kotlinx.coroutines.tasks.await
import java.util.concurrent.TimeUnit

/**
 * Periodic background worker that pre-fetches the home feed and subscription
 * updates so content is ready when the user opens the app.
 * Scheduled to run every 15 minutes (minimum WorkManager interval).
 * Mirrors iOS BackgroundFetchService.scheduleAppRefresh().
 */
@HiltWorker
class FeedRefreshWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return Result.success()
        return try {
            refreshSubscriptionFeed(uid)
            refreshTrending()
            Result.success()
        } catch (e: Exception) {
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }

    private suspend fun refreshSubscriptionFeed(uid: String) {
        // Touch subscriptions collection to trigger Firestore cache warm-up
        FirebaseFirestore.getInstance()
            .collection("users").document(uid)
            .collection("subscriptions")
            .limit(30)
            .get()
            .await()
    }

    private suspend fun refreshTrending() {
        FirebaseFirestore.getInstance()
            .collection("videos")
            .whereEqualTo("privacyStatus", "public")
            .orderBy("viewCount", com.google.firebase.firestore.Query.Direction.DESCENDING)
            .limit(20)
            .get()
            .await()
    }

    companion object {
        private const val WORK_TAG = "feed_refresh"

        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = PeriodicWorkRequestBuilder<FeedRefreshWorker>(
                15, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .addTag(WORK_TAG)
                .setBackoffCriteria(BackoffPolicy.LINEAR, 5, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_TAG,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelAllWorkByTag(WORK_TAG)
        }
    }
}
