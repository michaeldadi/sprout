package com.michaeldadi.sprout.ui.components

import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.michaeldadi.sprout.services.PlaidLinkCallback
import com.michaeldadi.sprout.services.PlaidLinkResult
import com.michaeldadi.sprout.services.PlaidService

/**
 * Composable button that integrates with Plaid Link
 * Handles the complete flow of initializing Plaid and launching the Link experience
 * 
 * @param linkToken The Plaid link token obtained from your backend
 * @param onSuccess Callback for successful link completion
 * @param onExit Callback for link exit (cancellation or error)
 * @param onError Callback for initialization or launch errors
 * @param modifier Modifier for the button
 * @param enabled Whether the button is enabled
 * @param buttonText Text to display on the button
 */
@Composable
fun PlaidLinkButton(
    linkToken: String,
    onSuccess: (PlaidLinkResult.Success) -> Unit,
    onExit: (PlaidLinkResult.Exit) -> Unit,
    onError: (String) -> Unit = {},
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    buttonText: String = "Connect Bank Account"
) {
    val context = LocalContext.current
    val activity = context as? ComponentActivity
    val plaidService: PlaidService = viewModel()
    
    val isLoading by plaidService.isLoading.collectAsState()
    val error by plaidService.error.collectAsState()
    val linkResult by plaidService.linkResult.collectAsState()

    // Handle errors
    LaunchedEffect(error) {
        error?.let { errorMessage ->
            onError(errorMessage)
            plaidService.clearError()
        }
    }

    // Handle link results
    LaunchedEffect(linkResult) {
        linkResult?.let { result ->
            when (result) {
                is PlaidLinkResult.Success -> onSuccess(result)
                is PlaidLinkResult.Exit -> onExit(result)
            }
            plaidService.clearLinkResult()
        }
    }

    // Initialize Plaid when link token changes
    LaunchedEffect(linkToken) {
        if (linkToken.isNotBlank()) {
            plaidService.initializePlaid(linkToken)
        }
    }

    Button(
        onClick = {
            activity?.let { act ->
                plaidService.launchPlaidLink(
                    activity = act,
                    callback = object : PlaidLinkCallback {
                        override fun onSuccess(result: PlaidLinkResult.Success) {
                            // Handled by LaunchedEffect above
                        }

                        override fun onExit(result: PlaidLinkResult.Exit) {
                            // Handled by LaunchedEffect above
                        }
                    }
                )
            } ?: run {
                onError("Activity context required for Plaid Link")
            }
        },
        enabled = enabled && !isLoading && linkToken.isNotBlank(),
        modifier = modifier
    ) {
        if (isLoading) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    strokeWidth = 2.dp
                )
                Text("Loading...")
            }
        } else {
            Text(buttonText)
        }
    }
}

/**
 * Enhanced Plaid Link button with custom styling and additional options
 * 
 * @param linkToken The Plaid link token obtained from your backend
 * @param onSuccess Callback for successful link completion
 * @param onExit Callback for link exit (cancellation or error)
 * @param onError Callback for initialization or launch errors
 * @param modifier Modifier for the button
 * @param enabled Whether the button is enabled
 * @param colors Button colors
 * @param contentPadding Button content padding
 * @param content Custom button content
 */
@Composable
fun PlaidLinkButtonCustom(
    linkToken: String,
    onSuccess: (PlaidLinkResult.Success) -> Unit,
    onExit: (PlaidLinkResult.Exit) -> Unit,
    onError: (String) -> Unit = {},
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    colors: ButtonColors = ButtonDefaults.buttonColors(),
    contentPadding: PaddingValues = ButtonDefaults.ContentPadding,
    content: @Composable RowScope.() -> Unit
) {
    val context = LocalContext.current
    val activity = context as? ComponentActivity
    val plaidService: PlaidService = viewModel()
    
    val isLoading by plaidService.isLoading.collectAsState()
    val error by plaidService.error.collectAsState()
    val linkResult by plaidService.linkResult.collectAsState()

    // Handle errors
    LaunchedEffect(error) {
        error?.let { errorMessage ->
            onError(errorMessage)
            plaidService.clearError()
        }
    }

    // Handle link results
    LaunchedEffect(linkResult) {
        linkResult?.let { result ->
            when (result) {
                is PlaidLinkResult.Success -> onSuccess(result)
                is PlaidLinkResult.Exit -> onExit(result)
            }
            plaidService.clearLinkResult()
        }
    }

    // Initialize Plaid when link token changes
    LaunchedEffect(linkToken) {
        if (linkToken.isNotBlank()) {
            plaidService.initializePlaid(linkToken)
        }
    }

    Button(
        onClick = {
            activity?.let { act ->
                plaidService.launchPlaidLink(
                    activity = act,
                    callback = object : PlaidLinkCallback {
                        override fun onSuccess(result: PlaidLinkResult.Success) {
                            // Handled by LaunchedEffect above
                        }

                        override fun onExit(result: PlaidLinkResult.Exit) {
                            // Handled by LaunchedEffect above
                        }
                    }
                )
            } ?: run {
                onError("Activity context required for Plaid Link")
            }
        },
        enabled = enabled && !isLoading && linkToken.isNotBlank(),
        modifier = modifier,
        colors = colors,
        contentPadding = contentPadding,
        content = content
    )
}

/**
 * Example usage composable showing how to use PlaidLinkButton
 */
@Composable
fun PlaidLinkExample() {
    var linkToken by remember { mutableStateOf("") }
    var resultMessage by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Plaid Link Integration",
            style = MaterialTheme.typography.headlineMedium
        )

        // You would typically get this from your backend
        OutlinedTextField(
            value = linkToken,
            onValueChange = { linkToken = it },
            label = { Text("Link Token") },
            placeholder = { Text("Enter your Plaid link token") },
            modifier = Modifier.fillMaxWidth()
        )

        PlaidLinkButton(
            linkToken = linkToken,
            onSuccess = { result ->
                resultMessage = "Success! Public token: ${result.publicToken}\n" +
                        "Institution: ${result.metadata.institutionName}\n" +
                        "Accounts: ${result.metadata.accountIds.size}"
            },
            onExit = { result ->
                if (result.error != null) {
                    resultMessage = "Error: ${result.error.displayMessage ?: result.error.errorMessage}"
                } else {
                    resultMessage = "User cancelled"
                }
            },
            onError = { error ->
                resultMessage = "Initialization error: $error"
            },
            modifier = Modifier.fillMaxWidth()
        )

        if (resultMessage.isNotEmpty()) {
            Card(
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = resultMessage,
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}