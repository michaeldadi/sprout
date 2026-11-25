package com.michaeldadi.sprout.money

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.michaeldadi.sprout.ui.theme.LocalSproutColors

/** Draws the server-calculated category values; refunds cannot create negative arc angles. */
@Composable
internal fun MoneyCategoryChart(categories: List<MoneyCategoryPace>) {
    val positive = categories.filter { it.spentMinor > 0 }
    if (positive.isEmpty()) {
        Text(
            "No spending in your budgeted categories this period.",
            style = MaterialTheme.typography.bodyMedium,
        )
        return
    }
    val palette = LocalSproutColors.current
    val colors = listOf(palette.action, palette.info, palette.warning, palette.textSecondary)
    val description =
        "Posted spending in budgeted categories. " +
            categories.joinToString(". ") {
                "${it.category}: ${MoneyAmount(it.spentMinor).formatted()}"
            }
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(180.dp).semantics { contentDescription = description }) {
            val stroke = 24.dp.toPx()
            val diameter = size.minDimension - stroke
            val total = positive.sumOf { it.spentMinor.toDouble() }
            var start = -90f
            positive.forEachIndexed { index, category ->
                val sweep = (category.spentMinor.toDouble() / total * 360).toFloat()
                drawArc(
                    color = colors[index % colors.size],
                    startAngle = start,
                    sweepAngle = (sweep - minOf(2f, sweep / 4)).coerceAtLeast(0f),
                    useCenter = false,
                    topLeft = Offset(stroke / 2, stroke / 2),
                    size = Size(diameter, diameter),
                    style = Stroke(stroke),
                )
                start += sweep
            }
        }
        Text("Categories", style = MaterialTheme.typography.labelLarge)
    }
}
