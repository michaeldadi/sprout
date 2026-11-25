package com.michaeldadi.sprout.ui.review

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.ime
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.compose.currentBackStackEntryAsState
import com.michaeldadi.sprout.data.entities.SyncStatus
import com.michaeldadi.sprout.data.entities.TransactionType
import com.michaeldadi.sprout.ui.activity.ActivityDetailScreen
import com.michaeldadi.sprout.ui.activity.ActivityItem
import com.michaeldadi.sprout.ui.activity.ActivityKind
import com.michaeldadi.sprout.ui.activity.ActivityListScreen
import com.michaeldadi.sprout.ui.activity.ActivityLoadState
import com.michaeldadi.sprout.ui.activity.ActivityPeriod
import com.michaeldadi.sprout.ui.home.HomeScreen
import com.michaeldadi.sprout.ui.components.SproutAuthenticatedNavigationBar
import com.michaeldadi.sprout.ui.theme.SproutTheme
import com.michaeldadi.sprout.ui.theme.SproutTokens
import java.math.BigDecimal
import java.time.Instant
import java.util.Date

/** Fixed fictional source records. This activity is excluded from release builds. */
class ActivityReviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { SproutTheme { ActivityReview() } }
    }
}

/** Home and Activity share the same fixed, fictional records in this debug-only host. */
class HomeReviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { SproutTheme { HomeReview() } }
    }
}

private enum class HomeScene(val label: String) {
    RECORDS("Records"), EMPTY("Empty"), OLDER("Older"), LOADING("Loading"),
    ERROR("Error"), STALE("Stale"), OFFLINE("Offline")
}

@Composable
private fun HomeReview() {
    var scene by remember { mutableStateOf(HomeScene.RECORDS) }
    var query by remember { mutableStateOf("") }
    var kind by remember { mutableStateOf(ActivityKind.ALL) }
    var period by remember { mutableStateOf(ActivityPeriod.RECENT) }
    val navController = rememberNavController()
    val route = navController.currentBackStackEntryAsState().value?.destination?.route
    val isKeyboardVisible = WindowInsets.ime.getBottom(LocalDensity.current) > 0
    val state: ActivityLoadState = when (scene) {
        HomeScene.RECORDS, HomeScene.OFFLINE -> ActivityLoadState.Ready(fixtureItems)
        HomeScene.STALE -> ActivityLoadState.Ready(fixtureItems.map { item ->
            if (item.id == "demo-grocery") item.copy(lastSyncedAt = Date(fixtureNow.time - 5L * 86_400_000)) else item
        })
        HomeScene.EMPTY -> ActivityLoadState.Ready(emptyList())
        HomeScene.OLDER -> ActivityLoadState.Ready(fixtureItems.filter { it.id == "demo-old" })
        HomeScene.LOADING -> ActivityLoadState.Loading
        HomeScene.ERROR -> ActivityLoadState.Failed("Saved activity could not be read. Try again.")
    }
    Column(modifier = Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
        Surface(color = SproutTokens.colors.surface) {
            Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)) {
                Text("DEMO DATA · 8 NOV 2026 · NEW YORK", color = SproutTokens.colors.textSecondary)
                Row(modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    HomeScene.entries.forEach { option ->
                        FilterChip(selected = scene == option, onClick = { scene = option }, label = { Text(option.label) })
                    }
                }
            }
        }
        NavHost(navController = navController, startDestination = "home", modifier = Modifier.weight(1f)) {
            composable("home") {
                HomeScreen(state, fixtureNow, scene == HomeScene.OFFLINE,
                    onViewActivity = { navController.navigate("activity") }, onRetry = { scene = HomeScene.RECORDS })
            }
            composable("activity") {
                ActivityListScreen(state, fixtureNow, scene == HomeScene.OFFLINE,
                    query, { query = it }, kind, { kind = it }, period, { period = it },
                    { id -> navController.navigate("transaction/$id") }, { scene = HomeScene.RECORDS })
            }
            composable("transaction/{id}") { entry ->
                ActivityDetailScreen(fixtureItems.firstOrNull { it.id == entry.arguments?.getString("id") },
                    onBack = { navController.popBackStack() })
            }
        }
        if (!isKeyboardVisible && (route == "home" || route == "activity")) {
            SproutAuthenticatedNavigationBar(
                currentRoute = route,
                onHome = { navController.popBackStack("home", false) },
                onActivity = { navController.navigate("activity") { launchSingleTop = true } }
            )
        }
    }
}

private enum class Scene(val label: String) {
    RECORDS("Records"), EMPTY("Empty"), LOADING("Loading"), ERROR("Error"), STALE("Stale"), OFFLINE("Offline")
}

@Composable
private fun ActivityReview() {
    var scene by remember { mutableStateOf(Scene.RECORDS) }
    var query by remember { mutableStateOf("") }
    var kind by remember { mutableStateOf(ActivityKind.ALL) }
    var period by remember { mutableStateOf(ActivityPeriod.RECENT) }
    val navController = rememberNavController()
    val sceneItems = if (scene == Scene.STALE) fixtureItems.map { item ->
        item.copy(lastSyncedAt = item.lastSyncedAt?.let { Date(it.time - 5L * 86_400_000) })
    } else fixtureItems
    val state: ActivityLoadState = when (scene) {
        Scene.RECORDS, Scene.STALE, Scene.OFFLINE -> ActivityLoadState.Ready(sceneItems)
        Scene.EMPTY -> ActivityLoadState.Ready(emptyList())
        Scene.LOADING -> ActivityLoadState.Loading
        Scene.ERROR -> ActivityLoadState.Failed("Saved activity could not be read. Try again.")
    }
    Column(modifier = Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
        Surface(color = SproutTokens.colors.surface) {
            Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)) {
                Text("DEMO DATA · 8 NOV 2026 · NEW YORK", color = SproutTokens.colors.textSecondary)
                Row(modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Scene.entries.forEach { option ->
                        FilterChip(selected = scene == option, onClick = { scene = option }, label = { Text(option.label) })
                    }
                }
            }
        }
        NavHost(navController = navController, startDestination = "activity", modifier = Modifier.weight(1f)) {
            composable("activity") {
                ActivityListScreen(state, fixtureNow, scene == Scene.OFFLINE,
                    query, { query = it }, kind, { kind = it }, period, { period = it },
                    { id -> navController.navigate("transaction/$id") }, { scene = Scene.RECORDS })
            }
            composable("transaction/{id}") { entry ->
                ActivityDetailScreen(sceneItems.firstOrNull { it.id == entry.arguments?.getString("id") },
                    onBack = { navController.popBackStack() })
            }
        }
    }
}

private val fixtureNow = Date.from(Instant.parse("2026-11-08T14:41:00Z"))
private fun date(value: String) = Date.from(Instant.parse(value))
private val fixtureItems = listOf(
    ActivityItem("demo-grocery", "North Market", "Groceries", BigDecimal("84.27"), "USD",
        date("2026-11-07T18:30:00Z"), TransactionType.EXPENSE, SyncStatus.SYNCED,
        date("2026-11-08T14:31:00Z"), "Checking · 1034", null),
    ActivityItem("demo-pay", "Payroll deposit", "Pay", BigDecimal("2480.00"), "USD",
        date("2026-11-06T15:00:00Z"), TransactionType.INCOME, SyncStatus.SYNCED,
        date("2026-11-08T14:31:00Z"), "Checking · 1034", null),
    ActivityItem("demo-transfer", "Transfer to rainy day savings", "Transfer", BigDecimal("350.00"), "USD",
        date("2026-11-05T12:15:00Z"), TransactionType.TRANSFER, SyncStatus.PENDING,
        null, null, "Internal transfer"),
    ActivityItem("demo-ride", "Metro ride", "Transit", BigDecimal("21.40"), "USD",
        date("2026-11-04T23:10:00Z"), TransactionType.EXPENSE, SyncStatus.FAILED,
        null, "Card · 7742", null),
    ActivityItem("demo-old", "Cinema", "Entertainment", BigDecimal("16.00"), "USD",
        date("2026-09-01T21:20:00Z"), TransactionType.EXPENSE, SyncStatus.SYNCED,
        date("2026-09-02T14:00:00Z"), "Card · 7742", null)
)
