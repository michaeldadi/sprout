package com.michaeldadi.sprout.config

/**
 * Cognito configuration object
 * Mirrors the iOS CognitoConfig.swift structure
 */
object CognitoConfig {
    // These values will be populated from CDK outputs
    val region = AppConfig.awsRegion
    val userPoolId = AppConfig.cognitoUserPoolId
    val clientId = AppConfig.cognitoClientId
}