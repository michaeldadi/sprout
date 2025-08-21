package com.michaeldadi.sprout.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.core.net.toUri

class GoogleAssistantService private constructor(private val context: Context) {

    companion object {
      @Volatile
      private var INSTANCE: GoogleAssistantService? = null

      fun getInstance(context: Context): GoogleAssistantService {
        val appContext = context.applicationContext
        return INSTANCE ?: synchronized(this) {
          INSTANCE ?: GoogleAssistantService(appContext).also { INSTANCE = it }
        }
      }
    }

    var isSetupComplete by mutableStateOf(false)
        private set

    val availableActions = listOf(
        SproutAssistantAction(
            id = "add_expense",
            title = "Add Expense",
            description = "Quickly log a new expense",
            examplePhrase = "Hey Google, add expense in Sprout",
            deepLink = "sprout://add-expense"
        ),
        SproutAssistantAction(
            id = "check_balance",
            title = "Check Balance",
            description = "View account balances",
            examplePhrase = "Hey Google, check my balance in Sprout",
            deepLink = "sprout://check-balance"
        ),
        SproutAssistantAction(
            id = "recent_transactions",
            title = "Recent Transactions",
            description = "View latest spending",
            examplePhrase = "Hey Google, show recent transactions in Sprout",
            deepLink = "sprout://recent-transactions"
        ),
        SproutAssistantAction(
            id = "monthly_spending",
            title = "Monthly Spending",
            description = "View this month's expenses",
            examplePhrase = "Hey Google, how much did I spend this month in Sprout",
            deepLink = "sprout://monthly-spending"
        ),
        SproutAssistantAction(
            id = "search_transactions",
            title = "Search Transactions",
            description = "Find specific transactions",
            examplePhrase = "Hey Google, search transactions in Sprout",
            deepLink = "sprout://search-transactions"
        ),
        SproutAssistantAction(
            id = "financial_goals",
            title = "Financial Goals",
            description = "Check goal progress",
            examplePhrase = "Hey Google, check my financial goals in Sprout",
            deepLink = "sprout://financial-goals"
        )
    )

    fun handleDeepLink(intent: Intent): SproutAssistantAction? {
        val data = intent.data ?: return null
        val scheme = data.scheme
        val host = data.host

        if (scheme == "sprout") {
            Log.d("GoogleAssistantService", "Handling deep link: $data")

            return when (host) {
                "add-expense" -> {
                    val amount = data.getQueryParameter("amount")
                    val merchant = data.getQueryParameter("merchant")
                    val category = data.getQueryParameter("category")
                    Log.d("GoogleAssistantService", "Add expense: amount=$amount, merchant=$merchant, category=$category")
                    availableActions.find { it.id == "add_expense" }
                }
                "check-balance" -> {
                    Log.d("GoogleAssistantService", "Check balance requested")
                    availableActions.find { it.id == "check_balance" }
                }
                "recent-transactions" -> {
                    val limit = data.getQueryParameter("limit")
                    Log.d("GoogleAssistantService", "Recent transactions: limit=$limit")
                    availableActions.find { it.id == "recent_transactions" }
                }
                "monthly-spending" -> {
                    val month = data.getQueryParameter("month")
                    val year = data.getQueryParameter("year")
                    Log.d("GoogleAssistantService", "Monthly spending: month=$month, year=$year")
                    availableActions.find { it.id == "monthly_spending" }
                }
                "search-transactions" -> {
                    val query = data.getQueryParameter("query")
                    Log.d("GoogleAssistantService", "Search transactions: query=$query")
                    availableActions.find { it.id == "search_transactions" }
                }
                "financial-goals" -> {
                    Log.d("GoogleAssistantService", "Financial goals requested")
                    availableActions.find { it.id == "financial_goals" }
                }
                else -> null
            }
        }

        return null
    }

    fun createDeepLinkIntent(action: SproutAssistantAction, parameters: Map<String, String> = emptyMap()): Intent {
        val uri = if (parameters.isNotEmpty()) {
            val builder = action.deepLink.toUri().buildUpon()
            parameters.forEach { (key, value) ->
                builder.appendQueryParameter(key, value)
            }
            builder.build()
        } else {
          action.deepLink.toUri()
        }

        return Intent(Intent.ACTION_VIEW, uri).apply {
            setPackage(context.packageName)
        }
    }

    fun getActionFromDeepLink(uri: Uri): SproutAssistantAction? {
        return availableActions.find { action ->
          action.deepLink.toUri().host == uri.host
        }
    }

    fun extractParametersFromUri(uri: Uri): Map<String, String> {
        val parameters = mutableMapOf<String, String>()
        uri.queryParameterNames.forEach { param ->
            uri.getQueryParameter(param)?.let { value ->
                parameters[param] = value
            }
        }
        return parameters
    }

    fun markSetupComplete() {
        isSetupComplete = true
    }
}

data class SproutAssistantAction(
    val id: String,
    val title: String,
    val description: String,
    val examplePhrase: String,
    val deepLink: String
)
