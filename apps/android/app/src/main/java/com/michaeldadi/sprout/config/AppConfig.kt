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
    const val googleSignInClientId = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" // TODO: Update with actual Google client ID
    
    // API Configuration
    const val apiBaseUrl = "https://api.sprout.com" // TODO: Update with actual API base URL
    
    // App Configuration
    const val appName = "Sprout"
    const val supportEmail = "support@sprout.com"
    const val termsUrl = "https://your-app.com/terms"
    const val privacyUrl = "https://your-app.com/privacy"
}