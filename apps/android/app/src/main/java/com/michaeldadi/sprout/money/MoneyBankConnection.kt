package com.michaeldadi.sprout.money

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.unit.dp
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.plaid.link.OpenPlaidLink
import com.plaid.link.configuration.LinkTokenConfiguration
import com.plaid.link.result.LinkExit
import com.plaid.link.result.LinkSuccess
import java.util.UUID
import kotlinx.coroutines.launch

@Composable
internal fun MoneyBankConnection(repo: MoneyRepository, state: MoneyState) {
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var repairId by rememberSaveable { mutableStateOf<String?>(null) }
    var requestId by rememberSaveable { mutableStateOf(UUID.randomUUID().toString()) }
    val launcher =
        rememberLauncherForActivityResult(OpenPlaidLink()) { result ->
            when (result) {
                is LinkSuccess ->
                    scope.launch {
                        try {
                            val body =
                                repairId?.let {
                                    mapOf("connectionId" to it, "requestId" to requestId)
                                }
                                    ?: mapOf(
                                        "publicToken" to result.publicToken,
                                        "requestId" to requestId,
                                    )
                            repo.request(
                                if (repairId == null) "/v1/bank/exchange" else "/v1/bank/repaired",
                                repo.encode(body),
                            )
                            message =
                                "Connected. Historical import will continue in the background."
                            repo.refresh()
                        } catch (e: Exception) {
                            message = e.message ?: "The connection needs another attempt."
                        }
                        busy = false
                    }
                is LinkExit -> {
                    busy = false
                    message =
                        if (result.error == null)
                            "Bank linking was closed. Manual tracking remains available."
                        else
                            "Bank linking didn't complete. Try again or continue with manual tracking."
                }
            }
        }
    fun begin(id: String? = null) {
        scope.launch {
            busy = true
            repairId = id
            requestId = UUID.randomUUID().toString()
            message = null
            try {
                val body =
                    if (id == null) mapOf("platform" to "android")
                    else mapOf("platform" to "android", "connectionId" to id)
                val result =
                    repo.request(
                        if (id == null) "/v1/bank/link-token" else "/v1/bank/repair",
                        repo.encode(body),
                    )
                val token =
                    Gson().fromJson(result, JsonObject::class.java).get("link_token").asString
                launcher.launch(LinkTokenConfiguration.Builder().token(token).build())
            } catch (e: Exception) {
                busy = false
                message = e.message ?: "Bank linking could not start."
            }
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(
            "Read-only bank access. You stay in control.",
            style = MaterialTheme.typography.titleMedium,
        )
        Text(
            "Your plan includes ${state.workspace?.entitlements?.connectionLimit ?: 1} live bank connection(s). Each may include several accounts."
        )
        Button(
            onClick = { begin() },
            enabled = !busy && state.workspace?.capabilities?.linking == true,
        ) {
            Text("Connect a bank")
        }
        if (state.workspace?.capabilities?.linking != true)
            Text(
                "Bank linking has not been enabled for this environment.",
                style = MaterialTheme.typography.bodySmall,
            )
        state.workspace?.connections?.forEach { connection ->
            Text(
                "Connection · ${connection.data.status}",
                style = MaterialTheme.typography.titleMedium,
            )
            Text(
                "Token exchange and historical ingestion are separate. Import can continue after you leave this screen.",
                style = MaterialTheme.typography.bodySmall,
            )
            OutlinedButton(onClick = { begin(connection.id) }, enabled = !busy) {
                Text("Repair connection")
            }
        }
        if (busy) CircularProgressIndicator()
        message?.let { Text(it) }
        TextButton(onClick = { scope.launch { repo.refresh() } }) {
            Text("Refresh connection status")
        }
    }
}
