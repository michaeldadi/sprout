package com.michaeldadi.sprout.services

import android.app.Application
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.plaid.link.Plaid
import com.plaid.link.PlaidHandler
import com.plaid.link.configuration.LinkTokenConfiguration
import com.plaid.link.result.LinkErrorCode
import com.plaid.link.result.LinkExit
import com.plaid.link.result.LinkSuccess
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Service for handling Plaid Link integration
 * Manages the PlaidHandler lifecycle and callback processing
 */
class PlaidService(application: Application) : AndroidViewModel(application) {

    // State management
    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _linkResult = MutableStateFlow<PlaidLinkResult?>(null)
    val linkResult: StateFlow<PlaidLinkResult?> = _linkResult.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    private var plaidHandler: PlaidHandler? = null

    /**
     * Initialize Plaid Link with a link token
     * @param linkToken The link token obtained from your backend
     */
    fun initializePlaid(linkToken: String) {
        viewModelScope.launch {
            try {
                _isLoading.value = true
                _error.value = null

                val linkTokenConfiguration = LinkTokenConfiguration.Builder()
                    .token(linkToken)
                    .build()

                plaidHandler = Plaid.create(getApplication(), linkTokenConfiguration)

            } catch (e: Exception) {
                _error.value = "Failed to initialize Plaid: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }

    /**
     * Launch Plaid Link with callback
     * This should be called from an Activity context
     */
    fun launchPlaidLink(
        activity: ComponentActivity,
        callback: PlaidLinkCallback
    ) {
        plaidHandler?.let { handler ->
            try {
                val intent = handler.open(activity)
                val launcher = activity.activityResultRegistry.register(
                    "plaid_link_${System.currentTimeMillis()}",
                    ActivityResultContracts.StartActivityForResult()
                ) { result ->
                    val linkResult = handler.to(result.data)
                    when (linkResult) {
                        is LinkSuccess -> {
                            val successResult = PlaidLinkResult.Success(
                                publicToken = linkResult.publicToken,
                                metadata = PlaidLinkMetadata(
                                    institutionId = linkResult.metadata.institution?.id,
                                    institutionName = linkResult.metadata.institution?.name,
                                    accountIds = emptyList(), // Accounts are available after token exchange on backend
                                    linkSessionId = linkResult.metadata.linkSessionId
                                )
                            )
                            handleLinkSuccess(successResult)
                            callback.onSuccess(successResult)
                        }
                        is LinkExit -> {
                            val exitResult = PlaidLinkResult.Exit(
                                error = linkResult.error?.let { error ->
                                    PlaidLinkError(
                                        errorCode = error.errorCode,
                                        errorMessage = error.errorMessage,
                                        displayMessage = error.displayMessage
                                    )
                                },
                                metadata = PlaidLinkMetadata(
                                    institutionId = linkResult.metadata.institution?.id,
                                    institutionName = linkResult.metadata.institution?.name,
                                    accountIds = emptyList(), // Accounts are available after token exchange on backend
                                    linkSessionId = linkResult.metadata.linkSessionId
                                )
                            )
                            handleLinkExit(exitResult)
                            callback.onExit(exitResult)
                        }
                    }
                }
                launcher.to(intent)
            } catch (e: Exception) {
                _error.value = "Failed to launch Plaid Link: ${e.message}"
            }
        } ?: run {
            _error.value = "Plaid not initialized. Call initializePlaid() first."
        }
    }

    /**
     * Handle successful Plaid Link completion
     */
    private fun handleLinkSuccess(linkSuccess: PlaidLinkResult.Success) {
        viewModelScope.launch {
            _linkResult.value = linkSuccess
        }
    }

    /**
     * Handle Plaid Link exit (user cancelled or error occurred)
     */
    private fun handleLinkExit(linkExit: PlaidLinkResult.Exit) {
        viewModelScope.launch {
            _linkResult.value = linkExit
        }
    }

    /**
     * Clear the current link result
     */
    fun clearLinkResult() {
        _linkResult.value = null
    }

    /**
     * Clear any error state
     */
    fun clearError() {
        _error.value = null
    }

    override fun onCleared() {
        super.onCleared()
        plaidHandler = null
    }
}

/**
 * Sealed class representing the result of a Plaid Link flow
 */
sealed class PlaidLinkResult {
    data class Success(
        val publicToken: String,
        val metadata: PlaidLinkMetadata
    ) : PlaidLinkResult()

    data class Exit(
        val error: PlaidLinkError?,
        val metadata: PlaidLinkMetadata
    ) : PlaidLinkResult()
}

/**
 * Data class containing metadata from Plaid Link
 */
data class PlaidLinkMetadata(
    val institutionId: String?,
    val institutionName: String?,
    val accountIds: List<String>,
    val linkSessionId: String?
)

/**
 * Data class representing a Plaid Link error
 */
data class PlaidLinkError(
  val errorCode: LinkErrorCode,
  val errorMessage: String,
  val displayMessage: String?
)

/**
 * Interface for handling Plaid Link callbacks
 * Implement this in your Activity or Compose screen
 */
interface PlaidLinkCallback {
    fun onSuccess(result: PlaidLinkResult.Success)
    fun onExit(result: PlaidLinkResult.Exit)
}
