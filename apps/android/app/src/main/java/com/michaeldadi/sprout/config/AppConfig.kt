package com.michaeldadi.sprout.config

/**
 * Central configuration object for the app
 * Mirrors the iOS AppConfig.swift structure
 */
object AppConfig {
    // AWS Configuration - These will be populated from environment/build config
    const val awsRegion = "us-east-1" // TODO: Update with actual values from CDK deployment
    const val cognitoUserPoolId = "us-east-1_XXXXXXXXX" // TODO: Update with actual values from CDK deployment
    const val cognitoClientId = "XXXXXXXXXXXXXXXXXXXXXXXXXX" // TODO: Update with actual values from CDK deployment

    // Google Sign In Configuration
    const val googleSignInClientId = "580971148783-b04rqp82bnk3qv478l0bo0jtdunu4kkc.apps.googleusercontent.com"

    // Apple Sign In Configuration
    const val appleSignInServiceId = "com.services.michaeldadi.sprout"

    // API Configuration
    const val apiBaseUrl = "https://api.getsprout.io" // TODO: Update with actual API base URL

    // App Configuration
    const val appName = "Sprout"
    const val supportEmail = "support@sprout.com"
    const val termsUrl = "https://getsprout.io/terms"
    const val privacyUrl = "https://getsprout.io/privacy"
}
