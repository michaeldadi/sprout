package com.michaeldadi.sprout.services

import com.michaeldadi.sprout.config.AppConfig
import io.appwrite.Client
import io.appwrite.services.Account
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

data class AppwriteAccountIdentity(val id: String, val email: String, val name: String)

/** Exchanges a native Google ID token for an Appwrite session without retaining the provider token. */
object AppwriteNativeAuth {
    suspend fun signInWithGoogle(idToken: String, name: String?): AppwriteAccountIdentity {
        exchangeGoogleIdToken(AppwriteConnection.client(), AppConfig.appwriteProjectId, idToken, name)
        return identity(AppwriteConnection.account())
    }

    internal suspend fun exchangeGoogleIdToken(client: Client, projectId: String, idToken: String, name: String?) {
        // SDK 25 predates this endpoint; use its public Client.call so the normal
        // cookie jar receives the session without a browser redirect.
        client.call(
            method = "POST",
            path = "/account/sessions/id-token",
            headers = mapOf(
                "X-Appwrite-Project" to projectId,
                "X-Appwrite-Response-Format" to "2.3.0",
                "content-type" to "application/json",
                "accept" to "application/json"
            ),
            params = mapOf("provider" to "google", "idToken" to idToken, "name" to name),
            responseType = Any::class.java
        )
    }

    suspend fun restore(): AppwriteAccountIdentity = identity(AppwriteConnection.account())

    suspend fun signOut() {
        AppwriteConnection.account().deleteSession("current")
    }

    private suspend fun identity(account: Account): AppwriteAccountIdentity {
        val user = account.get()
        return AppwriteAccountIdentity(id = user.id, email = user.email, name = user.name)
    }
}

/** Kept separate from Cognito until financial records move to Appwrite. */
object AppwriteNativeSession {
    private val _identity = MutableStateFlow<AppwriteAccountIdentity?>(null)
    val identity = _identity.asStateFlow()

    suspend fun restore() {
        if (_identity.value != null) return
        val restored = runCatching { AppwriteNativeAuth.restore() }.getOrNull()
        if (_identity.value == null) _identity.value = restored
    }

    suspend fun signInWithGoogle(idToken: String, name: String?) {
        _identity.value = AppwriteNativeAuth.signInWithGoogle(idToken, name)
    }

    suspend fun signOut() {
        AppwriteNativeAuth.signOut()
        _identity.value = null
    }
}
