plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tidynook.tidy_nook"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Same id as the 1.0.0 WebView app already on Google Play (the Kotlin package stays com.tidynook.tidy_nook).
        applicationId = "com.tidynook.game"
        minSdk = 26
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing comes only from environment variables (set by CI from repository secrets).
    // Without a key file the release build is left UNSIGNED on purpose (never debug-signed).
    val keystorePath: String? = System.getenv("TIDY_KEYSTORE_FILE")
    val hasUploadKey: Boolean = !keystorePath.isNullOrBlank() && file(keystorePath).exists()

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = file(keystorePath!!)
                storePassword = System.getenv("TIDY_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("TIDY_KEY_ALIAS")
                keyPassword = System.getenv("TIDY_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (hasUploadKey) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
