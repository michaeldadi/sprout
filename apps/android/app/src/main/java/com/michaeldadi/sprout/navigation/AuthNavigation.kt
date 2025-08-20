package com.michaeldadi.sprout.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.michaeldadi.sprout.ui.screens.ForgotPasswordScreen
import com.michaeldadi.sprout.ui.screens.LoginScreen
import com.michaeldadi.sprout.ui.screens.SignUpScreen
import com.michaeldadi.sprout.ui.screens.VerificationScreen

/**
 * Navigation setup for authentication screens
 * Mirrors the iOS navigation structure
 */
@Composable
fun AuthNavigation(
    navController: NavHostController = rememberNavController()
) {
    NavHost(
        navController = navController,
        startDestination = "login"
    ) {
        composable("login") {
            LoginScreen(
                onNavigateToSignUp = {
                    navController.navigate("signup")
                },
                onNavigateToForgotPassword = {
                    navController.navigate("forgot_password")
                }
            )
        }
        
        composable("signup") {
            SignUpScreen(
                onNavigateToLogin = {
                    navController.popBackStack("login", inclusive = false)
                },
                onNavigateToVerification = { email ->
                    navController.navigate("verification/$email")
                }
            )
        }
        
        composable("verification/{email}") { backStackEntry ->
            val email = backStackEntry.arguments?.getString("email") ?: ""
            VerificationScreen(
                email = email,
                onBackPressed = {
                    navController.popBackStack()
                },
                onVerificationComplete = {
                    navController.popBackStack("login", inclusive = false)
                }
            )
        }
        
        composable("forgot_password") {
            ForgotPasswordScreen(
                onBackPressed = {
                    navController.popBackStack("login", inclusive = false)
                }
            )
        }
    }
}