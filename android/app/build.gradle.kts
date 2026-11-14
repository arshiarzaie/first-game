plugins {
    id("com.android.application")
}

/**
 * Pure Android Gradle build — no Flutter.
 *
 * MainActivity is a plain `android.app.Activity` that hosts a hardware
 * accelerated WebView and serves the offline Three.js/WebGL2 engine from
 * APK assets. The Flutter engine is never started, so pulling the Flutter
 * Gradle Plugin (and with it libflutter.so + the Dart AOT snapshot) out of
 * the build removes roughly 70 MB of dead weight from the APK.
 */
android {
    namespace = "com.ghoroub.soulduskrun"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.ghoroub.soulduskrun"
        minSdk = 24
        targetSdk = 36
        // Source of truth for the app version now that pubspec.yaml is inert.
        // CI derives the release tag from these two lines.
        versionCode = 27
        versionName = "1.2.0"
    }

    buildTypes {
        release {
            // Release signing is intentionally out of scope. Signing with the
            // debug key so the APK stays installable without secrets.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // Keep the packaged web bundle as small as aapt2 can make it: everything
    // (html/js/css/glb) is deflated. AssetManager decompresses transparently
    // for the WebView's asset interceptor.
    packaging {
        resources {
            excludes += setOf(
                "META-INF/*.kotlin_module",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
            )
        }
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
}
