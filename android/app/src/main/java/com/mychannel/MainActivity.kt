package com.mychannel

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Rational
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.mychannel.ui.PipController
import com.mychannel.ui.theme.MyChannelTheme
import com.mychannel.ui.navigation.MyChannelNavigation
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    /**
     * Auto-enter Picture-in-Picture when the user leaves the app (Home / recents)
     * while a video is playing (Task 5, REQ-5.x). Guarded on API 26+, the PiP
     * system feature, and [PipController.isVideoActive] so it only triggers from
     * the video player. Any failure to enter PiP is non-fatal.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) return
        if (!PipController.isVideoActive || isInPictureInPictureMode) return

        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .build()
        runCatching { enterPictureInPictureMode(params) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install the splash screen before super.onCreate() so it shows on cold start
        // and transitions to postSplashScreenTheme (Theme.MyChannel) once content is ready.
        installSplashScreen()
        super.onCreate(savedInstanceState)
        setContent {
            MyChannelTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MyChannelNavigation()
                }
            }
        }
    }
}

