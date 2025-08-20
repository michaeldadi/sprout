package com.michaeldadi.sprout.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import kotlin.math.*

/**
 * Floating circles background animation component
 * Mirrors the iOS FloatingCirclesView functionality
 */
@Composable
fun FloatingCirclesBackground(
    animatedOffset: Float = 0f
) {
    Canvas(
        modifier = Modifier.fillMaxSize()
    ) {
        drawFloatingCircles(animatedOffset)
    }
}

private fun DrawScope.drawFloatingCircles(offset: Float) {
    val circles = listOf(
        CircleData(
            centerX = size.width * 0.2f,
            centerY = size.height * 0.3f,
            radius = 60f,
            alpha = 0.1f,
            speed = 1f
        ),
        CircleData(
            centerX = size.width * 0.8f,
            centerY = size.height * 0.2f,
            radius = 80f,
            alpha = 0.08f,
            speed = 0.8f
        ),
        CircleData(
            centerX = size.width * 0.6f,
            centerY = size.height * 0.7f,
            radius = 100f,
            alpha = 0.06f,
            speed = 1.2f
        ),
        CircleData(
            centerX = size.width * 0.1f,
            centerY = size.height * 0.8f,
            radius = 70f,
            alpha = 0.09f,
            speed = 0.9f
        ),
        CircleData(
            centerX = size.width * 0.9f,
            centerY = size.height * 0.6f,
            radius = 50f,
            alpha = 0.12f,
            speed = 1.1f
        )
    )

    circles.forEach { circle ->
        val animatedX = circle.centerX + sin((offset * circle.speed) * PI / 180f).toFloat() * 20f
        val animatedY = circle.centerY + cos((offset * circle.speed) * PI / 180f).toFloat() * 15f

        drawCircle(
            color = Color.White.copy(alpha = circle.alpha),
            radius = circle.radius,
            center = androidx.compose.ui.geometry.Offset(animatedX, animatedY)
        )
    }
}

private data class CircleData(
    val centerX: Float,
    val centerY: Float,
    val radius: Float,
    val alpha: Float,
    val speed: Float
)
