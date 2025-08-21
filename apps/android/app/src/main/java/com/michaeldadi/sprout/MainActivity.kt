package com.michaeldadi.sprout

import android.content.Intent
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
import com.michaeldadi.sprout.services.AppleSignInService
import com.michaeldadi.sprout.services.AuthService
import com.michaeldadi.sprout.ui.theme.SproutTheme
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import io.sentry.Sentry

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    // waiting for view to draw to better represent a captured error with a screenshot
    findViewById<android.view.View>(android.R.id.content).viewTreeObserver.addOnGlobalLayoutListener {
      try {
        throw Exception("This app uses Sentry! :)")
      } catch (e: Exception) {
        Sentry.captureException(e)
      }
    }

        enableEdgeToEdge()
        
        // Handle Apple Sign In callback if this is a redirect
        handleAppleSignInCallback(intent)
        
        setContent {
            SproutTheme {
                SproutApp()
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAppleSignInCallback(intent)
    }
    
    private fun handleAppleSignInCallback(intent: Intent) {
        val data = intent.data
        if (data != null && data.scheme == "com.michaeldadi.sprout" && data.host == "auth" && data.path == "/apple") {
            // Handle Apple Sign In callback in a coroutine since it's suspend
            val appleService = AppleSignInService(this, this)
            lifecycleScope.launch {
                appleService.handleCallback(intent)
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
