package com.michaeldadi.sprout

import android.app.Application
import android.util.Log
import com.appsflyer.AppsFlyerLib
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import com.mixpanel.android.mpmetrics.MixpanelAPI
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import zendesk.android.Zendesk
import zendesk.messaging.android.DefaultMessagingFactory

class SproutApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Initialize Zendesk SDK
        Zendesk.initialize(
          context = this,
          channelKey = "<your_channel_key>",
          successCallback = { zendesk ->
            Log.i("ZenDesk SDK initialized successfully:", zendesk.messaging.toString())
          },
          failureCallback = { error ->
            Log.e("An error occurred initializing the ZenDesk SDK:", error.message.toString())
          },
          messagingFactory = DefaultMessagingFactory()
        )

        // Initialize other SDKs that are already in use
        initializeMixpanel()
        initializeAppsFlyer()
        initializeFacebook()
        initializeRevenueCat()
    }

    private fun initializeMixpanel() {
        // TODO: Replace with your actual Mixpanel token
        val mixpanel = MixpanelAPI.getInstance(this, "YOUR_MIXPANEL_TOKEN", true)
    }

    private fun initializeAppsFlyer() {
        // TODO: Replace with your actual AppsFlyer dev key
        AppsFlyerLib.getInstance().init("YOUR_APPSFLYER_DEV_KEY", null, this)
        AppsFlyerLib.getInstance().start(this)
    }

    private fun initializeFacebook() {
        // Facebook SDK is auto-initialized via manifest metadata
        FacebookSdk.setAutoInitEnabled(true)
        AppEventsLogger.activateApp(this)
    }

    private fun initializeRevenueCat() {
        // TODO: Replace with your actual RevenueCat API key
        Purchases.logLevel = LogLevel.DEBUG
        Purchases.configure(
            PurchasesConfiguration.Builder(this, "YOUR_REVENUECAT_API_KEY")
                .build()
        )
    }
}
