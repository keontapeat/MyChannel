package com.mychannel

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.mychannel.ui.theme.MyChannelTheme
import com.mychannel.ui.navigation.MyChannelNavigation
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
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

