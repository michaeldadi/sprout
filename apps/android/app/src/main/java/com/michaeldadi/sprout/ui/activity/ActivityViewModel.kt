package com.michaeldadi.sprout.ui.activity

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.michaeldadi.sprout.data.database.SproutDatabase
import com.michaeldadi.sprout.data.repository.TransactionRepository
import com.michaeldadi.sprout.models.CognitoUser
import java.util.Base64
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch
import org.json.JSONObject

class ActivityViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = TransactionRepository(SproutDatabase.getDatabase(application).transactionDao(), application)
    private val _state = MutableStateFlow<ActivityLoadState>(ActivityLoadState.Loading)
    val state: StateFlow<ActivityLoadState> = _state
    private var userId: String? = null
    private var collection: Job? = null

    fun bindUser(user: CognitoUser?, force: Boolean = false) {
        val subject = user?.idToken?.let(::subjectFromIdToken)
        if (!force && subject == userId && collection != null) return
        collection?.cancel()
        userId = subject
        if (subject == null) {
            _state.value = ActivityLoadState.Failed("Account identity is unavailable. Sign in again to view saved activity.")
            return
        }
        _state.value = ActivityLoadState.Loading
        collection = viewModelScope.launch {
            repository.getTransactionsByUserId(subject)
                .catch { _state.value = ActivityLoadState.Failed("Saved activity could not be read. Try again.") }
                .collect { records -> _state.value = ActivityLoadState.Ready(records.map { it.toActivityItem() }) }
        }
    }

    fun retry(user: CognitoUser?) = bindUser(user, force = true)

    /** Prevent a previous account's cached state from drawing during an auth change. */
    fun stateFor(user: CognitoUser?, currentState: ActivityLoadState): ActivityLoadState {
        if (user == null) return ActivityLoadState.Loading
        val subject = user?.idToken?.let(::subjectFromIdToken)
            ?: return ActivityLoadState.Failed("Account identity is unavailable. Sign in again to view saved activity.")
        return if (subject == userId) currentState else ActivityLoadState.Loading
    }

    private fun subjectFromIdToken(token: String): String? = runCatching {
        val payload = token.split('.').getOrNull(1) ?: return null
        JSONObject(String(Base64.getUrlDecoder().decode(payload), Charsets.UTF_8))
            .optString("sub").takeIf { it.isNotBlank() }
    }.getOrNull()
}
