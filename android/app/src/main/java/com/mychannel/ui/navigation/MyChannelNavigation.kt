package com.mychannel.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.mychannel.R
import com.mychannel.ui.screens.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyChannelNavigation() {
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

val bottomNavItems = listOf(
    Screen.Home,
    Screen.Flicks,
    Screen.Upload,
    Screen.Subscriptions,
    Screen.Library
)

