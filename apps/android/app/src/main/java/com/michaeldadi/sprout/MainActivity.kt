package com.michaeldadi.sprout

import android.content.Intent
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.compose.currentBackStackEntryAsState
import com.michaeldadi.sprout.navigation.AuthNavigation
import com.michaeldadi.sprout.services.AppleSignInService
import com.michaeldadi.sprout.services.AuthService
import com.michaeldadi.sprout.ui.theme.SproutTheme
import com.michaeldadi.sprout.ui.activity.ActivityDetailScreen
import com.michaeldadi.sprout.ui.activity.ActivityFilter
import com.michaeldadi.sprout.ui.activity.ActivityKind
import com.michaeldadi.sprout.ui.activity.ActivityListScreen
import com.michaeldadi.sprout.ui.activity.ActivityLoadState
import com.michaeldadi.sprout.ui.activity.ActivityPeriod
import com.michaeldadi.sprout.ui.activity.ActivityViewModel
import com.michaeldadi.sprout.ui.home.HomeScreen
import com.michaeldadi.sprout.ui.components.SproutAuthenticatedNavigationBar
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.platform.LocalContext
import java.util.Date
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
        val currentUser by authService.currentUser.collectAsState()
        MainAppContent(currentUser)
    } else {
        // Authentication flow
        AuthNavigation()
    }
}

@Composable
fun MainAppContent(currentUser: com.michaeldadi.sprout.models.CognitoUser?) {
    val activityViewModel: ActivityViewModel = viewModel()
    val state by activityViewModel.state.collectAsState()
    LaunchedEffect(currentUser?.idToken) { activityViewModel.bindUser(currentUser) }
    val accountState = activityViewModel.stateFor(currentUser, state)

    val context = LocalContext.current
    val connectivityManager = remember(context) { context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager }
    var offline by remember { mutableStateOf(!connectivityManager.isValidated()) }
    DisposableEffect(connectivityManager) {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { offline = !connectivityManager.isValidated() }
            override fun onLost(network: Network) { offline = !connectivityManager.isValidated() }
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                offline = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            }
        }
        connectivityManager.registerNetworkCallback(NetworkRequest.Builder().build(), callback)
        onDispose { connectivityManager.unregisterNetworkCallback(callback) }
    }

    var query by rememberSaveable { mutableStateOf("") }
    var kindName by rememberSaveable { mutableStateOf(ActivityKind.ALL.name) }
    var periodName by rememberSaveable { mutableStateOf(ActivityPeriod.RECENT.name) }
    val navController = rememberNavController()
    val route = navController.currentBackStackEntryAsState().value?.destination?.route
    val isKeyboardVisible = WindowInsets.ime.getBottom(LocalDensity.current) > 0
    val openActivity = { navController.navigate("activity") { launchSingleTop = true } }
    Scaffold(
        contentWindowInsets = WindowInsets.safeDrawing,
        bottomBar = {
            if (!isKeyboardVisible && (route == "home" || route == "activity")) {
                SproutAuthenticatedNavigationBar(
                    currentRoute = route,
                    onHome = { navController.popBackStack("home", false) },
                    onActivity = openActivity
                )
            }
        }
    ) { contentPadding ->
    NavHost(navController = navController, startDestination = "home",
        modifier = Modifier.padding(contentPadding)) {
        composable("home") {
            HomeScreen(
                state = accountState,
                now = Date(),
                offline = offline,
                onViewActivity = openActivity,
                onRetry = { activityViewModel.retry(currentUser) }
            )
        }
        composable("activity") {
            ActivityListScreen(
                state = accountState,
                now = Date(),
                offline = offline,
                query = query,
                onQueryChange = { query = it },
                kind = ActivityKind.valueOf(kindName),
                onKindChange = { kindName = it.name },
                period = ActivityPeriod.valueOf(periodName),
                onPeriodChange = { periodName = it.name },
                onOpen = { id -> navController.navigate("transaction/${Uri.encode(id)}") },
                onRetry = { activityViewModel.retry(currentUser) }
            )
        }
        composable("transaction/{id}") { entry ->
            val id = entry.arguments?.getString("id")
            val item = (accountState as? ActivityLoadState.Ready)?.items?.firstOrNull { it.id == id }
            ActivityDetailScreen(item = item, onBack = { navController.popBackStack() })
        }
    }
    }
}

private fun ConnectivityManager.isValidated(): Boolean {
    val active = activeNetwork ?: return false
    return getNetworkCapabilities(active)?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
}
