package com.michaeldadi.sprout.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Sprout's semantic palette. MaterialTheme is derived from these roles in Theme.kt,
 * so app components and Material controls share one light/dark source.
 */
data class SproutColors(
    val canvas: Color,
    val surface: Color,
    val surfaceSubtle: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val separator: Color,
    val action: Color,
    val onAction: Color,
    val actionSubtle: Color,
    val success: Color,
    val warning: Color,
    val error: Color,
    val info: Color
)

internal val LightSproutColors = GeneratedLightColors
internal val DarkSproutColors = GeneratedDarkColors

internal val LocalSproutColors = staticCompositionLocalOf { LightSproutColors }

object SproutTokens {
    val colors: SproutColors
        @Composable get() = LocalSproutColors.current
}
