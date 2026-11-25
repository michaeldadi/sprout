package com.michaeldadi.sprout.money

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.speech.RecognizerIntent
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.navigation.compose.*
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.michaeldadi.sprout.services.*
import com.michaeldadi.sprout.ui.theme.SproutTheme
import java.util.UUID
import kotlinx.coroutines.launch

@Composable
fun MoneyApp(
    identity: AppwriteAccountIdentity,
    incomingLink: Uri? = null,
    incomingDelivery: String? = null,
    review: MoneyWorkspace? = null,
) {
    val context = LocalContext.current
    val repository = remember(identity.id) { MoneyRepository(context, identity, review) }
    val state by repository.state.collectAsState()
    val scope = rememberCoroutineScope()
    LaunchedEffect(repository) { repository.initialize() }
    DisposableEffect(repository) { onDispose { repository.deactivate() } }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var foreground by
        remember(lifecycle) {
            mutableStateOf(lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))
        }
    DisposableEffect(repository, lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            foreground = event.targetState.isAtLeast(Lifecycle.State.RESUMED)
            if (event == Lifecycle.Event.ON_RESUME) scope.launch { repository.refresh() }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    val changeChannel = state.workspace?.changeChannel
    LaunchedEffect(repository, foreground, changeChannel) {
        if (!foreground || review != null || changeChannel == null ||
            !Regex("^tablesdb\\.[A-Za-z0-9_-]+\\.tables\\.sync_heads\\.rows\\.[A-Za-z0-9_-]+$").matches(changeChannel)) return@LaunchedEffect
        repeat(6) { attempt ->
            if (AppwriteNativeSession.identity.value?.id != identity.id) return@LaunchedEffect
            try {
                MoneyChangeSignal.listen(identity.id, changeChannel).collect {
                    kotlinx.coroutines.delay(400); repository.refresh()
                }
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (_: Exception) { /* Cursor sync remains authoritative. */ }
            kotlinx.coroutines.delay(minOf(15000L,1000L shl attempt))
        }
    }
    LaunchedEffect(repository, foreground) {
        if (foreground && review == null) while (true) {
            kotlinx.coroutines.delay(300000)
            repository.refresh()
        }
    }
    val pendingMutations = state.mutations.filter { !it.conflict }.map { it.id }.sorted()
    LaunchedEffect(repository, foreground, pendingMutations) {
        if (foreground && review == null && pendingMutations.isNotEmpty())
            repeat(6) { attempt ->
                kotlinx.coroutines.delay(
                    if (attempt == 0) 250L else minOf(15000L, 1000L shl attempt)
                )
                repository.refresh()
            }
    }
    val pendingJobs =
        state.workspace
            ?.jobs
            .orEmpty()
            .filter {
                it.type in listOf("assistant", "review.prepare", "privacy.export", "privacy.delete", "bank.sync", "transaction.import", "receipt.reconcile", "receipt.cleanup") &&
                    it.status in listOf("queued", "running", "retry")
            }
            .map { it.id }
            .sorted()
    LaunchedEffect(repository, foreground, pendingJobs) {
        if (foreground && review == null && pendingJobs.isNotEmpty())
            repeat(40) { attempt ->
                kotlinx.coroutines.delay(minOf(15000L, 2000L + (attempt / 4) * 1000L))
                repository.refresh()
            }
    }
    val dark =
        when (state.workspace?.profile?.appearance) {
            "dark" -> true
            "light" -> false
            else -> isSystemInDarkTheme()
        }
    SideEffect {
        (context as? android.app.Activity)?.let { activity ->
            androidx.core.view.WindowCompat.getInsetsController(
                    activity.window,
                    activity.window.decorView,
                )
                .apply {
                    isAppearanceLightStatusBars = !dark
                    isAppearanceLightNavigationBars = !dark
                }
        }
    }
    SproutTheme(darkTheme = dark) {
        MoneyDeviceGate(review != null) {
            when {
                state.workspace == null ->
                    MoneyPage("Your Sprout", state) {
                        Text(
                            if (state.refreshing || state.message == null) "Opening your workspace…"
                            else "Your workspace is unavailable",
                            style = MaterialTheme.typography.headlineSmall,
                        )
                        Text(state.message ?: "Connecting to your saved financial records.")
                        Button(onClick = { scope.launch { repository.refresh() } }) {
                            Text("Retry")
                        }
                        TextButton(onClick = { scope.launch { AppwriteNativeSession.signOut() } }) {
                            Text("Sign out")
                        }
                    }
                state.workspace!!.profile.onboarding != "complete" ->
                    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
                        MoneyOnboarding(repository, state)
                    }
                else -> MoneyShell(repository, state, incomingLink, incomingDelivery)
            }
        }
    }
}

@Composable
private fun MoneyShell(repo: MoneyRepository, state: MoneyState, incomingLink: Uri?, incomingDelivery: String?) {
    val startTab = rememberSaveable {
        when (incomingLink?.let { it.path?.takeIf(String::isNotEmpty) ?: "/${it.host}" }) {
            "/subscriptions", "/subscription", "/insights", "/actions" -> "insights"
            "/transaction", "/activity", "/expense" -> "activity"
            "/budget" -> "budget"
            "/profile" -> "profile"
            else -> "home"
        }
    }
    var handledDelivery by rememberSaveable { mutableStateOf<String?>(null) }
    val nav = rememberNavController()
    val route = nav.currentBackStackEntryAsState().value?.destination?.route ?: startTab
    val scope = rememberCoroutineScope()
    var expense by rememberSaveable { mutableStateOf(false) }
    var initialExpense by
        rememberSaveable(
            stateSaver =
                androidx.compose.runtime.saveable.Saver<ExpenseDraft, String>(
                    save = { Gson().toJson(it) },
                    restore = { Gson().fromJson(it, ExpenseDraft::class.java) },
                )
        ) {
            mutableStateOf(ExpenseDraft())
        }
    var expenseLinkError by remember { mutableStateOf(false) }
    var homeOrigin by rememberSaveable { mutableStateOf(false) }
    var chatContext by rememberSaveable { mutableStateOf<String?>(null) }
    val selected =
        when {
            route.startsWith("subscription") || route.startsWith("action") -> "insights"
            route.startsWith("transaction") -> "activity"
            route == "connection" || route.startsWith("privacy") -> "profile"
            else -> route
        }
    LaunchedEffect(selected) { if (!repo.reviewMode) MoneyAnalytics.track("screen_view", mapOf("screen_name" to selected)) }
    fun navigateTab(destination: String) {
        nav.navigate(destination) {
            popUpTo(nav.graph.startDestinationId) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }
    fun ask(value: String) {
        chatContext = value
        navigateTab("insights")
    }
    fun openSubscriptions() {
        homeOrigin = selected == "home"
        navigateTab("insights")
        nav.navigate("subscriptions")
    }
    LaunchedEffect(incomingLink, incomingDelivery, expense) {
        incomingLink?.let { link ->
            val delivery = incomingDelivery ?: link.toString()
            if (handledDelivery == delivery) return@LaunchedEffect
            val path = link.path?.takeIf { it.isNotEmpty() } ?: "/${link.host}"
            if (path == "/expense" && expense) return@LaunchedEffect
            handledDelivery = delivery
            when (path) {
                "/budget" -> navigateTab("budget")
                "/transaction" -> {
                    navigateTab("activity")
                    link.getQueryParameter("id")?.let {
                        nav.navigate("transaction/${Uri.encode(it)}")
                    }
                }
                "/subscriptions" -> {
                    homeOrigin = false
                    navigateTab("insights")
                    nav.navigate("subscriptions")
                }
                "/insights" -> navigateTab("insights")
                "/activity" -> navigateTab("activity")
                "/profile" -> navigateTab("profile")
                "/subscription" -> {
                    navigateTab("insights")
                    link.getQueryParameter("id")?.let {
                        nav.navigate("subscription/${Uri.encode(it)}")
                    }
                }
                "/actions" -> {
                    navigateTab("insights")
                    link.getQueryParameter("id")?.let { nav.navigate("action/${Uri.encode(it)}") }
                }
                "/expense" ->
                    if (!expense) {
                        val fields =
                            link.queryParameterNames.associateWith {
                                link.getQueryParameter(it).orEmpty()
                            }
                        val draft =
                            if (
                                link.toString().length < 12_000 &&
                                    link.queryParameterNames.all {
                                        link.getQueryParameters(it).size == 1
                                    }
                            )
                                ExpenseDraft.shortcut(fields)
                            else null
                        if (draft == null) expenseLinkError = true
                        else {
                            initialExpense = draft
                            expense = true
                        }
                    }
            }
        }
    }
    BackHandler(enabled = route == "subscriptions" && homeOrigin) {
        homeOrigin = false
        nav.popBackStack()
        navigateTab("home")
    }
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        contentWindowInsets = WindowInsets.safeDrawing,
        topBar = {
            if (route !in MoneyTab.entries.map { it.route })
                Row(Modifier.statusBarsPadding()) {
                    IconButton(
                        onClick = {
                            nav.popBackStack()
                            if (route == "subscriptions" && homeOrigin) {
                                homeOrigin = false
                                navigateTab("home")
                            }
                        }
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                }
        },
        bottomBar = {
            if (route in MoneyTab.entries.map { it.route }) {
                MoneyFloatingNavigation(
                    selected,
                    route == "home" || route == "activity",
                    { destination ->
                        homeOrigin = false
                        navigateTab(destination)
                    },
                    { expense = true },
                )
            }
        },
    ) { padding ->
        NavHost(
            navController = nav,
            startDestination = startTab,
            modifier = Modifier.padding(padding),
        ) {
            composable("home") {
                MoneyHome(
                    repo,
                    state,
                    ::openSubscriptions,
                    { navigateTab("activity") },
                    { id -> nav.navigate("transaction/${Uri.encode(id)}") },
                    ::ask,
                )
            }
            composable("budget") { MoneyBudgetScreen(repo, state, ::ask) }
            composable("activity") {
                MoneyActivity(repo, state) { nav.navigate("transaction/${Uri.encode(it)}") }
            }
            composable("insights") {
                MoneyInsights(
                    repo,
                    state,
                    chatContext,
                    { chatContext = null },
                    { nav.navigate("subscriptions") },
                    { nav.navigate("transaction/${Uri.encode(it)}") },
                )
            }
            composable("profile") {
                MoneyProfileScreen(
                    repo,
                    state,
                    { nav.navigate("connection") },
                    { nav.navigate("privacy/$it") },
                    { nav.navigate("import") },
                )
            }
            composable("subscriptions") {
                MoneySubscriptions(state) { nav.navigate("subscription/${Uri.encode(it)}") }
            }
            composable("subscription/{id}") { entry ->
                MoneySubscriptionScreen(
                    repo,
                    state,
                    entry.arguments?.getString("id"),
                    ::ask,
                    { nav.navigate("transaction/${Uri.encode(it)}") },
                    { nav.navigate("action/${Uri.encode(it)}") },
                )
            }
            composable("transaction/{id}") { entry ->
                MoneyTransactionScreen(
                    repo,
                    state,
                    entry.arguments?.getString("id"),
                    ::ask,
                    requestSync = { scope.launch { repo.refresh() } },
                ) {
                    nav.popBackStack()
                }
            }
            composable("action/{id}") { entry ->
                MoneyActionScreen(repo, state, entry.arguments?.getString("id"))
            }
            composable("connection") { MoneyConnection(repo, state) }
            composable("import") { MoneyImportScreen(repo, state) }
            composable("privacy/{kind}") { entry ->
                MoneyPrivacy(repo, state, entry.arguments?.getString("kind") ?: "export")
            }
        }
    }
    if (expense)
        MoneyExpenseSheet(repo, initialExpense, onSaved = { scope.launch { repo.refresh() } }) {
            expense = false
            initialExpense = ExpenseDraft()
        }
    if (expenseLinkError)
        AlertDialog(
            onDismissRequest = { expenseLinkError = false },
            title = { Text("Review expense") },
            text = {
                Text(
                    "Use a positive USD amount with at most two decimal places, a valid date, and a supported category."
                )
            },
            confirmButton = { TextButton(onClick = { expenseLinkError = false }) { Text("OK") } },
        )
}

@Composable
private fun MoneyFloatingNavigation(
    selected: String,
    addVisible: Boolean,
    navigate: (String) -> Unit,
    expense: () -> Unit,
) {
    BoxWithConstraints(
        Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        val showLabels = maxWidth >= 350.dp && LocalDensity.current.fontScale < 1.5f
        val attached = addVisible && showLabels
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Surface(
                Modifier.weight(1f),
                shape = RoundedCornerShape(32.dp),
                color = MaterialTheme.colorScheme.surface,
                shadowElevation = 6.dp,
            ) {
                Row(
                    Modifier.padding(6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceAround,
                ) {
                    MoneyTab.entries.forEach { tab ->
                        val active = selected == tab.route
                        val icon =
                            when (tab) {
                                MoneyTab.HOME -> Icons.Default.Home
                                MoneyTab.BUDGET -> Icons.Default.PieChart
                                MoneyTab.ACTIVITY -> Icons.AutoMirrored.Filled.List
                                MoneyTab.INSIGHTS -> Icons.Default.AutoAwesome
                                MoneyTab.PROFILE -> Icons.Default.Person
                            }
                        if (active && showLabels)
                            Surface(
                                shape = RoundedCornerShape(24.dp),
                                color = MaterialTheme.colorScheme.primaryContainer,
                            ) {
                                Row(
                                    Modifier.selectable(
                                            true,
                                            onClick = { navigate(tab.route) },
                                            role = Role.Tab,
                                        )
                                        .heightIn(min = 48.dp)
                                        .padding(horizontal = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                ) {
                                    Icon(icon, tab.title, Modifier.size(20.dp))
                                    Text(tab.title, style = MaterialTheme.typography.labelMedium)
                                }
                            }
                        else
                            IconButton(
                                onClick = { navigate(tab.route) },
                                modifier = Modifier.size(48.dp),
                            ) {
                                Icon(
                                    icon,
                                    tab.title,
                                    tint =
                                        if (active) MaterialTheme.colorScheme.primary
                                        else MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                    }
                }
            }
            if (attached)
                FloatingActionButton(
                    onClick = expense,
                    modifier = Modifier.size(64.dp),
                    shape = RoundedCornerShape(20.dp),
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ) {
                    Icon(Icons.Default.Add, "Add expense")
                }
        }
        if (addVisible && !attached)
            FilledTonalIconButton(
                onClick = expense,
                modifier = Modifier.align(Alignment.TopEnd).offset(y = (-64).dp).size(56.dp),
            ) {
                Icon(Icons.Default.Add, "Add expense")
            }
    }
}

@Composable
private fun MoneyPage(
    title: String,
    state: MoneyState,
    compactHeader: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        Modifier.fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .imePadding()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Text(
            title,
            style =
                if (compactHeader) MaterialTheme.typography.titleLarge
                else MaterialTheme.typography.headlineLarge,
        )
        if (state.refreshing) LinearProgressIndicator(Modifier.fillMaxWidth())
        state.message?.let {
            Text(
                it,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
            )
        }
        if (state.mutations.isNotEmpty())
            Text(
                "${state.mutations.size} pending change(s) · totals reflect the last server snapshot",
                style = MaterialTheme.typography.labelMedium,
            )
        content()
        Spacer(Modifier.height(80.dp))
    }
}

@Composable
private fun MoneyCard(
    color: androidx.compose.ui.graphics.Color = MaterialTheme.colorScheme.surface,
    content: @Composable ColumnScope.() -> Unit,
) {
    Surface(shape = RoundedCornerShape(26.dp), color = color, modifier = Modifier.fillMaxWidth()) {
        Column(
            Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            content = content,
        )
    }
}

@Composable
private fun InsightPill(text: String) {
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.primaryContainer,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Default.AutoAwesome,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Text(text, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun Amount(minor: Long?) {
    Text(
        minor?.let { MoneyAmount(it).formatted() } ?: "—",
        style = MaterialTheme.typography.displaySmall,
        maxLines = 2,
    )
}

@Composable
private fun ValueRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(label, Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, Modifier.weight(1f))
    }
}

@Composable
private fun TransactionRow(item: MoneyTransaction, pending: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Surface(
            shape = RoundedCornerShape(14.dp),
            color = MaterialTheme.colorScheme.surfaceContainer,
        ) {
            Text(
                item.merchant.take(1).uppercase(),
                Modifier.padding(14.dp),
                style = MaterialTheme.typography.titleMedium,
            )
        }
        Column(Modifier.weight(1f)) {
            Text(item.merchant, style = MaterialTheme.typography.titleMedium)
            Text(
                "${item.category} · ${if (pending) "Waiting to sync" else if(item.source == "plaid") "Bank" else "Manual"}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(item.amount.formatted(), style = MaterialTheme.typography.titleSmall)
    }
}

@Composable
private fun Pace(pace: MoneyCategoryPace) {
    Column(Modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        ValueRow(
            pace.category,
            "${MoneyAmount(pace.spentMinor).formatted()} / ${MoneyAmount(pace.plannedMinor).formatted()}",
        )
        LinearProgressIndicator(
            progress = {
                (pace.spentMinor.toFloat() / pace.plannedMinor.coerceAtLeast(1)).coerceIn(0f, 1f)
            },
            modifier = Modifier.fillMaxWidth(),
            color =
                if (pace.aheadOfPace)
                    com.michaeldadi.sprout.ui.theme.LocalSproutColors.current.warning
                else MaterialTheme.colorScheme.primary,
        )
        Text(
            "${MoneyAmount(pace.remainingMinor).formatted()} remaining",
            style = MaterialTheme.typography.labelMedium,
        )
    }
}

@Composable
private fun MoneyHome(
    repo: MoneyRepository,
    state: MoneyState,
    subscriptions: () -> Unit,
    activity: () -> Unit,
    transaction: (String) -> Unit,
    ask: (String) -> Unit,
) {
    val w = state.workspace ?: return
    MoneyPage(
        "Good to see you${w.profile.name.takeIf { it.isNotBlank() }?.let { ", $it" } ?: ""}",
        state,
        compactHeader = true,
    ) {
        Text(
            "Snapshot ${w.snapshot.asOf.take(16).replace('T', ' ')} UTC · ${w.transactions.size} saved",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        InsightPill(w.insights.firstOrNull()?.title ?: "Your money, with a little more clarity.")
        MoneyCard(color = MaterialTheme.colorScheme.primaryContainer) {
            Text(w.snapshot.heroLabel, style = MaterialTheme.typography.labelLarge)
            Amount(w.snapshot.heroMinor)
            Text(
                if (w.snapshot.heroMinor == null)
                    "Set your monthly target in Budget to get started."
                else "Based on saved spending this month.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            HorizontalDivider()
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        "Connected cash balance",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        w.snapshot.balanceMinor?.let { MoneyAmount(it).formatted() } ?: "—",
                        style = MaterialTheme.typography.titleLarge,
                    )
                }
                Column(
                    Modifier.weight(1f).clickable(onClick = subscriptions),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(
                        "Subscriptions / month",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        MoneyAmount(w.snapshot.monthlySubscriptionsMinor).formatted(),
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            }
        }
        Text(
            w.snapshot.coverage,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        w.subscriptions
            .firstOrNull { it.decision == "confirmed" }
            ?.let { s ->
                TextButton(onClick = subscriptions) {
                    Text("${s.merchant} · estimated renewal ${s.nextDate}")
                }
            }
        Text("Category pace", style = MaterialTheme.typography.titleLarge)
        MoneyCard {
            if (w.snapshot.budget.categories.isEmpty())
                Text("Give your money a plan. Add category limits in Budget.")
            w.snapshot.budget.categories.take(3).forEach { Pace(it) }
        }
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Latest activity", style = MaterialTheme.typography.titleLarge)
            TextButton(onClick = activity) { Text("View all") }
        }
        MoneyCard {
            if (repo.transactions().isEmpty()) Text("Your first expense starts here.")
            repo.transactions().take(4).forEach { t ->
                TransactionRow(t, state.mutations.any { it.entity == "transaction:${t.id}" }) {
                    transaction(t.id)
                }
            }
        }
        OutlinedButton(onClick = { ask("budget:${w.snapshot.budget.month}") }) {
            Text("Ask Sprout about this month")
        }
    }
}

@Composable
private fun MoneyBudgetScreen(repo: MoneyRepository, state: MoneyState, ask: (String) -> Unit) {
    val w = state.workspace ?: return
    val scope = rememberCoroutineScope()
    var selectedMonth by rememberSaveable { mutableStateOf("") }
    var choosingPeriod by remember { mutableStateOf(false) }
    val periods = w.budgetPeriods ?: listOf(w.snapshot.budget)
    val period = periods.firstOrNull { it.month == selectedMonth } ?: w.snapshot.budget
    val current = period.month == w.snapshot.budget.month
    var editing by remember { mutableStateOf<MoneyPlanEdit?>(null) }
    var choosingEdit by remember { mutableStateOf(false) }
    MoneyPage("Budget", state) {
        InsightPill(
            if (period.categories.any { it.aheadOfPace })
                "A category is moving ahead of its planned pace."
            else "A little direction for every dollar."
        )
        Box {
            TextButton(onClick = { choosingPeriod = true }) { Text("Period: ${period.month}") }
            DropdownMenu(expanded = choosingPeriod, onDismissRequest = { choosingPeriod = false }) {
                periods.forEach { item ->
                    DropdownMenuItem(
                        text = { Text(item.month) },
                        onClick = {
                            selectedMonth = item.month
                            choosingPeriod = false
                        },
                    )
                }
            }
        }
        Text(
            if (period.state == "closed") "Completed period"
            else if (current) "Current period" else "Upcoming period"
        )
        Amount(
            if (current) w.snapshot.heroMinor
            else if (period.categories.isEmpty()) null else period.remainingMinor
        )
        Text(if (current) "Remaining monthly target" else "Remaining category budgets")
        if (period.categories.isNotEmpty()) MoneyCategoryChart(period.categories)
        MoneyCard {
            if (period.categories.isEmpty())
                Text(
                    if (current) "Create your first category budget."
                    else "No category budgets were saved for this period."
                )
            period.categories.forEach { Pace(it) }
        }
        Text(
            "Pace uses posted expenses. Transfers and pending charges are excluded.",
            style = MaterialTheme.typography.bodySmall,
        )
        Button(onClick = {
            if (current) choosingEdit = true
            else editing = MoneyPlanEdit(w, period.month, true)
        }) { Text(if (current) "Edit your plan" else "Edit category budgets") }
        MoneyBudgetConflicts(repo, state)
        MoneyGoals(repo, state)
        TextButton(onClick = { ask("budget:${period.month}") }) { Text("Ask Sprout") }
    }
    if (choosingEdit) AlertDialog(
        onDismissRequest = { choosingEdit = false },
        title = { Text("Edit your plan") },
        text = { Text("Choose the part of your plan to update.") },
        confirmButton = { TextButton(onClick = {
            choosingEdit = false; editing = MoneyPlanEdit(w, period.month, false)
        }) { Text("Monthly target") } },
        dismissButton = { TextButton(onClick = {
            choosingEdit = false; editing = MoneyPlanEdit(w, period.month, true)
        }) { Text("Category budgets") } },
    )
    editing?.let { edit -> MoneyBudgetEditor(repo, edit) { editing = null } }
}

private data class MoneyPlanEdit(val baseline: MoneyWorkspace, val month: String, val categoryOnly: Boolean)

@Composable
private fun MoneyBudgetEditor(repo: MoneyRepository, edit: MoneyPlanEdit, close: () -> Unit) {
    val scope = rememberCoroutineScope()
    val saved = edit.baseline.budgets.filter { it.data.month == edit.month }
    var target by remember(edit) { mutableStateOf(edit.baseline.profile.monthlyTargetMinor?.let { java.math.BigDecimal.valueOf(it, 2).toPlainString() } ?: "") }
    var category by remember(edit) { mutableStateOf(saved.firstOrNull()?.data?.category ?: "Food") }
    var limit by remember(edit) { mutableStateOf(saved.firstOrNull()?.data?.limit?.minor?.let { java.math.BigDecimal.valueOf(it, 2).toPlainString() } ?: "") }
    var error by remember(edit) { mutableStateOf<String?>(null) }
    var saving by remember(edit) { mutableStateOf(false) }
    var choosingCategory by remember(edit) { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = { if (!saving) close() },
        title = { Text(if (edit.categoryOnly) "Category budget" else "Monthly target") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (edit.categoryOnly) {
                    Text("Category budget · ${edit.month}")
                    if (saved.isNotEmpty()) Box {
                        TextButton(onClick = { choosingCategory = true }) { Text("Choose a saved category") }
                        DropdownMenu(choosingCategory, onDismissRequest = { choosingCategory = false }) {
                            saved.forEach { item -> DropdownMenuItem(text = { Text(item.data.category) }, onClick = {
                                category = item.data.category
                                limit = java.math.BigDecimal.valueOf(item.data.limit.minor, 2).toPlainString()
                                choosingCategory = false
                            }) }
                        }
                    }
                    OutlinedTextField(category, { category = it }, label = { Text("Category") })
                    OutlinedTextField(limit, { limit = it }, label = { Text("Limit in USD") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
                    Text("This limit applies only to ${edit.month}.", style = MaterialTheme.typography.bodySmall)
                } else {
                    OutlinedTextField(target, { target = it }, label = { Text("Monthly target in USD") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
                    Text("This target applies to your ongoing monthly plan.", style = MaterialTheme.typography.bodySmall)
                }
                Text("If this plan changes on another device, Sprout will keep your edit for review.", style = MaterialTheme.typography.bodySmall)
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            }
        },
        confirmButton = { TextButton(enabled = !saving, onClick = {
            saving = true
            scope.launch {
                try {
                    if (edit.categoryOnly) {
                        val name = category.trim()
                        require(name.isNotEmpty()) { "Enter a category." }
                        val amount = MoneyAmount.parse(limit) ?: error("Review the category limit.")
                        val previous = saved.firstOrNull { MoneyBudget.categoryKey(it.data.category) == MoneyBudget.categoryKey(name) }
                        val id = previous?.id ?: UUID.randomUUID().toString()
                        repo.enqueue(mapOf("type" to "budget.upsert", "budget" to MoneyBudget(id, previous?.data?.category ?: name, edit.month, MoneyAmount(amount)), "expectedVersion" to (previous?.version ?: 0)), "budget:$id")
                    } else {
                        val amount = MoneyAmount.parse(target) ?: error("Enter your monthly target.")
                        repo.saveProfile(edit.baseline.profile.copy(monthlyTargetMinor = amount), expectedVersion = edit.baseline.profileVersion)
                    }
                    close()
                    repo.refresh()
                } catch (e: Exception) { error = e.message } finally { saving = false }
            }
        }) { Text("Save") } },
        dismissButton = { TextButton(enabled = !saving, onClick = close) { Text("Cancel") } },
    )
}

@Composable
private fun MoneyActivity(repo: MoneyRepository, state: MoneyState, open: (String) -> Unit) {
    var query by rememberSaveable { mutableStateOf("") }
    var type by rememberSaveable { mutableStateOf("All") }
    var period by rememberSaveable { mutableStateOf("This month") }
    val items =
        repo.transactions().filter { t ->
            (query.isBlank() ||
                "${t.merchant} ${t.category} ${t.description}".contains(query, true)) &&
                (type == "All" || t.type == type.lowercase()) &&
                (period == "All time" || t.date.startsWith(state.workspace?.today?.take(7) ?: ""))
        }
    MoneyPage("Activity", state) {
        OutlinedTextField(
            query,
            { query = it },
            Modifier.fillMaxWidth(),
            label = { Text("Search your activity") },
            leadingIcon = { Icon(Icons.Default.Search, null) },
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("This month", "All time").forEach {
                FilterChip(period == it, { period = it }, { Text(it) })
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            listOf("All", "Expense", "Income").forEach {
                FilterChip(type == it, { type = it }, { Text(it) })
            }
        }
        if (state.mutations.isNotEmpty())
            InsightPill(moneyPendingSyncCopy(state.mutations))
        if (items.isEmpty())
            MoneyCard {
                Text("No matching activity.")
                Text(
                    "Add an expense or change your filters.",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        items
            .groupBy { it.date }
            .forEach { (date, transactions) ->
                Text(date, style = MaterialTheme.typography.titleSmall)
                MoneyCard {
                    transactions.forEach { t ->
                        TransactionRow(
                            t,
                            state.mutations.any { it.entity == "transaction:${t.id}" },
                        ) {
                            open(t.id)
                        }
                    }
                }
            }
    }
}

@Composable
private fun MoneyTransactionScreen(
    repo: MoneyRepository,
    state: MoneyState,
    id: String?,
    ask: (String) -> Unit,
    requestSync: () -> Unit,
    back: () -> Unit,
) {
    val item = repo.transactions().firstOrNull { it.id == id }
    val scope = rememberCoroutineScope()
    var confirm by remember { mutableStateOf(false) }
    var deletionVersion by remember { mutableStateOf<Int?>(null) }
    var editDraft by remember { mutableStateOf<ExpenseDraft?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    MoneyPage("Transaction", state) {
        TextButton(onClick = back) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, null)
            Text("Back to Activity")
        }
        if (item == null) Text("This transaction is unavailable. Refresh Activity.")
        else {
            MoneyCard {
                Text(item.merchant, style = MaterialTheme.typography.headlineSmall)
                Amount(item.amount.minor)
                ValueRow("Date", item.date)
                ValueRow("Category", item.category)
                ValueRow("Source", item.source)
                ValueRow("Account", item.accountId)
                Text(item.description)
            }
            TextButton(onClick = { ask("transaction:${item.id}") }) { Text("Ask Sprout") }
            MoneyReceiptSection(repo, state, item.id)
            if (item.source != "plaid" && item.type == "expense")
                OutlinedButton(
                    onClick = { editDraft = ExpenseDraft.editing(item) },
                    enabled = state.mutations.none { it.entity == "transaction:$id" },
                ) {
                    Text("Edit expense")
                }
            if (item.source != "plaid")
                TextButton(
                    onClick = {
                        deletionVersion = item.version
                        confirm = true
                    },
                    enabled = state.mutations.none { it.entity == "transaction:$id" },
                ) {
                    Text("Delete transaction", color = MaterialTheme.colorScheme.error)
                }
            error?.let { Text(it) }
        }
    }
    if (confirm && item != null)
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text("Delete this transaction?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        scope.launch {
                            try {
                                repo.enqueue(
                                    mapOf(
                                        "type" to "transaction.delete",
                                        "id" to item.id,
                                        "expectedVersion" to (deletionVersion ?: return@launch),
                                    ),
                                    "transaction:${item.id}",
                                )
                                requestSync()
                                back()
                            } catch (e: Exception) {
                                error = e.message
                            }
                            confirm = false
                        }
                    }
                ) {
                    Text("Delete")
                }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text("Cancel") } },
        )
    editDraft?.let { draft ->
        MoneyExpenseSheet(repo, draft, onSaved = requestSync) { editDraft = null }
    }
}

@Composable
private fun MoneySubscriptions(state: MoneyState, open: (String) -> Unit) {
    val w = state.workspace ?: return
    MoneyPage("Subscriptions", state) {
        InsightPill("Recurring charges, with the evidence in view.")
        Amount(w.snapshot.monthlySubscriptionsMinor)
        Text("Monthly equivalent · confirmed subscriptions")
        if (w.subscriptions.isEmpty())
            MoneyCard {
                Text("Nothing recurring yet.")
                Text(
                    "Candidates appear after at least three matching charges. Manual tracking remains available."
                )
            }
        w.subscriptions.firstOrNull()?.let {
            InsightPill("Next estimated renewal · ${it.nextDate}")
        }
        w.subscriptions.forEach { s ->
            MoneyCard {
                Column(
                    Modifier.fillMaxWidth().clickable { open(s.id) },
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(s.merchant, style = MaterialTheme.typography.titleLarge)
                    ValueRow(
                        "${s.decision.replaceFirstChar { it.uppercase() }} · estimated ${s.nextDate}",
                        "${MoneyAmount(s.amountMinor).formatted()} / ${s.cadence}",
                    )
                }
            }
        }
    }
}

@Composable
private fun MoneySubscriptionScreen(
    repo: MoneyRepository,
    state: MoneyState,
    id: String?,
    ask: (String) -> Unit,
    transaction: (String) -> Unit,
    action: (String) -> Unit,
) {
    val s = state.workspace?.subscriptions?.firstOrNull { it.id == id }
    val scope = rememberCoroutineScope()
    var error by remember { mutableStateOf<String?>(null) }
    fun command(value: Map<String, Any?>, key: String) {
        scope.launch {
            try {
                repo.enqueue(value, key)
                repo.refresh()
            } catch (e: Exception) {
                error = e.message
            }
        }
    }
    MoneyPage("Subscription", state) {
        if (s == null) Text("The evidence may have changed. Refresh subscriptions.")
        else {
            Text(s.merchant, style = MaterialTheme.typography.headlineLarge)
            Amount(s.amountMinor)
            Text("${s.cadence} · estimated renewal ${s.nextDate}")
            InsightPill(
                if (s.decision == "confirmed")
                    "You confirmed that Sprout should track this subscription."
                else "A recurring pattern was detected. Review the charges to confirm it."
            )
            if (s.decision != "confirmed")
                Button(
                    onClick = {
                        command(
                            mapOf(
                                "type" to "recurring.decide",
                                "id" to s.id,
                                "decision" to "confirmed",
                                "expectedVersion" to s.decisionVersion,
                            ),
                            "recurring:${s.id}",
                        )
                    }
                ) {
                    Text("Track as a subscription")
                }
            Text("Charge history", style = MaterialTheme.typography.titleLarge)
            MoneyCard {
                val max = s.charges.maxOfOrNull { it.minor }?.coerceAtLeast(1) ?: 1
                s.charges.forEach { charge ->
                    ValueRow(charge.date, MoneyAmount(charge.minor).formatted())
                    LinearProgressIndicator(
                        progress = { charge.minor.toFloat() / max },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                Text(
                    "Actual charges. Bank charges don't show whether you use the service.",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            MoneyCard {
                s.evidenceIds.forEach { id ->
                    repo
                        .transactions()
                        .firstOrNull { it.id == id }
                        ?.let { t -> TransactionRow(t, false) { transaction(id) } }
                }
                ValueRow("Account", s.accountId)
            }
            val reminder =
                state.workspace?.reminders?.firstOrNull { it.data.subscriptionId == s.id }
            OutlinedButton(
                onClick = {
                    command(
                        mapOf(
                            "type" to "reminder.set",
                            "subscriptionId" to s.id,
                            "enabled" to !(reminder?.data?.enabled ?: false),
                            "daysBefore" to 3,
                        ),
                        "reminder:${s.id}",
                    )
                },
                enabled = state.workspace?.capabilities?.notifications == true,
            ) {
                Text(
                    if (reminder?.data?.enabled == true) "Turn off renewal reminder"
                    else "Remind me before renewal"
                )
            }
            if (state.workspace?.capabilities?.notifications != true)
                Text(
                    "Reminder delivery is not available in this environment.",
                    style = MaterialTheme.typography.bodySmall,
                )
            Text("Direct cancellation", style = MaterialTheme.typography.titleLarge)
            Text(
                "A reminder and a cancellation are separate actions. Cancellation completes only after authoritative provider confirmation.",
                style = MaterialTheme.typography.bodySmall,
            )
            state.workspace
                ?.actions
                ?.filter { it.data.subscriptionId == s.id }
                ?.forEach { a ->
                    OutlinedButton(onClick = { action(a.id) }) {
                        Text("Cancellation · ${a.data.state.replace('_',' ')}")
                    }
                }
            Button(
                onClick = {
                    command(
                        mapOf("type" to "action.propose", "subscriptionId" to s.id),
                        "action:${s.id}",
                    )
                },
                enabled = state.workspace?.capabilities?.cancellation == true,
            ) {
                Text("Review cancellation")
            }
            TextButton(onClick = { ask("subscription:${s.id}") }) { Text("Ask Sprout") }
            TextButton(
                onClick = {
                    command(
                        mapOf(
                            "type" to "recurring.decide",
                            "id" to s.id,
                            "decision" to "dismissed",
                            "expectedVersion" to s.decisionVersion,
                        ),
                        "recurring:${s.id}",
                    )
                }
            ) {
                Text("This isn't a subscription")
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        }
    }
}

@Composable
private fun MoneyActionScreen(repo: MoneyRepository, state: MoneyState, id: String?) {
    val a = state.workspace?.actions?.firstOrNull { it.id == id }
    val scope = rememberCoroutineScope()
    var confirm by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    MoneyPage("Cancellation", state) {
        if (a == null) Text("Action unavailable.")
        else {
            MoneyCard {
                Text(a.data.merchant, style = MaterialTheme.typography.headlineSmall)
                ValueRow("Status", a.data.state.replace('_', ' '))
                Text(
                    "Cancel this specific subscription. Refunds and access end dates depend on the merchant. Partner authentication may be required."
                )
            }
            if (a.data.state == "proposed")
                Button(onClick = { confirm = true }) { Text("Approve this cancellation") }
            if (a.data.state == "needs_attention")
                InsightPill("The outcome is uncertain. Sprout must reconcile it before retrying.")
            Text(
                "Approval expires after 24 hours or a material evidence change.",
                style = MaterialTheme.typography.bodySmall,
            )
            error?.let { Text(it) }
        }
    }
    if (confirm && a != null)
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = { Text("Approve cancellation?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        scope.launch {
                            try {
                                repo.enqueue(
                                    mapOf(
                                        "type" to "action.approve",
                                        "id" to a.id,
                                        "expectedVersion" to a.version,
                                        "evidenceHash" to a.data.evidenceHash,
                                    ),
                                    "action:${a.id}",
                                )
                                repo.refresh()
                            } catch (e: Exception) {
                                error = e.message
                            }
                            confirm = false
                        }
                    }
                ) {
                    Text("Approve")
                }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text("Cancel") } },
        )
}

@Composable
private fun MoneyInsights(
    repo: MoneyRepository,
    state: MoneyState,
    context: String?,
    clear: () -> Unit,
    subscriptions: () -> Unit,
    transaction: (String) -> Unit,
) {
    var mode by rememberSaveable { mutableStateOf(if (context == null) "Feed" else "Chat") }
    var question by rememberSaveable { mutableStateOf("") }
    var answer by rememberSaveable { mutableStateOf("") }
    var answerJobId by rememberSaveable { mutableStateOf<String?>(null) }
    var asking by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(context) { if (context != null) mode = "Chat" }
    MoneyPage("Insights", state) {
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
            listOf("Feed", "Chat").forEachIndexed { index, label ->
                SegmentedButton(
                    selected = mode == label,
                    onClick = { mode = label },
                    shape = SegmentedButtonDefaults.itemShape(index, 2),
                ) {
                    Text(label)
                }
            }
        }
        if (mode == "Feed") {
            OutlinedButton(onClick = subscriptions) { Text("Your subscriptions and renewals") }
            val review = state.workspace?.jobs?.filter { it.type == "review.prepare" }?.maxByOrNull { it.updatedAt ?: "" }
            val preparing = review?.status in listOf("queued", "running", "retry")
            OutlinedButton(enabled = !preparing && state.mutations.none { it.entity == "weekly-review" }, onClick = { scope.launch { repo.enqueue(mapOf("type" to "review.weekly"), "weekly-review"); repo.refresh() } }) { Text("Review last week") }
            if (preparing) InsightPill(if (review?.error == "INCOMPLETE_HISTORY") "Your review is waiting for the current import to finish." else "Your weekly review is saved and being prepared.")
            if (review?.result?.status == "empty") Text("No completed records from last week yet. Add your history to create a review.", style = MaterialTheme.typography.bodySmall)
            if (state.workspace?.insights.isNullOrEmpty())
                MoneyCard {
                    Icon(Icons.Default.AutoAwesome, null, tint = MaterialTheme.colorScheme.primary)
                    Text(
                        "Clarity comes with a little history.",
                        style = MaterialTheme.typography.titleLarge,
                    )
                    Text(
                        "Sprout will show evidence-backed changes as you build your financial picture."
                    )
                }
            state.workspace?.insights?.forEach { insight ->
                MoneyCard {
                    Text(insight.title, style = MaterialTheme.typography.titleLarge)
                    Text(insight.detail)
                    insight.evidenceIds.take(3).forEach { id ->
                        TextButton(onClick = { transaction(id) }) { Text("Supporting transaction") }
                    }
                    Row {
                        TextButton(
                            onClick = {
                                mode = "Chat"
                                question = "Explain this insight: ${insight.title}"
                            }
                        ) {
                            Text("Ask Sprout")
                        }
                        TextButton(
                            onClick = {
                                scope.launch {
                                    repo.enqueue(
                                        mapOf(
                                            "type" to "insight.feedback",
                                            "id" to insight.id,
                                            "feedback" to "dismissed",
                                        ),
                                        "insight:${insight.id}",
                                    )
                                    repo.refresh()
                                }
                            }
                        ) {
                            Text("Dismiss")
                        }
                        TextButton(
                            onClick = {
                                scope.launch {
                                    repo.enqueue(
                                        mapOf(
                                            "type" to "insight.feedback",
                                            "id" to insight.id,
                                            "feedback" to "snoozed",
                                        ),
                                        "insight:${insight.id}",
                                    )
                                    repo.refresh()
                                }
                            }
                        ) {
                            Text("Snooze")
                        }
                    }
                }
            }
        } else {
            InsightPill("Ask a question. Review the evidence. Choose what happens next.")
            context?.let {
                Text("Context: $it", style = MaterialTheme.typography.labelMedium)
                TextButton(onClick = clear) { Text("Clear context") }
            }
            state.workspace
                ?.conversations
                ?.sortedBy { it.data.createdAt }
                ?.forEach { conversation ->
                    MoneyCard {
                        Text(
                            conversation.data.question,
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text(conversation.data.answer.message)
                        conversation.data.answer.references.forEach { reference ->
                            reference.evidenceIds.forEach { id ->
                                TextButton(onClick = { transaction(id) }) {
                                    Text("Supporting transaction")
                                }
                            }
                        }
                    }
                }
            state.workspace
                ?.jobs
                ?.filter { it.type == "assistant" && it.status != "succeeded" }
                ?.forEach { job ->
                    InsightPill("Assistant request · ${job.status.replace('_',' ')}")
                }
            TextButton(onClick = { scope.launch { repo.refresh() } }) {
                Text("Refresh conversation")
            }
            if (
                answer.isNotEmpty() &&
                    (answerJobId == null ||
                        state.workspace?.jobs?.none { it.id == answerJobId } != false)
            )
                MoneyCard { Text(answer) }
            if (asking) CircularProgressIndicator()
            if (state.workspace?.capabilities?.ai != true)
                Text(
                    "AI isn't enabled in this environment. Saved records remain available in Activity."
                )
            OutlinedTextField(
                question,
                { question = it },
                Modifier.fillMaxWidth(),
                label = { Text("Ask Sprout") },
                maxLines = 5,
            )
            Button(
                enabled =
                    question.isNotBlank() && !asking && state.workspace?.capabilities?.ai == true,
                onClick = {
                    scope.launch {
                        asking = true
                        try {
                            val response =
                                repo.request(
                                    "/v1/assistant",
                                    repo.encode(
                                        mapOf(
                                            "question" to question,
                                            "context" to context,
                                            "requestId" to UUID.randomUUID().toString(),
                                        )
                                    ),
                                )
                            val accepted = Gson().fromJson(response, JsonObject::class.java)
                            answerJobId = accepted["id"]?.asString
                            answer =
                                accepted.get("message")?.asString
                                    ?: "Request accepted. Check the conversation for progress."
                            question = ""
                            repo.refresh()
                        } catch (e: Exception) {
                            answerJobId = null
                            answer = e.message ?: "Couldn't complete the request."
                        }
                        asking = false
                    }
                },
            ) {
                Text("Send")
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MoneyExpenseSheet(
    repo: MoneyRepository,
    initialDraft: ExpenseDraft = ExpenseDraft(),
    onSaved: () -> Unit = {},
    close: () -> Unit,
) {
    var draft by
        rememberSaveable(
            stateSaver =
                androidx.compose.runtime.saveable.Saver<ExpenseDraft, String>(
                    save = { Gson().toJson(it) },
                    restore = { Gson().fromJson(it, ExpenseDraft::class.java) },
                )
        ) {
            mutableStateOf(initialDraft)
        }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    var scanning by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val speech =
        rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result
            ->
            if (result.resultCode == Activity.RESULT_OK) {
                val text =
                    result.data
                        ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                        ?.firstOrNull()
                        .orEmpty()
                val amounts = ExpenseDraft.explicitAmounts(text)
                draft =
                    draft.copy(
                        source = "voice",
                        transcript = text,
                        amount = amounts.singleOrNull() ?: "",
                    )
                error =
                    if (amounts.size == 1) null
                    else "Review the transcript and enter the final expense total."
            } else error = "Voice capture didn't complete. You can type the expense."
        }
    var cameraPath by rememberSaveable { mutableStateOf<String?>(null) }
    fun readReceipt(uri: Uri, temporary: java.io.File? = null) {
        if (scanning) { temporary?.delete(); return }
        scanning = true
        draft = draft.copy(receiptJPEG = null, keepReceipt = false)
        scope.launch {
            try {
                val result = MoneyReceiptOcr.scan(context, uri); val text = result.text
                val extracted = MoneyReceiptExtraction.parse(text)
                draft = draft.copy(source = "scan", transcript = text.take(SproutReceiptRules.maxCharacters), amount = extracted.amount,
                    merchant = draft.merchant.ifBlank { extracted.merchant.orEmpty() }, receiptJPEG = result.jpeg, keepReceipt = false, receiptId = UUID.randomUUID().toString())
                error = if (extracted.totals.size == 1) null else "Review subtotal, tax and total. Choose or enter the final expense amount."
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (_: Exception) { error = "Couldn't read the receipt. Enter its details manually." }
            finally {
                scanning = false
                if (temporary != null) {
                    runCatching { context.revokeUriPermission(uri, android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION or android.content.Intent.FLAG_GRANT_WRITE_URI_PERMISSION) }
                    temporary.delete()
                }
            }
        }
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        val image = cameraPath?.let { java.io.File(it) }; cameraPath = null
        if (success && image?.isFile == true) {
            runCatching { androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.captures", image) }
                .onSuccess { readReceipt(it, image) }
                .onFailure { image.delete(); error = "This camera image could not be opened. Choose a photo or type the expense." }
        } else { image?.delete() }
    }
    fun takeReceipt() {
        var image: java.io.File? = null
        try {
            val directory = MoneyReceiptOcr.captureDirectory(context, repo.identity.id).apply { mkdirs() }
            val created = java.io.File.createTempFile("capture-", ".jpg", directory); image = created
            cameraPath = created.absolutePath
            camera.launch(androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.captures", created))
        } catch (_: Exception) { cameraPath = null; image?.delete(); error = "Camera is unavailable. Type the expense or choose a photo." }
    }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) takeReceipt()
        else error = "Camera access was denied. You can choose a photo or enter the receipt details manually."
    }
    val photos = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri -> if (uri != null) readReceipt(uri) }
    val receipt = remember(draft.source, draft.transcript) { if (draft.source == "scan") MoneyReceiptExtraction.parse(draft.transcript) else null }
    ModalBottomSheet(
        onDismissRequest = close,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(
            Modifier.fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                if (draft.expectedVersion == 0) "Add expense" else "Edit expense",
                style = MaterialTheme.typography.headlineMedium,
            )
            OutlinedTextField(
                draft.amount,
                { draft = draft.copy(amount = it) },
                Modifier.fillMaxWidth(),
                label = { Text("Amount in USD") },
                enabled = !scanning,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            )
            OutlinedTextField(
                draft.merchant,
                { draft = draft.copy(merchant = it) },
                Modifier.fillMaxWidth(),
                label = { Text("Merchant") },
                enabled = !scanning,
            )
            OutlinedTextField(
                draft.category,
                { draft = draft.copy(category = it) },
                Modifier.fillMaxWidth(),
                label = { Text("Category") },
                enabled = !scanning,
            )
            OutlinedTextField(
                draft.date,
                { draft = draft.copy(date = it) },
                Modifier.fillMaxWidth(),
                label = { Text("Date · YYYY-MM-DD") },
                enabled = !scanning,
            )
            ValueRow("Account", "Manual / cash")
            OutlinedTextField(
                draft.notes,
                { draft = draft.copy(notes = it) },
                Modifier.fillMaxWidth(),
                label = { Text("Notes (optional)") },
                enabled = !scanning,
                isError = draft.notes.length > 1000,
                supportingText = {
                    if (draft.notes.length > 1000) Text("Keep notes to 1,000 characters or fewer.")
                },
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = {
                        runCatching {
                                speech.launch(
                                    Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                                        .putExtra(
                                            RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                                        )
                                        .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                                        .putExtra(
                                            RecognizerIntent.EXTRA_PROMPT,
                                            "Describe your expense",
                                        )
                                )
                            }
                            .onFailure {
                                error = "Speech is unavailable. Type your expense instead."
                            }
                    }
                , enabled = !scanning && cameraPath == null) {
                    Icon(Icons.Default.Mic, null)
                    Text("Voice")
                }
                OutlinedButton(
                    onClick = {
                        runCatching {
                                if (
                                    androidx.core.content.ContextCompat.checkSelfPermission(
                                        context,
                                        android.Manifest.permission.CAMERA,
                                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                                )
                                    takeReceipt()
                                else cameraPermission.launch(android.Manifest.permission.CAMERA)
                            }
                            .onFailure {
                                error = "Camera is unavailable. Type the receipt details."
                            }
                    }
                , enabled = !scanning && cameraPath == null) {
                    Icon(Icons.Default.DocumentScanner, null)
                    Text("Camera")
                }
            }
            OutlinedButton(enabled = !scanning && cameraPath == null, onClick = { photos.launch(androidx.activity.result.PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) { Text("Scan receipt from photo") }
            if (scanning) LinearProgressIndicator(Modifier.fillMaxWidth())
            receipt?.let { suggested ->
                if (suggested.totals.size > 1) {
                    Text("Several totals were found. Check the receipt before choosing.")
                    suggested.totals.forEach { total -> TextButton(onClick = { draft = draft.copy(amount = java.math.BigDecimal.valueOf(total, 2).toPlainString()) }) { Text("Use total ${MoneyAmount(total).formatted()}") } }
                }
                suggested.merchant?.takeIf { it != draft.merchant }?.let { merchant -> TextButton(onClick = { draft = draft.copy(merchant = merchant) }) { Text("Use merchant $merchant") } }
                suggested.date?.takeIf { it != draft.date }?.let { date -> TextButton(onClick = { draft = draft.copy(date = date) }) { Text("Use receipt date $date") } }
            }
            if (draft.transcript.isNotEmpty()) {
                Text(draft.transcript, style = MaterialTheme.typography.bodySmall)
                Text(
                    "Review every field. Audio is not retained. Receipt text is read on this device; a compressed image is uploaded only if you choose to keep it.",
                    style = MaterialTheme.typography.labelSmall,
                )
            }
            if (draft.receiptJPEG != null) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(draft.keepReceipt, onCheckedChange = { draft = draft.copy(keepReceipt = it) }, enabled = !scanning && !saving)
                    Text("Keep compressed receipt with this expense", Modifier.weight(1f))
                }
                Text("The copy is private to your Sprout account and can be removed from the transaction. The original photo is unchanged. Beta limits: 100 retained copies, 50 MB per account, 650 KB per copy.", style = MaterialTheme.typography.bodySmall)
            }
            error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            Button(
                onClick = {
                    scope.launch {
                        saving = true
                        try {
                            repo.save(draft)
                            onSaved()
                            close()
                        } catch (e: Exception) {
                            error = e.message
                            saving = false
                        }
                    }
                },
                enabled = draft.transaction() != null && !saving && !scanning,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Save to Activity")
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun MoneyOnboarding(repo: MoneyRepository, state: MoneyState) {
    val w = state.workspace ?: return
    val scope = rememberCoroutineScope()
    var target by rememberSaveable { mutableStateOf("") }
    var selected by rememberSaveable { mutableStateOf(emptyList<String>()) }
    var touchedSelections by rememberSaveable { mutableStateOf(emptyList<String>()) }
    val chosen =
        w.subscriptions
            .filter {
                if (it.id in touchedSelections) it.id in selected else it.decision == "confirmed"
            }
            .map { it.id }
    var error by remember { mutableStateOf<String?>(null) }
    var connecting by remember { mutableStateOf(false) }
    val step =
        when (w.profile.onboarding) {
            "subscriptions-found" -> 3
            "your-plan" -> 4
            else -> 2
        }
    fun advance(stage: String, targetMinor: Long? = w.profile.monthlyTargetMinor) {
        scope.launch {
            try {
                repo.saveProfile(
                    w.profile.copy(onboarding = stage, monthlyTargetMinor = targetMinor)
                )
                repo.refresh()
            } catch (e: Exception) {
                error = e.message
            }
        }
    }
    MoneyPage(
        if (step == 3) "Subscriptions found"
        else if (step == 4) "Your plan" else "Connect your bank",
        state,
    ) {
        LinearProgressIndicator(progress = { step / 4f }, modifier = Modifier.fillMaxWidth())
        when (step) {
            2 -> {
                Icon(
                    Icons.Default.AccountBalance,
                    null,
                    Modifier.size(88.dp),
                    tint = MaterialTheme.colorScheme.primary,
                )
                Text(
                    "A clearer picture starts here.",
                    style = MaterialTheme.typography.headlineLarge,
                )
                Text(
                    "Connect one bank connection free. Access is read-only. Or skip and add expenses yourself."
                )
                Button(onClick = { connecting = true }) { Text("Connect a bank") }
                TextButton(onClick = { advance("subscriptions-found") }) {
                    Text(if (w.connections.isNullOrEmpty()) "Skip for now" else "Continue")
                }
            }
            3 -> {
                Amount(w.subscriptions.filter { it.id in chosen }.sumOf { it.monthlyMinor })
                Text("Estimated monthly cost of selected subscriptions")
                if (w.subscriptions.isEmpty())
                    MoneyCard {
                        Text("No recurring candidates yet.")
                        Text("Continue now and review candidates later in Insights.")
                    }
                w.subscriptions.forEach { s ->
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(
                            s.id in chosen,
                            {
                                touchedSelections = (touchedSelections + s.id).distinct()
                                selected = if (it) (selected + s.id).distinct() else selected - s.id
                            },
                        )
                        Column {
                            Text(s.merchant)
                            Text(
                                "${MoneyAmount(s.monthlyMinor).formatted()} / month · ${s.decision}",
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                    }
                }
                Text(
                    "Confirming tracks these charges. It doesn't subscribe, cancel or authorize an external action.",
                    style = MaterialTheme.typography.bodySmall,
                )
                Button(
                    onClick = {
                        scope.launch {
                            try {
                                w.subscriptions.forEach { s ->
                                    repo.enqueue(
                                        mapOf(
                                            "type" to "recurring.decide",
                                            "id" to s.id,
                                            "decision" to
                                                if (s.id in chosen) "confirmed" else "dismissed",
                                            "expectedVersion" to s.decisionVersion,
                                        ),
                                        "recurring:${s.id}",
                                    )
                                }
                                repo.saveProfile(w.profile.copy(onboarding = "your-plan"))
                                repo.refresh()
                            } catch (e: Exception) {
                                error = e.message
                            }
                        }
                    }
                ) {
                    Text("Track ${chosen.size} and continue")
                }
            }
            4 -> {
                InsightPill("A plan that starts with you.")
                Text(
                    "Your monthly spending target",
                    style = MaterialTheme.typography.headlineMedium,
                )
                OutlinedTextField(
                    target,
                    { target = it },
                    label = { Text("Your target in USD") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                )
                Text(
                    "There isn't enough synced history for a reliable historical average yet. You can change your target later."
                )
                Button(
                    onClick = {
                        val value = MoneyAmount.parse(target)
                        if (value == null) error = "Enter a monthly target."
                        else advance("complete", value)
                    }
                ) {
                    Text("Save my plan")
                }
                TextButton(onClick = { advance("complete") }) { Text("Decide later") }
            }
        }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        TextButton(onClick = { scope.launch { AppwriteNativeSession.signOut() } }) {
            Text("Sign out")
        }
    }
    if (connecting)
        AlertDialog(
            onDismissRequest = { connecting = false },
            title = { Text("Bank linking") },
            text = { MoneyBankConnection(repo, state) },
            confirmButton = { TextButton(onClick = { connecting = false }) { Text("Continue") } },
        )
}

@Composable
private fun MoneyConnection(repo: MoneyRepository, state: MoneyState) {
    MoneyPage("Linked accounts", state) { MoneyBankConnection(repo, state) }
}

@Composable
private fun MoneyProfileScreen(
    repo: MoneyRepository,
    state: MoneyState,
    connection: () -> Unit,
    privacy: (String) -> Unit,
    importTransactions: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var error by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    var notifications by remember { mutableStateOf(false) }
    var password by remember { mutableStateOf(false) }
    var support by remember { mutableStateOf(false) }
    val credentialIdentity by com.michaeldadi.sprout.services.AppwriteNativeSession.identity.collectAsState()
    if (notifications) MoneyNotificationPreferences(repo, state) { notifications = false }
    if (password) MoneyPasswordSheet(repo.identity.id) { password = false }
    if (support) MoneySupportSheet { support = false }
    MoneyPage("Profile & security", state) {
        MoneyCard {
            Icon(Icons.Default.AccountCircle, null, Modifier.size(56.dp))
            Text(
                repo.identity.name.ifEmpty { "Your Sprout" },
                style = MaterialTheme.typography.headlineSmall,
            )
            Text(repo.identity.email)
        }
        MoneyCard {
            TextButton(onClick = connection) { Text("Linked accounts · Manage") }
            ValueRow(
                "Membership",
                if (state.workspace?.entitlements?.plus == true) "Sprout Plus" else "Free",
            )
            Text(
                "Membership is server-verified. Restore and upgrade become available after billing setup.",
                style = MaterialTheme.typography.bodySmall,
            )
        }
        MoneyCard {
            if (credentialIdentity?.id == repo.identity.id && credentialIdentity?.hasPassword == true) TextButton(onClick = { password = true }) { Text("Change password") }
            TextButton(onClick = { notifications = true }) { Column(horizontalAlignment=Alignment.Start) { Text("Notification preferences"); Text("Quiet hours ${if(state.workspace?.profile?.quietHours?.enabled != false) "on" else "off"} · ${state.workspace?.profile?.timezone.orEmpty()}",style=MaterialTheme.typography.bodySmall) } }
            Text("Appearance", style = MaterialTheme.typography.titleMedium)
            Row {
                listOf("system", "light", "dark").forEach { mode ->
                    FilterChip(
                        state.workspace?.profile?.appearance == mode,
                        onClick = {
                            scope.launch {
                                try {
                                    state.workspace?.profile?.let {
                                        repo.saveProfile(it.copy(appearance = mode))
                                        repo.refresh()
                                    }
                                } catch (e: Exception) {
                                    error = e.message
                                }
                            }
                        },
                        label = { Text(mode.replaceFirstChar { it.uppercase() }) },
                    )
                }
            }
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Lock on this device", Modifier.weight(1f))
                Switch(
                    checked = deviceLockPreferences(context).getBoolean("enabled", false),
                    onCheckedChange = { value ->
                        authenticateDevice(context) { success ->
                            if (success)
                                deviceLockPreferences(context)
                                    .edit()
                                    .putBoolean("enabled", value)
                                    .apply()
                            else error = "Device authentication did not complete."
                        }
                    },
                )
            }
            Text(
                "Uses this device's biometrics or screen lock. Financial previews and screenshots are hidden while enabled.",
                style = MaterialTheme.typography.bodySmall,
            )
        }
        if (state.mutations.any { it.conflict })
            MoneyCard {
                Text("Changes needing review", style = MaterialTheme.typography.titleMedium)
                state.mutations
                    .filter { it.conflict }
                    .forEach { m ->
                        Text(repo.pendingExpenseDescription(m))
                        Text(
                            "Activity shows the server version. Your edit stays on this device until you choose what to keep."
                        )
                        if (m.entity.startsWith("goal:"))
                            Text("Review both goal versions in Budget.")
                        if (m.entity.startsWith("budget:"))
                            Text("Review both budget versions in Budget.")
                        if (m.entity.startsWith("transaction:")) MoneyEditConflictButton(repo, state, m)
                        if (m.entity.startsWith("receipt-upload:")) MoneyPendingReceiptButton(repo, m)
                        TextButton(onClick = { scope.launch { repo.useServer(m) } }) {
                            Text("Discard edit and use server version")
                        }
                    }
            }
        MoneyCard {
            TextButton(onClick = importTransactions) { Text("Import transactions") }
            TextButton(onClick = { privacy("export") }) { Text("Export my data") }
            TextButton(onClick = { privacy("delete") }) { Text("Delete my account") }
            TextButton(
                onClick = {
                    context.startActivity(
                        Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse("https://getsprout.appwrite.network/privacy"),
                        )
                    )
                }
            ) {
                Text("Privacy policy")
            }
            TextButton(
                onClick = {
                    context.startActivity(
                        Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse("https://getsprout.appwrite.network/terms"),
                        )
                    )
                }
            ) {
                Text("Terms")
            }
        }
        TextButton(onClick = { support = true }) { Text("Help & support") }
        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        OutlinedButton(
            onClick = {
                scope.launch {
                    try {
                        AppwriteNativeSession.signOut()
                    } catch (e: Exception) {
                        error = "Couldn't sign out. Try again."
                    }
                }
            }
        ) {
            Text("Sign out")
        }
    }
}

@Composable
private fun MoneyPrivacy(repo: MoneyRepository, state: MoneyState, kind: String) {
    var confirm by remember { mutableStateOf(false) }
    var status by rememberSaveable { mutableStateOf("") }
    var requestJobId by rememberSaveable { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val requests = state.workspace?.jobs?.filter { it.type == "privacy.$kind" }?.sortedByDescending { it.updatedAt ?: "" } ?: emptyList()
    MoneyPage(if (kind == "delete") "Delete account" else "Export data", state) {
        Text(
            if (kind == "delete")
                "Deletion stops new work and tracks removal of active records, attachments and provider connections. Provider and backup retention have separate timelines."
            else "Request a private archive of your financial records, settings and ready retained receipt copies."
        )
        if (
            status.isNotEmpty() &&
                (requestJobId == null ||
                    state.workspace?.jobs?.none { it.id == requestJobId } != false)
        )
            InsightPill(status)
        requests.take(10).forEach { job ->
                ValueRow("Request", job.status.replace('_', ' '))
                if (job.status == "retry")
                    Text("Your request is saved. Sprout will retry automatically.")
                else if (job.status in listOf("failed", "needs_attention"))
                    Text("This request needs support before it can be completed.")
                if (job.id == requests.firstOrNull()?.id && job.status == "succeeded") {
                    val file = job.result?.fileId
                    val bucket = job.result?.bucketId
                    if (file != null && bucket != null) {
                        job.result?.generatedAt?.let { generated ->
                            Text(
                                "Created " +
                                    runCatching {
                                            java.time.Instant.parse(generated)
                                                .atZone(java.time.ZoneId.systemDefault())
                                                .format(
                                                    java.time.format.DateTimeFormatter.ofPattern(
                                                        "MMM d, yyyy h:mm a"
                                                    )
                                                )
                                        }
                                        .getOrDefault(generated),
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                        MoneyExportButton(file, bucket, repo.identity.id)
                    }
                }
            }
        TextButton(onClick = { scope.launch { repo.refresh() } }) { Text("Refresh progress") }
        Button(onClick = { confirm = true }, enabled = !busy) {
            Text(if (kind == "delete") "Request account deletion" else "Request export")
        }
    }
    if (confirm)
        AlertDialog(
            onDismissRequest = { confirm = false },
            title = {
                Text(
                    if (kind == "delete") "Permanently delete this account?"
                    else "Create an export?"
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        confirm = false
                        busy = true
                        scope.launch {
                            try {
                                if (kind == "delete") {
                                    MoneyDeletionState.prepare(repo.identity.id)
                                    return@launch
                                }
                                val result = repo.request("/v1/privacy", repo.encode(mapOf("type" to kind, "requestId" to UUID.randomUUID().toString())))
                                val job = Gson().fromJson(result, JsonObject::class.java)
                                requestJobId = job["id"]?.asString
                                status = "Your request is ${job["status"]?.asString}."
                                repo.refresh()
                            } catch (e: Exception) {
                                requestJobId = null
                                status = e.message ?: "Couldn't submit this request."
                                if (kind == "delete") MoneyDeletionState.refresh()
                            }
                            busy = false
                        }
                    }
                ) {
                    Text("Confirm")
                }
            },
            dismissButton = { TextButton(onClick = { confirm = false }) { Text("Cancel") } },
        )
}
