package com.michaeldadi.sprout

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.michaeldadi.sprout.navigation.AuthNavigation
import com.michaeldadi.sprout.services.AuthService
import com.michaeldadi.sprout.ui.theme.SproutTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            SproutTheme {
                SproutApp()
            }
        }
    }
}

@Composable
fun SproutApp() {
    val authService: AuthService = viewModel()
    val isAuthenticated by authService.isAuthenticated.collectAsState()

    if (isAuthenticated) {
        // Main app content (placeholder for now)
        MainAppContent()
    } else {
        // Authentication flow
        AuthNavigation()
    }
}

@Composable
fun MainAppContent() {
    // Placeholder for the main app content after authentication
    // This would contain your main app screens
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "Welcome to Sprout! 🌱\nYou are now authenticated.",
                style = MaterialTheme.typography.headlineMedium
            )
        }
    }
}
