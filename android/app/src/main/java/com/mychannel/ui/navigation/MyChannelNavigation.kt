package com.mychannel.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.NavType
import androidx.navigation.navArgument
import com.mychannel.R
import com.mychannel.ui.screens.*
import com.mychannel.ui.screens.auth.ProfileSetupScreen
import com.mychannel.ui.screens.upload.StudioScreen
import com.mychannel.ui.screens.upload.UploadScreen
import com.mychannel.ui.screens.SettingsScreen
import com.mychannel.viewmodel.AuthStatus
import com.mychannel.viewmodel.AuthViewModel

/**
 * Root navigation host (REQ-2.5).
 *
 * Observes [AuthViewModel] and gates the app on auth state:
 * - [AuthStatus.Loading] → splash-style progress while the persisted Firebase
 *   session resolves on cold start.
 * - [AuthStatus.Unauthenticated] → the auth flow ([AuthNavigation]).
 * - [AuthStatus.Authenticated] with `needsProfileSetup` → first-time
 *   [ProfileSetupScreen] (REQ-2.6).
 * - [AuthStatus.Authenticated] otherwise → the main bottom-nav app.
 */
@Composable
fun MyChannelNavigation(
    authViewModel: AuthViewModel = hiltViewModel()
) {
    val authState by authViewModel.uiState.collectAsStateWithLifecycle()

    when (val status = authState.status) {
        is AuthStatus.Loading -> {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        }

        is AuthStatus.Unauthenticated -> {
            AuthNavigation(state = authState, viewModel = authViewModel)
        }

        is AuthStatus.Authenticated -> {
            if (status.needsProfileSetup) {
                ProfileSetupScreen(state = authState, viewModel = authViewModel)
            } else {
                MainNavigation()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MainNavigation() {
    val navController = rememberNavController()
    
    Scaffold(
        bottomBar = {
            NavigationBar {
                val navBackStackEntry by navController.currentBackStackEntryAsState()
                val currentDestination = navBackStackEntry?.destination
                
                bottomNavItems.forEach { screen ->
                    NavigationBarItem(
                        icon = { 
                            Icon(
                                painter = painterResource(id = screen.icon),
                                contentDescription = screen.title
                            )
                        },
                        label = { Text(screen.title) },
                        selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true,
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    )
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Home.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            // Bottom-nav tabs
            composable(Screen.Home.route) { HomeScreen(navController) }
            composable(Screen.Flicks.route) { FlicksScreen(navController) }
            composable(Screen.Upload.route) { UploadScreen(navController) }
            composable(Screen.Subscriptions.route) { SubscriptionsScreen(navController) }
            composable(Screen.Library.route) { LibraryScreen(navController) }

            // Full-screen destinations
            composable(STUDIO_ROUTE) { StudioScreen(navController) }

            composable(
                route = "video/{videoId}",
                arguments = listOf(navArgument("videoId") { type = NavType.StringType })
            ) { backStackEntry ->
                VideoPlayerScreen(
                    videoId = backStackEntry.arguments?.getString("videoId") ?: "",
                    navController = navController
                )
            }

            composable(
                route = "channel/{channelId}",
                arguments = listOf(navArgument("channelId") { type = NavType.StringType })
            ) { backStackEntry ->
                ChannelScreen(
                    channelId = backStackEntry.arguments?.getString("channelId") ?: "",
                    navController = navController
                )
            }

            composable(
                route = "live/{streamId}",
                arguments = listOf(navArgument("streamId") { type = NavType.StringType })
            ) { backStackEntry ->
                LiveStreamScreen(
                    streamId = backStackEntry.arguments?.getString("streamId") ?: "",
                    navController = navController
                )
            }

            composable(SEARCH_ROUTE) { SearchScreen(navController) }

            composable(NOTIFICATIONS_ROUTE) { NotificationsScreen(navController) }

            composable(VS_MATCH_ROUTE) { VSMatchScreen(navController) }

            // Profile / Channel
            composable(PROFILE_ROUTE) { ProfileScreen(navController, channelId = null) }
            composable(
                route = PROFILE_CHANNEL_ROUTE,
                arguments = listOf(navArgument("channelId") { type = NavType.StringType })
            ) { backStackEntry ->
                ProfileScreen(
                    navController = navController,
                    channelId = backStackEntry.arguments?.getString("channelId")
                )
            }

            // Settings
            composable(SETTINGS_ROUTE) { SettingsScreen(navController) }

            // Clips
            composable(CLIPS_ROUTE) { ClipsScreen(navController) }
            composable(
                route = "clips/{videoId}",
                arguments = listOf(navArgument("videoId") { type = NavType.StringType })
            ) { backStackEntry ->
                ClipsScreen(
                    navController = navController,
                    videoId = backStackEntry.arguments?.getString("videoId")
                )
            }

            // Watch Party
            composable(
                route = "watch_party/{partyId}",
                arguments = listOf(navArgument("partyId") { type = NavType.StringType })
            ) { backStackEntry ->
                WatchPartyScreen(
                    partyId = backStackEntry.arguments?.getString("partyId") ?: "",
                    navController = navController
                )
            }

            // Downloads (offline)
            composable(DOWNLOADS_ROUTE) { DownloadsScreen(navController) }

            // History (watch history full page — reuse LibraryScreen with tab param or dedicated)
            composable("history") {
                LibraryScreen(navController = navController)
            }

            // Watch Later
            composable("watch_later") {
                LibraryScreen(navController = navController)
            }

            // Playlists
            composable("playlists") {
                LibraryScreen(navController = navController)
            }

            // Community posts
            composable(COMMUNITY_ROUTE) { CommunityScreen(navController) }

            // Premieres
            composable(PREMIERES_ROUTE) { PremieresScreen(navController) }

            // Super Thanks
            composable(
                route = "super_thanks/{videoId}/{creatorId}/{creatorName}",
                arguments = listOf(
                    navArgument("videoId") { type = NavType.StringType },
                    navArgument("creatorId") { type = NavType.StringType },
                    navArgument("creatorName") { type = NavType.StringType }
                )
            ) { backStackEntry ->
                SuperThanksScreen(
                    videoId = backStackEntry.arguments?.getString("videoId") ?: "",
                    creatorId = backStackEntry.arguments?.getString("creatorId") ?: "",
                    creatorName = backStackEntry.arguments?.getString("creatorName") ?: "",
                    navController = navController
                )
            }

            // Per-video analytics
            composable(
                route = "video_analytics/{videoId}",
                arguments = listOf(navArgument("videoId") { type = NavType.StringType })
            ) { backStackEntry ->
                VideoAnalyticsScreen(
                    videoId = backStackEntry.arguments?.getString("videoId") ?: "",
                    navController = navController
                )
            }

            // Geo block manager (from Settings)
            composable("settings/geo_blocks") {
                GeoBlockManagerScreen(navController = navController)
            }
        }
    }
}

sealed class Screen(val route: String, val title: String, val icon: Int) {
    object Home : Screen("home", "Home", R.drawable.ic_home)
    object Flicks : Screen("flicks", "Flicks", R.drawable.ic_flicks)
    object Upload : Screen("upload", "Upload", R.drawable.ic_upload)
    object Subscriptions : Screen("subscriptions", "Subscriptions", R.drawable.ic_subscriptions)
    object Library : Screen("library", "Library", R.drawable.ic_library)
}

/**
 * Route for the Creator Studio screen (Task 10). It is a full-screen
 * destination reachable from [UploadScreen] rather than a bottom-nav tab, so it
 * is kept as a plain route constant outside the [Screen] bottom-nav hierarchy.
 */
const val STUDIO_ROUTE = "studio"
const val SEARCH_ROUTE = "search"
const val NOTIFICATIONS_ROUTE = "notifications"
const val VS_MATCH_ROUTE = "vs_matches"
const val PROFILE_ROUTE = "profile"
const val PROFILE_CHANNEL_ROUTE = "profile/{channelId}"
const val SETTINGS_ROUTE = "settings"
const val CLIPS_ROUTE = "clips"
const val DOWNLOADS_ROUTE = "downloads"
const val COMMUNITY_ROUTE = "community"
const val PREMIERES_ROUTE = "premieres"

val bottomNavItems = listOf(
    Screen.Home,
    Screen.Flicks,
    Screen.Upload,
    Screen.Subscriptions,
    Screen.Library
)

