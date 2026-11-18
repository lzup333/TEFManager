plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "eternal.future.tefmanager"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "eternal.future.tefmanager"
        minSdk = 24
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("tefmanager.p12")
            storePassword = "EternalFuture@2026"
            keyAlias = "TEFManager"
            keyPassword = "EternalFuture@2026"
            storeType = "PKCS12"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.16.0")
    // Xposed API is only needed to compile the entry point; LSPosed provides it
    // at runtime inside the hooked process.
    compileOnly("de.robv.android.xposed:api:82")
}

flutter {
    source = "../.."
}
