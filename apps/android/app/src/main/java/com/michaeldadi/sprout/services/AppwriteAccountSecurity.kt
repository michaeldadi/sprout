package com.michaeldadi.sprout.services

import com.michaeldadi.sprout.config.AppConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.CookieJar
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/** A verified JWT and cookie-free connection bind updates to one account even
 * if the app's shared sign-in session changes while a request is in flight. */
internal class AppwriteAccountSecurity private constructor(private val owner: String, private val token: String) {
    private val transport = OkHttpClient.Builder().cookieJar(CookieJar.NO_COOKIES).followRedirects(false).followSslRedirects(false).callTimeout(30, TimeUnit.SECONDS).build()
    companion object {
        suspend fun verified(owner: String): AppwriteAccountSecurity = withContext(Dispatchers.IO) {
            check(AppwriteNativeSession.identity.value?.id == owner) { "Sign in to this account again." }
            val jwt = AppwriteConnection.account().createJWT().jwt
            val session = AppwriteAccountSecurity(owner, jwt)
            check(session.call("GET", "account").optString("passwordUpdate").isNotEmpty()) { "This account does not have a password credential." }
            session
        }
    }
    suspend fun changePassword(current: String, new: String) = withContext(Dispatchers.IO) {
        check(AppwriteNativeSession.identity.value?.id == owner) { "The signed-in account changed. Reopen account security." }
        call("PATCH", "account/password", JSONObject().put("oldPassword", current).put("password", new))
        Unit
    }
    private fun call(method: String, path: String, body: JSONObject? = null): JSONObject {
        val request = Request.Builder().url("${AppConfig.appwriteEndpoint.trimEnd('/')}/$path").header("X-Appwrite-Project", AppConfig.appwriteProjectId).header("X-Appwrite-JWT", token).method(method, body?.toString()?.toRequestBody("application/json".toMediaType())).build()
        val response = try { transport.newCall(request).execute() } catch (_: Exception) {
            error(if (method == "PATCH") "The password update could not be confirmed. Try signing in with your new password before making another change." else "Connect to Sprout to verify your account security.")
        }
        return response.use {
            val raw = it.body?.string() ?: error("Account security could not be verified.")
            val kind = runCatching { JSONObject(raw).optString("type") }.getOrDefault("")
            check(it.code == 200) { if (kind.startsWith("user_jwt") || kind == "user_session_not_found") "Your session expired. Sign in again." else "The change was not confirmed. Check your current password and your account's password requirements, then retry." }
            val facts = JSONObject(raw)
            check(facts.optString("\$id") == owner) { "Account ownership could not be verified." }
            facts
        }
    }
}
