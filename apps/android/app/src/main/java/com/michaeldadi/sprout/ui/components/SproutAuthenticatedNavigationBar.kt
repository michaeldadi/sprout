package com.michaeldadi.sprout.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.List
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.michaeldadi.sprout.ui.theme.SproutTokens

/** Navigation display for the two implemented authenticated destinations. */
@Composable
fun SproutAuthenticatedNavigationBar(
    currentRoute: String,
    onHome: () -> Unit,
    onActivity: () -> Unit
) {
    NavigationBar(containerColor = SproutTokens.colors.surface) {
        NavigationBarItem(
            selected = currentRoute == "home",
            onClick = onHome,
            icon = { Icon(Icons.Filled.Home, contentDescription = null) },
            label = { Text("Home") }
        )
        NavigationBarItem(
            selected = currentRoute == "activity",
            onClick = onActivity,
            icon = { Icon(Icons.Filled.List, contentDescription = null) },
            label = { Text("Activity") }
        )
    }
}
