package com.mychannel.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.mychannel.ui.screens.auth.LoginScreen
import com.mychannel.ui.screens.auth.RegisterScreen
import com.mychannel.viewmodel.AuthUiState
import com.mychannel.viewmodel.AuthViewModel

/**
 * Auth route definitions (REQ-2.x). Kept separate from the main bottom-nav
 * [Screen] graph so the unauthenticated flow has its own back stack.
 */
sealed class AuthScreen(val route: String) {
    data object Login : AuthScreen("auth/login")
    data object Register : AuthScreen("auth/register")
}

/**
 * Self-contained navigation graph for the unauthenticated flow: Login ⇄
 * Register. Profile setup is handled at the root once a user is authenticated
 * (see [MyChannelNavigation]).
 */
@Composable
fun AuthNavigation(
    state: AuthUiState,
    viewModel: AuthViewModel
) {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = AuthScreen.Login.route
    ) {
        composable(AuthScreen.Login.route) {
            LoginScreen(
                state = state,
                viewModel = viewModel,
                onNavigateToRegister = {
                    viewModel.consumeMessages()
                    navController.navigate(AuthScreen.Register.route)
                }
            )
        }
        composable(AuthScreen.Register.route) {
            RegisterScreen(
                state = state,
                viewModel = viewModel,
                onNavigateBack = {
                    viewModel.consumeMessages()
                    navController.popBackStack()
                }
            )
        }
    }
}
