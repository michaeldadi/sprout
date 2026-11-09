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

internal val LightSproutColors = SproutColors(
    canvas = Color(0xFFF6F8F4),
    surface = Color(0xFFFFFFFF),
    surfaceSubtle = Color(0xFFEBF2EA),
    textPrimary = Color(0xFF16271D),
    textSecondary = Color(0xFF526258),
    separator = Color(0xFFD7E2D7),
    action = Color(0xFF1C6A3D),
    onAction = Color(0xFFFFFFFF),
    actionSubtle = Color(0xFFD8ECDD),
    success = Color(0xFF227047),
    warning = Color(0xFF8B5B11),
    error = Color(0xFFA93830),
    info = Color(0xFF245C7B)
)

internal val DarkSproutColors = SproutColors(
    canvas = Color(0xFF101B16),
    surface = Color(0xFF17241D),
    surfaceSubtle = Color(0xFF22332A),
    textPrimary = Color(0xFFF0F6EF),
    textSecondary = Color(0xFFB9CCBC),
    separator = Color(0xFF35493B),
    action = Color(0xFF8BDD9D),
    onAction = Color(0xFF101B16),
    actionSubtle = Color(0xFF234532),
    success = Color(0xFF8BDD9D),
    warning = Color(0xFFF1C77A),
    error = Color(0xFFFFB4AC),
    info = Color(0xFF9DD5F1)
)

internal val LocalSproutColors = staticCompositionLocalOf { LightSproutColors }

object SproutTokens {
    val colors: SproutColors
        @Composable get() = LocalSproutColors.current
}
