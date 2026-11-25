package com.michaeldadi.sprout.money

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.gson.Gson
import com.google.gson.JsonParser
import com.michaeldadi.sprout.config.AppConfig
import com.michaeldadi.sprout.services.AppwriteNativeSession
import com.michaeldadi.sprout.services.AppwriteNativeAuth
import com.michaeldadi.sprout.services.AppwriteConnection
import io.appwrite.enums.ExecutionMethod
import io.appwrite.services.Functions
import java.io.File
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Mutex
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

@androidx.annotation.Keep
data class MoneyDeletionReceipt(
    val owner: String,
    val requestId: String,
    val receipt: String,
    val accepted: Boolean,
)

@androidx.annotation.Keep
data class MoneyDeletionProgress(val status: String, val steps: Steps, val retained: List<String>) {
    @androidx.annotation.Keep
    data class Steps(
        val accessRevoked: Boolean,
        val attachmentsRemoved: Boolean,
        val financialRecordsRemoved: Boolean,
        val identityAnonymized: Boolean,
    )
}

/**
 * This receipt reveals progress only. Encrypt it with a device-only Keystore key and exclude its
 * ciphertext from Android backups. Never log the token.
 */
object MoneyDeletionState {
    private lateinit var context: Context
    private var pending: MoneyDeletionReceipt? = null
    private val _active = MutableStateFlow<MoneyDeletionReceipt?>(null)
    val active = _active.asStateFlow()
    private val _blocked = MutableStateFlow(false)
    val blocked = _blocked.asStateFlow()
    private val _progress = MutableStateFlow<MoneyDeletionProgress?>(null)
    val progress = _progress.asStateFlow()
    private val _localCleanupIssue = MutableStateFlow(false)
    val localCleanupIssue = _localCleanupIssue.asStateFlow()
    private val _message = MutableStateFlow<String?>(null)
    val message = _message.asStateFlow()
    private val _needsAuthentication = MutableStateFlow(false)
    val needsAuthentication = _needsAuthentication.asStateFlow()
    private val _submitting = MutableStateFlow(false)
    val submitting = _submitting.asStateFlow()
    private val submission = Mutex()
    private val gson = Gson()
    private val http =
        OkHttpClient.Builder()
            .callTimeout(java.time.Duration.ofSeconds(20))
            .cookieJar(okhttp3.CookieJar.NO_COOKIES)
            .build()

    private fun hash(text: String) =
        MessageDigest.getInstance("SHA-256").digest(text.toByteArray()).joinToString("") {
            "%02x".format(it)
        }

    private val scope
        get() = hash("${AppConfig.appwriteEndpoint}/${AppConfig.appwriteProjectId}")

    private val file
        get() = File(context.noBackupFilesDir, "sprout-privacy-$scope")

    private fun key(): SecretKey {
        val alias = "sprout.privacy.receipt.$scope"
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let {
            return it
        }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            .apply {
                init(
                    KeyGenParameterSpec.Builder(
                            alias,
                            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                        )
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setKeySize(256)
                        .build()
                )
            }
            .generateKey()
    }

    fun initialize(context: Context) {
        this.context = context.applicationContext
        if (file.exists())
            try {
                val envelope = JsonParser.parseString(file.readText()).asJsonObject
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(
                    Cipher.DECRYPT_MODE,
                    key(),
                    GCMParameterSpec(128, Base64.decode(envelope["iv"].asString, Base64.NO_WRAP)),
                )
                pending =
                    gson.fromJson(
                        String(
                            cipher.doFinal(Base64.decode(envelope["data"].asString, Base64.NO_WRAP))
                        ),
                        MoneyDeletionReceipt::class.java,
                    )
                val saved = checkNotNull(pending)
                require(saved.owner.isNotBlank() && runCatching { UUID.fromString(saved.requestId) }.isSuccess && saved.receipt.matches(Regex("^[A-Za-z0-9_-]{43}$")))
                _active.value = saved
            } catch (_: Exception) {
                _blocked.value = true
                _message.value =
                    "Your private progress receipt could not be opened. Contact support; financial screens remain hidden."
            }
    }

    private fun persist(value: MoneyDeletionReceipt) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val data = cipher.doFinal(gson.toJson(value).toByteArray())
        val encoded =
            gson.toJson(
                mapOf(
                    "iv" to Base64.encodeToString(cipher.iv, Base64.NO_WRAP),
                    "data" to Base64.encodeToString(data, Base64.NO_WRAP),
                )
            )
        val atomic = android.util.AtomicFile(file)
        val stream = atomic.startWrite()
        try {
            stream.write(encoded.toByteArray())
            atomic.finishWrite(stream)
        } catch (error: Exception) {
            atomic.failWrite(stream)
            throw error
        }
        pending = value
    }

    fun prepare(owner: String): MoneyDeletionReceipt {
        check(!_blocked.value) { "Your previous privacy receipt needs review." }
        pending?.let {
            require(it.owner == owner) { "A previous privacy request needs review." }
            return it
        }
        val bytes = ByteArray(32).also { SecureRandom().nextBytes(it) }
        return MoneyDeletionReceipt(
                owner,
                UUID.randomUUID().toString(),
                Base64.encodeToString(
                    bytes,
                    Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
                ),
                false,
            )
            .also { persist(it); _active.value = it }
    }

    suspend fun retrySubmission(email: String? = null, password: String? = null) {
        if (!submission.tryLock()) return
        try {
            val saved = pending ?: return
            if (saved.accepted) return
            _submitting.value = true
            refresh()
            if (pending?.accepted == true) return
            try {
                if (email != null && password != null) AppwriteNativeSession.signIn(email, password, false, "")
                val identity = try { AppwriteNativeAuth.restore() } catch (error: Exception) {
                    if (error is io.appwrite.exceptions.AppwriteException && error.code in listOf(401, 403)) _needsAuthentication.value = true
                    throw error
                }
                if (identity.id != saved.owner) {
                    runCatching { AppwriteNativeSession.signOut() }
                    _needsAuthentication.value = true
                    _message.value = "Sign in to the account that requested deletion. This receipt cannot affect another account."
                    return
                }
                _needsAuthentication.value = false
                val execution = Functions(AppwriteConnection.client()).createExecution(
                    functionId = "sprout-api", async = false, path = "/v1/privacy", method = ExecutionMethod.POST,
                    headers = mapOf("x-sprout-account" to saved.owner),
                    body = gson.toJson(mapOf("type" to "delete", "requestId" to saved.requestId, "receipt" to saved.receipt, "_account" to saved.owner)),
                )
                check(execution.responseStatusCode in 200..299)
                accept(saved)
                refresh()
            } catch (cancelled: kotlinx.coroutines.CancellationException) { throw cancelled }
            catch (_: Exception) {
                _message.value = if (_needsAuthentication.value) "Sign in again to retry this saved deletion request. If access was already revoked, refresh progress instead."
                else "Acceptance could not be confirmed. Your original request is saved; retry when connected."
            }
        } finally { _submitting.value = false; submission.unlock() }
    }

    fun accept(value: MoneyDeletionReceipt) {
        val accepted = value.copy(accepted = true)
        persist(accepted)
        _active.value = accepted
    }

    fun cleanLocal(owner: String) {
        val accountScope =
            hash("${AppConfig.appwriteEndpoint}/${AppConfig.appwriteProjectId}/$owner")
        check(
            context.deleteDatabase("sprout-money-v1-$accountScope") ||
                !context.getDatabasePath("sprout-money-v1-$accountScope").exists()
        )
        MoneyReceiptArchive.erase(context, owner)
        check(
            File(context.cacheDir, "sprout-exports/$accountScope").let {
                !it.exists() || it.deleteRecursively()
            }
        )
        check(MoneyReceiptOcr.captureDirectory(context, owner).let { !it.exists() || it.deleteRecursively() })
    }

    fun cleanup() {
        active.value?.let { owner ->
            _localCleanupIssue.value = runCatching { cleanLocal(owner.owner) }.isFailure
        }
    }

    suspend fun refresh() {
        val saved = pending ?: return
        if (saved.accepted) cleanup()
        try {
            val progress =
                withContext(Dispatchers.IO) {
                    val body =
                        gson.toJson(
                            mapOf(
                                "async" to false,
                                "method" to "POST",
                                "path" to "/",
                                "body" to gson.toJson(mapOf("receipt" to saved.receipt)),
                            )
                        )
                    val request =
                        Request.Builder()
                            .url(
                                AppConfig.appwriteEndpoint +
                                    "/functions/sprout-privacy-status/executions"
                            )
                            .header("X-Appwrite-Project", AppConfig.appwriteProjectId)
                            .post(body.toRequestBody("application/json".toMediaType()))
                            .build()
                    http.newCall(request).execute().use { response ->
                        check(response.code == 201)
                        val envelope = JsonParser.parseString(response.body!!.string()).asJsonObject
                        check(envelope["responseStatusCode"].asInt == 200)
                        gson.fromJson(
                            envelope["responseBody"].asString,
                            MoneyDeletionProgress::class.java,
                        )
                    }
                }
            _progress.value = progress
            _message.value = null
            if (!saved.accepted) accept(saved)
        } catch (cancelled: kotlinx.coroutines.CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            _message.value =
                "Progress is temporarily unavailable. Your receipt is saved on this device."
        }
    }

    fun dismissCompleted() {
        val saved = _active.value ?: return
        if (_progress.value?.status != "active_data_removed" || !saved.accepted) return
        try { cleanLocal(saved.owner); _localCleanupIssue.value = false }
        catch (_: Exception) { _localCleanupIssue.value = true; _message.value = "Local cached records could not be removed. Retry cleanup before returning to welcome."; return }
        if (!file.delete() && file.exists()) { _message.value = "Your completed receipt could not be cleared. Unlock this device and try again."; return }
        pending = null
        _active.value = null
        _progress.value = null
        _message.value = null
    }
}

@Composable
fun MoneyDeletionProgressScreen() {
    val progress by MoneyDeletionState.progress.collectAsState()
    val message by MoneyDeletionState.message.collectAsState()
    val cleanupIssue by MoneyDeletionState.localCleanupIssue.collectAsState()
    val active by MoneyDeletionState.active.collectAsState()
    val needsAuthentication by MoneyDeletionState.needsAuthentication.collectAsState()
    val submitting by MoneyDeletionState.submitting.collectAsState()
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var foreground by remember {
        mutableStateOf(lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED))
    }
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            foreground = event.targetState.isAtLeast(Lifecycle.State.RESUMED)
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(active) {
        active?.takeIf { it.accepted }?.let {
            MoneyDeletionState.cleanup()
            runCatching { AppwriteNativeSession.signOut() }
        }
    }
    LaunchedEffect(foreground) {
        if (foreground) {
            MoneyDeletionState.retrySubmission()
            repeat(120) {
                MoneyDeletionState.refresh()
                if (
                    MoneyDeletionState.progress.value?.status in
                        listOf("active_data_removed", "needs_attention")
                )
                    return@LaunchedEffect
                delay(5000)
            }
        }
    }
    Surface(color = MaterialTheme.colorScheme.background, modifier = Modifier.fillMaxSize()) {
        Column(
            Modifier.safeDrawingPadding().padding(20.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Text("Account deletion", style = MaterialTheme.typography.headlineLarge)
            Text(if (active?.accepted == true) "Your request was accepted. New financial work is stopped." else "Your deletion request is saved on this device. Waiting for the server to confirm acceptance; financial screens remain hidden.")
            progress?.let { p ->
                Text(
                    if (p.status == "active_data_removed") "Active financial data removed"
                    else p.status.replace('_', ' ').replaceFirstChar { it.uppercase() },
                    style = MaterialTheme.typography.headlineSmall,
                )
                val steps =
                    listOf(
                        "Account access revoked" to p.steps.accessRevoked,
                        "Private attachments removed" to p.steps.attachmentsRemoved,
                        "Financial records removed" to p.steps.financialRecordsRemoved,
                        "Identity anonymized" to p.steps.identityAnonymized,
                    )
                steps.forEach { (label, done) -> Text("${if(done) "✓" else "Pending:"} $label") }
                if (p.status == "needs_attention")
                    Text("This request needs support before the remaining steps can finish.")
                p.retained.forEach { Text(it, style = MaterialTheme.typography.bodySmall) }
                if (p.status == "active_data_removed")
                    Button(onClick = { MoneyDeletionState.dismissCompleted() }) {
                        Text("Return to welcome")
                    }
            } ?: CircularProgressIndicator()
            if (cleanupIssue)
                Text(
                    "Server deletion continues. Local cached records need cleanup on this device. Restart Sprout or contact support."
                )
            message?.let { Text(it) }
            TextButton(onClick = { scope.launch { MoneyDeletionState.refresh() } }) {
                Text("Refresh deletion progress")
            }
            if (active?.accepted == false) {
                if (needsAuthentication) {
                    OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("Account email") }, singleLine = true,
                        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = androidx.compose.ui.text.input.KeyboardType.Email))
                    OutlinedTextField(value = password, onValueChange = { password = it }, label = { Text("Password") }, singleLine = true,
                        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = androidx.compose.ui.text.input.KeyboardType.Password),
                        visualTransformation = androidx.compose.ui.text.input.PasswordVisualTransformation())
                }
                Button(enabled = !submitting && (!needsAuthentication || (email.isNotBlank() && password.isNotBlank())), onClick = {
                    val secret = password; password = ""
                    scope.launch { MoneyDeletionState.retrySubmission(if(needsAuthentication) email else null, if(needsAuthentication) secret else null) }
                }) { Text("Retry original deletion request") }
            }
        }
    }
}
