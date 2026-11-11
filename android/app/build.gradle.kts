plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (Analytics + Crashlytics) is optional. google-services.json is NOT in the repository; CI writes it
// from the GOOGLE_SERVICES_JSON secret when that is set. Without the file the plugins are not applied and the
// app builds and runs without Firebase (the Dart side then turns telemetry off).
val hasGoogleServices = file("google-services.json").exists()
if (hasGoogleServices) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

android {
    namespace = "com.tidynook.tidy_nook"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    // The release "lintVital" check crashes inside plugin sources (in_app_purchase_android, seen in Arrowtile);
    // it is not a code error, so it is skipped for release builds.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications needs core library desugaring (java.time on older Android).
        isCoreLibraryDesugaringEnabled = true
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
