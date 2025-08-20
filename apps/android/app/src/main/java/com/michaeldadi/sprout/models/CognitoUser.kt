package com.michaeldadi.sprout.models

/**
 * Data model for a Cognito user
 * Mirrors the iOS CognitoUser struct
 */
data class CognitoUser(
    val email: String,
    val accessToken: String,
    val idToken: String,
    val refreshToken: String
)