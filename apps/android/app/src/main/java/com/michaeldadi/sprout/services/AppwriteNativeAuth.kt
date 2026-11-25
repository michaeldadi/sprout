package com.michaeldadi.sprout.services

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.michaeldadi.sprout.config.AppConfig
import io.appwrite.Client
import io.appwrite.exceptions.AppwriteException
import io.appwrite.services.Account
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

@androidx.annotation.Keep
data class AppwriteAccountIdentity(val id: String, val email: String, val name: String, val hasPassword: Boolean? = null)

/**
 * Exchanges a native Google ID token for an Appwrite session without retaining the provider token.
 */
object AppwriteNativeAuth {
    suspend fun signInWithGoogle(idToken: String, name: String?): AppwriteAccountIdentity {
        exchangeGoogleIdToken(
            AppwriteConnection.client(),
            AppConfig.appwriteProjectId,
            idToken,
            name,
        )
        return identity(AppwriteConnection.account())
    }

    internal suspend fun exchangeGoogleIdToken(
        client: Client,
        projectId: String,
        idToken: String,
        name: String?,
    ) {
        // SDK 25 predates this endpoint; use its public Client.call so the normal
        // cookie jar receives the session without a browser redirect.
        client.call(
            method = "POST",
            path = "/account/sessions/id-token",
            headers =
                mapOf(
                    "X-Appwrite-Project" to projectId,
                    "X-Appwrite-Response-Format" to "2.3.0",
                    "content-type" to "application/json",
                    "accept" to "application/json",
                ),
            params = mapOf("provider" to "google", "idToken" to idToken, "name" to name),
            responseType = Any::class.java,
        )
    }

    suspend fun restore(): AppwriteAccountIdentity = identity(AppwriteConnection.account())

    suspend fun signOut() {
        AppwriteConnection.account().deleteSession("current")
    }

    private suspend fun identity(account: Account): AppwriteAccountIdentity {
        val user = account.get()
        return AppwriteAccountIdentity(id = user.id, email = user.email, name = user.name, hasPassword = user.passwordUpdate.isNotEmpty())
    }
}

/**
 * Cached identity permits offline access; server authentication and account markers remain
 * authoritative for every download and upload.
 */
object AppwriteNativeSession {
    private val _identity = MutableStateFlow<AppwriteAccountIdentity?>(null)
    val identity = _identity.asStateFlow()
    private val _restoring = MutableStateFlow(true)
    val restoring = _restoring.asStateFlow()
    private var preferences: SharedPreferences? = null
    private val generation = AtomicLong()
    private val gson = Gson()

    fun initialize(context: Context) {
        val scope =
            MessageDigest.getInstance("SHA-256")
                .digest(
                    "${AppConfig.appwriteEndpoint}/${AppConfig.appwriteProjectId}".toByteArray()
                )
                .joinToString("") { "%02x".format(it) }
        preferences =
            context.applicationContext.getSharedPreferences(
                "sprout-identity-$scope",
                Context.MODE_PRIVATE,
            )
    }

    private fun remember(value: AppwriteAccountIdentity?) {
        _identity.value = value
        preferences
            ?.edit()
            ?.apply {
                if (value == null) remove("identity") else putString("identity", gson.toJson(value))
            }
            ?.commit()
    }

    private suspend fun prepareSignIn() {
        generation.incrementAndGet()
        if (preferences?.getBoolean("signedOut", false) == true) {
            try {
                AppwriteNativeAuth.signOut()
            } catch (error: AppwriteException) {
                if (error.code != 401) throw error
            }
        }
    }

    private fun signedIn(value: AppwriteAccountIdentity) {
        preferences?.edit()?.remove("signedOut")?.commit()
        remember(value)
    }

    suspend fun restore() {
        _restoring.value = true
        try { restoreIdentity() } finally { _restoring.value = false }
    }

    private suspend fun restoreIdentity() {
        if (_identity.value != null) return
        if (preferences?.getBoolean("signedOut", false) == true) return
        val attempt = generation.get()
        _identity.value =
            runCatching {
                    gson.fromJson(
                        preferences?.getString("identity", null),
                        AppwriteAccountIdentity::class.java,
                    )
                }
                .getOrNull()
        try {
            val restored = AppwriteNativeAuth.restore()
            if (generation.get() == attempt) remember(restored)
        } catch (error: AppwriteException) {
            if (
                generation.get() == attempt &&
                    error.code in 400..499 &&
                    error.code !in listOf(408, 429)
            )
                remember(null)
        } catch (_: Exception) {
            /* Keep prior identity for offline cached records. */
        }
    }

    suspend fun signInWithGoogle(idToken: String, name: String?) {
        prepareSignIn()
        signedIn(AppwriteNativeAuth.signInWithGoogle(idToken, name))
    }

    suspend fun signOut() {
        com.michaeldadi.sprout.money.MoneyAnalytics.reset()
        generation.incrementAndGet()
        preferences?.edit()?.putBoolean("signedOut", true)?.commit()
        remember(null)
        AppwriteNativeAuth.signOut()
    }

    suspend fun signIn(email: String, password: String, create: Boolean, name: String) {
        prepareSignIn()
        val account = AppwriteConnection.account()
        if (create) account.create(io.appwrite.ID.unique(), email, password, name)
        account.createEmailPasswordSession(email, password)
        signedIn(AppwriteNativeAuth.restore())
    }
}
