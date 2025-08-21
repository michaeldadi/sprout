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
        initializeMixpanel()
        initializeAppsFlyer()
        initializeFacebook()
        initializeRevenueCat()
    }

    private fun initializeMixpanel() {
        if (BuildConfig.MIXPANEL_TOKEN.isNotEmpty()) {
            MixpanelAPI.getInstance(this, BuildConfig.MIXPANEL_TOKEN, true)
            Log.i("SproutApplication", "MixPanel initialized")
        } else {
            Log.w("SproutApplication", "MixPanel token not configured")
        }
    }

    private fun initializeAppsFlyer() {
        if (BuildConfig.APPSFLYER_DEV_KEY.isNotEmpty()) {
            AppsFlyerLib.getInstance().init(BuildConfig.APPSFLYER_DEV_KEY, null, this)
            AppsFlyerLib.getInstance().start(this)
            Log.i("SproutApplication", "AppsFlyer initialized")
        } else {
            Log.w("SproutApplication", "AppsFlyer dev key not configured")
        }
    }

    private fun initializeFacebook() {
        // Facebook SDK is auto-initialized via manifest metadata
        FacebookSdk.setAutoInitEnabled(true)
        AppEventsLogger.activateApp(this)
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
