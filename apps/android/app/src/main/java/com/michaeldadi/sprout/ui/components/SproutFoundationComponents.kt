package com.michaeldadi.sprout.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Warning
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.michaeldadi.sprout.ui.theme.SproutSpacing
import com.michaeldadi.sprout.ui.theme.SproutTokens
import com.michaeldadi.sprout.ui.theme.SproutType
import java.math.BigDecimal
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

enum class SproutActionRole { PRIMARY, SECONDARY, QUIET, DESTRUCTIVE }

@Composable
fun SproutActionButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    role: SproutActionRole = SproutActionRole.PRIMARY,
    enabled: Boolean = true,
    busy: Boolean = false
) {
    val content: @Composable () -> Unit = {
        Row(horizontalArrangement = Arrangement.spacedBy(SproutSpacing.xs), verticalAlignment = Alignment.CenterVertically) {
            if (busy) CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp,
                color = SproutTokens.colors.textSecondary)
            Text(title, style = MaterialTheme.typography.labelLarge, textAlign = TextAlign.Center)
        }
    }
    val buttonModifier = modifier.fillMaxWidth().heightIn(min = SproutSpacing.touchTarget)
    val disabledColors = ButtonDefaults.buttonColors(
        disabledContainerColor = SproutTokens.colors.surfaceSubtle,
        disabledContentColor = SproutTokens.colors.textSecondary
    )
    when (role) {
        SproutActionRole.PRIMARY -> Button(onClick, modifier = buttonModifier, enabled = enabled && !busy,
            colors = disabledColors, content = { content() })
        SproutActionRole.SECONDARY -> OutlinedButton(
            onClick, modifier = buttonModifier, enabled = enabled && !busy,
            colors = ButtonDefaults.outlinedButtonColors(disabledContentColor = SproutTokens.colors.textSecondary),
            content = { content() }
        )
        SproutActionRole.DESTRUCTIVE -> OutlinedButton(
            onClick, modifier = buttonModifier, enabled = enabled && !busy,
            colors = ButtonDefaults.outlinedButtonColors(contentColor = SproutTokens.colors.error,
                disabledContentColor = SproutTokens.colors.textSecondary),
            content = { content() }
        )
        SproutActionRole.QUIET -> TextButton(onClick, modifier = buttonModifier, enabled = enabled && !busy,
            colors = ButtonDefaults.textButtonColors(disabledContentColor = SproutTokens.colors.textSecondary),
            content = { content() })
    }
}

private fun formatAmount(amount: BigDecimal?, currencyCode: String): String {
    if (amount == null) return "Amount unavailable"
    return runCatching {
        NumberFormat.getCurrencyInstance(Locale.getDefault()).apply {
            val sourceCurrency = Currency.getInstance(currencyCode)
            currency = sourceCurrency
            val digits = maxOf(sourceCurrency.defaultFractionDigits.coerceAtLeast(0), amount.scale().coerceAtLeast(0))
            maximumFractionDigits = digits
            minimumFractionDigits = digits
        }.format(amount)
    }.getOrDefault("Amount unavailable")
}

@Composable
fun SproutAmountText(
    amount: BigDecimal?,
    currencyCode: String,
    modifier: Modifier = Modifier,
    large: Boolean = false,
    concealed: Boolean = false
) {
    val value = if (concealed) "Amount hidden" else formatAmount(amount, currencyCode)
    Text(
        text = if (concealed) "••••••" else value,
        modifier = modifier.semantics { contentDescription = value },
        style = if (large) SproutType.amountLarge else SproutType.amountRow,
        color = SproutTokens.colors.textPrimary
    )
}

enum class SproutFeedbackKind { INFO, WARNING, ERROR, SUCCESS }

@Composable
fun SproutStatusBanner(title: String, detail: String, kind: SproutFeedbackKind, modifier: Modifier = Modifier) {
    val color = when (kind) {
        SproutFeedbackKind.INFO -> SproutTokens.colors.info
        SproutFeedbackKind.WARNING -> SproutTokens.colors.warning
        SproutFeedbackKind.ERROR -> SproutTokens.colors.error
        SproutFeedbackKind.SUCCESS -> SproutTokens.colors.success
    }
    Surface(modifier = modifier.fillMaxWidth(), color = SproutTokens.colors.surfaceSubtle, shape = MaterialTheme.shapes.medium) {
        Row(modifier = Modifier.padding(SproutSpacing.md), horizontalArrangement = Arrangement.spacedBy(SproutSpacing.sm)) {
            Text("●", color = color)
            Column(verticalArrangement = Arrangement.spacedBy(SproutSpacing.xxs)) {
                Text(title, style = MaterialTheme.typography.titleMedium, color = SproutTokens.colors.textPrimary)
                Text(detail, style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textSecondary)
            }
        }
    }
}

/** Short list-level status; record rows retain their specific sync state. */
@Composable
fun SproutStatusLine(text: String, kind: SproutFeedbackKind, modifier: Modifier = Modifier) {
    val color = when (kind) {
        SproutFeedbackKind.INFO -> SproutTokens.colors.info
        SproutFeedbackKind.WARNING -> SproutTokens.colors.warning
        SproutFeedbackKind.ERROR -> SproutTokens.colors.error
        SproutFeedbackKind.SUCCESS -> SproutTokens.colors.success
    }
    val icon = when (kind) {
        SproutFeedbackKind.INFO -> Icons.Filled.Info
        SproutFeedbackKind.WARNING -> Icons.Filled.Warning
        SproutFeedbackKind.ERROR -> Icons.Filled.Warning
        SproutFeedbackKind.SUCCESS -> Icons.Filled.CheckCircle
    }
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(SproutSpacing.xs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
        Text(text, style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textPrimary)
    }
}

@Composable
fun SproutTransactionRow(
    title: String,
    detail: String,
    amount: BigDecimal?,
    currencyCode: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    status: String? = null,
    statusKind: SproutFeedbackKind = SproutFeedbackKind.WARNING,
    selected: Boolean = false,
    enabled: Boolean = true
) {
    Surface(
        modifier = modifier.fillMaxWidth().semantics { this.selected = selected },
        color = if (selected) SproutTokens.colors.actionSubtle else SproutTokens.colors.surface,
        shape = MaterialTheme.shapes.medium
    ) {
        Column(
            modifier = Modifier.clickable(enabled = enabled, onClick = onClick)
                .heightIn(min = SproutSpacing.rowMinHeight)
                .padding(SproutSpacing.md),
            verticalArrangement = Arrangement.spacedBy(SproutSpacing.xs)
        ) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(SproutSpacing.sm)) {
                Surface(color = SproutTokens.colors.actionSubtle, shape = RoundedCornerShape(SproutSpacing.sm)) {
                    Text(title.take(1).uppercase(), modifier = Modifier.padding(SproutSpacing.sm),
                        color = SproutTokens.colors.action, style = MaterialTheme.typography.titleMedium)
                }
                Column(verticalArrangement = Arrangement.spacedBy(SproutSpacing.xxs)) {
                    Text(title, style = MaterialTheme.typography.titleMedium, color = SproutTokens.colors.textPrimary)
                    Text(detail, style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textSecondary)
                    if (status != null) Text(status, style = MaterialTheme.typography.labelMedium, color = when (statusKind) {
                        SproutFeedbackKind.INFO -> SproutTokens.colors.info
                        SproutFeedbackKind.WARNING -> SproutTokens.colors.warning
                        SproutFeedbackKind.ERROR -> SproutTokens.colors.error
                        SproutFeedbackKind.SUCCESS -> SproutTokens.colors.success
                    })
                }
            }
            SproutAmountText(amount, currencyCode, modifier = Modifier.align(Alignment.End))
        }
    }
}

@Composable
fun SproutStatePanel(title: String, detail: String, modifier: Modifier = Modifier, loading: Boolean = false) {
    Surface(modifier = modifier.fillMaxWidth(), color = SproutTokens.colors.surface, shape = MaterialTheme.shapes.medium) {
        Column(modifier = Modifier.padding(SproutSpacing.lg), verticalArrangement = Arrangement.spacedBy(SproutSpacing.xs)) {
            if (loading) CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
            Text(title, style = MaterialTheme.typography.titleLarge, color = SproutTokens.colors.textPrimary)
            Text(detail, style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textSecondary)
        }
    }
}

@Composable
fun SproutInputField(
    title: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    helper: String? = null,
    error: String? = null
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(SproutSpacing.xs)) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            label = { Text(title) },
            isError = error != null,
            singleLine = false,
            modifier = Modifier.fillMaxWidth().heightIn(min = SproutSpacing.touchTarget)
        )
        if (error != null) Text(error, style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.error)
        else if (helper != null) Text(helper, style = MaterialTheme.typography.bodyMedium, color = SproutTokens.colors.textSecondary)
    }
}

@Composable
fun SproutSearchField(
    title: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val keyboardController = LocalSoftwareKeyboardController.current
    val focusManager = LocalFocusManager.current
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier.fillMaxWidth(),
        placeholder = { Text("Merchant or category") },
        leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
        trailingIcon = {
            if (value.isNotEmpty()) {
                IconButton(onClick = { onValueChange("") }) {
                    Icon(Icons.Filled.Clear, contentDescription = "Clear search")
                }
            }
        },
        singleLine = true,
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
        keyboardActions = KeyboardActions(onSearch = {
            keyboardController?.hide()
            focusManager.clearFocus()
        }),
        label = { Text(title) }
    )
}
