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
import com.mychannel.R
import com.mychannel.ui.screens.*
import com.mychannel.ui.screens.auth.ProfileSetupScreen
import com.mychannel.ui.screens.upload.StudioScreen
import com.mychannel.ui.screens.upload.UploadScreen
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
            composable(Screen.Home.route) { HomeScreen(navController) }
            composable(Screen.Flicks.route) { FlicksScreen(navController) }
            composable(Screen.Upload.route) { UploadScreen(navController) }
            composable(Screen.Subscriptions.route) { SubscriptionsScreen(navController) }
            composable(Screen.Library.route) { LibraryScreen(navController) }
            composable(STUDIO_ROUTE) { StudioScreen(navController) }
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

val bottomNavItems = listOf(
    Screen.Home,
    Screen.Flicks,
    Screen.Upload,
    Screen.Subscriptions,
    Screen.Library
)

