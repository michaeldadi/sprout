package com.michaeldadi.sprout.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.michaeldadi.sprout.R


/**
 * Social login button component
 * Mirrors the iOS SocialLoginButton functionality
 */
@Composable
fun SocialLoginButton(
    text: String,
    backgroundColor: Color,
    textColor: Color,
    icon: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = backgroundColor
        ),
        border = if (backgroundColor == Color.White) {
            BorderStroke(1.dp, Color.Gray.copy(alpha = 0.2f))
        } else {
            BorderStroke(1.dp, Color.White.copy(alpha = 0.2f))
        },
        shape = RoundedCornerShape(15.dp),
        elevation = ButtonDefaults.buttonElevation(
            defaultElevation = 2.dp
        )
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Icon based on type
            when (icon.lowercase()) {
                "apple" -> {
                    Icon(
                        painter = painterResource(id = R.drawable.ic_apple_logo),
                        contentDescription = "Apple logo",
                        modifier = Modifier.size(20.dp),
                        tint = textColor
                    )
                }
                "google" -> {
                    Icon(
                        painter = painterResource(id = R.drawable.ic_google_logo),
                        contentDescription = "Google logo",
                        modifier = Modifier.size(20.dp),
                        tint = Color.Unspecified // Keep Google's original colors
                    )
                }
                else -> {
                    Text(
                        text = icon,
                        fontSize = 20.sp,
                        color = textColor
                    )
                }
            }
            
            Text(
                text = text,
                color = textColor,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}