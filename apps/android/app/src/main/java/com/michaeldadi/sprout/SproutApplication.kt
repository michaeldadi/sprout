package com.michaeldadi.sprout

import android.app.Application
import android.util.Log
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.michaeldadi.sprout.services.AppwriteConnection
import zendesk.android.Zendesk
import zendesk.messaging.android.DefaultMessagingFactory

class SproutApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        AppwriteConnection.initialize(this)
        runCatching { com.michaeldadi.sprout.money.MoneyReceiptOcr.pruneAbandoned(this) }
        com.michaeldadi.sprout.money.MoneyDeletionState.initialize(this)

        // Initialize Zendesk SDK
        if (BuildConfig.ZENDESK_CHANNEL_KEY.isNotEmpty()) {
            Zendesk.initialize(
              context = this,
              channelKey = BuildConfig.ZENDESK_CHANNEL_KEY,
              successCallback = { zendesk ->
                Log.i("ZenDesk SDK initialized successfully:", zendesk.messaging.toString())
              },
              failureCallback = { error ->
                Log.e("An error occurred initializing the ZenDesk SDK:", error.message.toString())
              },
              messagingFactory = DefaultMessagingFactory()
            )
        } else {
            Log.w("SproutApplication", "Zendesk channel key not configured")
        }

        // Initialize other SDKs that are already in use
        com.michaeldadi.sprout.money.MoneyAnalytics.configure(this)
        initializeRevenueCat()
    }

    private fun initializeRevenueCat() {
        if (BuildConfig.REVENUECAT_API_KEY.isNotEmpty()) {
            Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.INFO
            Purchases.configure(
                PurchasesConfiguration.Builder(this, BuildConfig.REVENUECAT_API_KEY)
                    .build()
            )
            Log.i("SproutApplication", "RevenueCat initialized")
        } else {
            Log.w("SproutApplication", "RevenueCat API key not configured")
        }
    }
}
