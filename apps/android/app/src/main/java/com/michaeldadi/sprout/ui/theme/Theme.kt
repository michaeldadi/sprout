package com.michaeldadi.sprout.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

private val LightColorScheme = lightColorScheme(
    primary = LightSproutColors.action,
    onPrimary = LightSproutColors.onAction,
    primaryContainer = LightSproutColors.actionSubtle,
    onPrimaryContainer = LightSproutColors.textPrimary,
    secondary = LightSproutColors.textSecondary,
    onSecondary = LightSproutColors.surface,
    secondaryContainer = LightSproutColors.surfaceSubtle,
    onSecondaryContainer = LightSproutColors.textPrimary,
    tertiary = LightSproutColors.info,
    onTertiary = LightSproutColors.surface,
    background = LightSproutColors.canvas,
    onBackground = LightSproutColors.textPrimary,
    surface = LightSproutColors.surface,
    onSurface = LightSproutColors.textPrimary,
    surfaceVariant = LightSproutColors.surfaceSubtle,
    onSurfaceVariant = LightSproutColors.textSecondary,
    surfaceContainerLowest = LightSproutColors.surface,
    surfaceContainerLow = LightSproutColors.canvas,
    surfaceContainer = LightSproutColors.surfaceSubtle,
    surfaceContainerHigh = LightSproutColors.surfaceSubtle,
    surfaceContainerHighest = LightSproutColors.surfaceSubtle,
    inverseSurface = LightSproutColors.textPrimary,
    inverseOnSurface = LightSproutColors.surface,
    inversePrimary = DarkSproutColors.action,
    surfaceTint = LightSproutColors.action,
    outline = LightSproutColors.separator,
    outlineVariant = LightSproutColors.separator,
    error = LightSproutColors.error,
    onError = LightSproutColors.surface
)

private val DarkColorScheme = darkColorScheme(
    primary = DarkSproutColors.action,
    onPrimary = DarkSproutColors.onAction,
    primaryContainer = DarkSproutColors.actionSubtle,
    onPrimaryContainer = DarkSproutColors.textPrimary,
    secondary = DarkSproutColors.textSecondary,
    onSecondary = DarkSproutColors.canvas,
    secondaryContainer = DarkSproutColors.surfaceSubtle,
    onSecondaryContainer = DarkSproutColors.textPrimary,
    tertiary = DarkSproutColors.info,
    onTertiary = DarkSproutColors.canvas,
    background = DarkSproutColors.canvas,
    onBackground = DarkSproutColors.textPrimary,
    surface = DarkSproutColors.surface,
    onSurface = DarkSproutColors.textPrimary,
    surfaceVariant = DarkSproutColors.surfaceSubtle,
    onSurfaceVariant = DarkSproutColors.textSecondary,
    surfaceContainerLowest = DarkSproutColors.canvas,
    surfaceContainerLow = DarkSproutColors.surface,
    surfaceContainer = DarkSproutColors.surfaceSubtle,
    surfaceContainerHigh = DarkSproutColors.surfaceSubtle,
    surfaceContainerHighest = DarkSproutColors.surfaceSubtle,
    inverseSurface = DarkSproutColors.textPrimary,
    inverseOnSurface = DarkSproutColors.canvas,
    inversePrimary = LightSproutColors.action,
    surfaceTint = DarkSproutColors.action,
    outline = DarkSproutColors.separator,
    outlineVariant = DarkSproutColors.separator,
    error = DarkSproutColors.error,
    onError = DarkSproutColors.canvas
)

private val SproutShapes = Shapes(
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(24.dp)
)

@Composable
fun SproutTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (darkTheme) DarkSproutColors else LightSproutColors
    CompositionLocalProvider(LocalSproutColors provides colors) {
        MaterialTheme(
            colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme,
            typography = Typography,
            shapes = SproutShapes,
            content = content
        )
    }
}
