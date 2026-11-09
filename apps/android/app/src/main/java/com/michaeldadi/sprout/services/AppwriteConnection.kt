package com.michaeldadi.sprout.services

import android.content.Context
import com.michaeldadi.sprout.config.AppConfig
import io.appwrite.Client
import io.appwrite.services.Account
import java.net.URI

/** One Appwrite client per process so its session follows the selected build environment. */
object AppwriteConnection {
    private var configuredClient: Client? = null

    fun initialize(context: Context) {
        val endpoint = AppConfig.appwriteEndpoint
        val projectId = AppConfig.appwriteProjectId
        if (endpoint.isBlank() || projectId.isBlank()) {
            configuredClient = null
            return
        }
        val uri = runCatching { URI(endpoint) }.getOrNull()
        if (uri?.scheme != "https" || uri.host == null || uri.path != "/v1" || uri.query != null || projectId.contains('/')) {
            configuredClient = null
            return
        }
        configuredClient = Client(context.applicationContext)
            .setEndpoint(endpoint)
            .setProject(projectId)
    }

    fun client(): Client = configuredClient ?: error("Appwrite is not configured for this build")

    fun account(): Account = Account(client())

    suspend fun ping(): String = client().ping()
}
