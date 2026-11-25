package com.michaeldadi.sprout.money

import android.content.Context
import com.michaeldadi.sprout.BuildConfig
import com.mixpanel.android.mpmetrics.MixpanelAPI
import org.json.JSONObject

/** Anonymous, allowlisted product events through one destination. */
object MoneyAnalytics {
    private var client: MixpanelAPI? = null
    @Synchronized fun configure(context: Context) {
        if (client != null || BuildConfig.DEBUG || BuildConfig.MIXPANEL_TOKEN.isBlank()) return
        client = MixpanelAPI.getInstance(context, BuildConfig.MIXPANEL_TOKEN, "sprout-allowlist-v1", false).apply {
            setEnableLogging(false)
            setUseIpAddressForGeolocation(false)
        }
    }
    @Synchronized fun track(name: String, parameters: Map<String, Any?> = emptyMap()) {
        val safe = SproutAnalyticsPolicy.sanitize(name, parameters) ?: return
        client?.track(name, JSONObject(safe))
    }
    @Synchronized fun reset() { client?.reset() }
}
