package com.michaeldadi.sprout.services

import android.content.Context
import io.appwrite.Client

object AppwriteConnection {
    private const val endpoint = "https://nyc.cloud.appwrite.io/v1"
    private const val projectId = "6af0e4b00015b4aa04e3"

    private lateinit var client: Client

    fun initialize(context: Context) {
        client = Client(context.applicationContext)
            .setEndpoint(endpoint)
            .setProject(projectId)
    }

    suspend fun ping(): String = client.ping()
}
