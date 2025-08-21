import java.util.Properties
import java.io.FileInputStream

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.google.gms)
    alias(libs.plugins.crashlytics)

    id("io.sentry.android.gradle") version "5.9.0"
}

// Load environment variables from .env file
val envFile = file("../../.env.local")
val envProperties = Properties()
if (envFile.exists()) {
    envProperties.load(FileInputStream(envFile))
} else {
    println("WARNING: .env.local file not found. Using default values.")
}

android {
    namespace = "com.michaeldadi.sprout"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.michaeldadi.sprout"
        minSdk = 29
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // Add BuildConfig fields from environment variables
        buildConfigField("String", "ZENDESK_CHANNEL_KEY", "\"${envProperties.getProperty("ZENDESK_CHANNEL_KEY", "")}\"")
        buildConfigField("String", "MIXPANEL_TOKEN", "\"${envProperties.getProperty("MIXPANEL_TOKEN", "")}\"")
        buildConfigField("String", "APPSFLYER_DEV_KEY", "\"${envProperties.getProperty("APPSFLYER_DEV_KEY", "")}\"")
        buildConfigField("String", "REVENUECAT_API_KEY", "\"${envProperties.getProperty("REVENUECAT_API_KEY", "")}\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)

    // Navigation
    implementation(libs.androidx.navigation.compose)

    // ViewModel
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    // AWS Cognito
    implementation(libs.aws)

    // Google Sign In
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play.services.auth)
    implementation(libs.googleid)

    // Coroutines
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.foundation)

    // Custom Tabs for Apple Sign In
    implementation(libs.androidx.browser)

    // Room database
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    implementation(libs.androidx.room.common.jvm)
    ksp(libs.androidx.room.compiler)

    // WorkManager for background sync
    implementation(libs.androidx.work.runtime.ktx)

    // RevenueCat
    implementation(libs.revenuecat)

    // MixPanel
    implementation(libs.android.mixpanel)

    // AppsFlyer
    implementation(libs.appsflyer.android)
    implementation(libs.install.referrer)
    implementation(libs.facebook.sdk)

    // Android shortcuts
    implementation(libs.androidx.shortcuts)

    // ZenDesk chat support SDK
    implementation(libs.zendesk.support)

    // Firebase
    implementation(platform(libs.firebase.sdk))
    implementation(libs.firebase.dynamic)
    // Individual firebase dependencies
    implementation(libs.firebase.ai)
    implementation(libs.firebase.analytics)
    implementation(libs.firebase.appcheck)
    implementation(libs.firebase.appdist)
    implementation(libs.firebase.crashlytics)
    implementation(libs.firebase.messaging)
    implementation(libs.firebase.perf)
    implementation(libs.firebase.remoteconfig)

    // Plaid
    implementation(libs.plaid.link)

    // Networking
    implementation(libs.retrofit)
    implementation(libs.retrofit.gson)
    implementation(libs.okhttp.logging)
    implementation(libs.gson)

    // Unit testing
    testImplementation(libs.junit)
    testImplementation(libs.mockito.core)
    testImplementation(libs.mockito.kotlin)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.kotlin.test)

    // Android testing
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    androidTestImplementation(libs.mockito.core)
    androidTestImplementation(libs.mockito.kotlin)

    // Debug dependencies
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}


sentry {
    org.set("michael-dadi-1b")
    projectName.set("sprout-android")

    // this will upload your source code to Sentry to show it as part of the stack traces
    // disable if you don't want to expose your sources
    includeSourceContext.set(true)
}
