package com.michaeldadi.sprout.config

import com.michaeldadi.sprout.BuildConfig

/**
 * Central configuration object for the app
 * Mirrors the iOS AppConfig.swift structure
 */
object AppConfig {
    // AWS Configuration - These will be populated from environment/build config
    const val awsRegion = "us-east-1"
    const val cognitoUserPoolId = "us-east-1_acu33uaoz"
    const val cognitoClientId = "52atb5sd5p1gcn5ohlvtt9dkfp"

    // Public client identifiers are supplied by the selected build environment.
    val googleSignInClientId = BuildConfig.SPROUT_GOOGLE_WEB_CLIENT_ID.trim()
    val appwriteEndpoint = BuildConfig.SPROUT_APPWRITE_ENDPOINT.trim()
    val appwriteProjectId = BuildConfig.SPROUT_APPWRITE_PROJECT_ID.trim()

    // API Configuration
    val apiBaseUrl: String = BuildConfig.SPROUT_API_BASE_URL.trim()

    // App Configuration
    const val appName = "Sprout"
    const val supportEmail = "support@getsprout.io"
    const val termsUrl = "https://getsprout.io/terms"
    const val privacyUrl = "https://getsprout.io/privacy"
}
