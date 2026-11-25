plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

// A separate process drives the real minified app through platform accessibility.
// It has no dependency on :app and contributes no code to a shipping APK.
android {
    namespace = "com.michaeldadi.sprout.acceptance"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.michaeldadi.sprout.acceptance"
        minSdk = 29
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11) } }
}
androidComponents { beforeVariants(selector().withBuildType("release")) { it.enable = false } }
dependencies {
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.4.1")
}
