plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Placeholder namespace/application ID is replaced via CI for signed store builds.
    namespace = "com.placeholder.barstockapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.placeholder.barstockapp"
        // The semantic version (MAJOR.MINOR.PATCH) is defined in pubspec.yaml; keep versionName in sync.
        versionName = flutter.versionName
        // versionCode must monotonically increase with every semantic version bump for Play Console uploads.
        versionCode = flutter.versionCode
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
    }

    buildTypes {
        release {
            // Signing configs are supplied by CI/CD or locally via gradle.properties before publishing.
            // Keep this block unsigned so QA builds remain free of release credentials.
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.6.0"))
    implementation("com.google.firebase:firebase-analytics")
}
