package com.michaeldadi.sprout.models

/**
 * Data model for stored authentication tokens
 * Mirrors the iOS StoredTokens struct
 */
data class StoredTokens(
    val accessToken: String,
    val idToken: String,
    val refreshToken: String
)