package com.michaeldadi.sprout.money

import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.google.gson.Gson
import com.michaeldadi.sprout.services.AppwriteAccountIdentity
import com.michaeldadi.sprout.ui.theme.SproutTheme

class MoneyDesignReviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val frame = intent.getStringExtra("frame") ?: "home"
        var fixture =
            Gson()
                .fromJson(
                    assets.open("money-workspace.json").bufferedReader().use { it.readText() },
                    MoneyWorkspace::class.java,
                )
        if (frame in listOf("connect-bank", "subscriptions-found", "your-plan"))
            fixture = fixture.copy(profile = fixture.profile.copy(onboarding = frame))
        if (intent.getBooleanExtra("dark", false))
            fixture = fixture.copy(profile = fixture.profile.copy(appearance = "dark"))
        val route =
            when (frame) {
                "budget" -> "/budget"
                "activity" -> "/activity"
                "subscriptions" -> "/subscriptions"
                "insights" -> "/insights"
                "profile" -> "/profile"
                "add-expense" -> "/expense"
                "subscription-detail" -> "/subscription?id=${fixture.subscriptions.first().id}"
                else -> "/home"
            }
        setContent {
            SproutTheme {
                if (frame == "welcome") MoneyWelcome()
                else
                    Box(Modifier.fillMaxSize()) {
                        MoneyApp(
                            AppwriteAccountIdentity(
                                "design-review",
                                "alex@example.invalid",
                                "Alex",
                            ),
                            Uri.parse("sprout://app$route"),
                            review = fixture,
                        )
                        Text("FICTIONAL DESIGN REVIEW", Modifier.align(Alignment.TopCenter))
                    }
            }
        }
    }
}
