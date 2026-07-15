plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.starsight"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.starsight"
        // MediaPipe Tasks Vision requires minSdk 24+, so it's hardcoded here
        // instead of using flutter.minSdkVersion (which may be lower).
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // MediaPipe does native library loading that R8 breaks unless you
            // add proper keep rules — disabling minification for now is the
            // simplest fix. Revisit this before a real production release.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // MediaPipe Tasks Vision (Gesture Recognizer)
    implementation("com.google.mediapipe:tasks-vision:0.10.14")

    // CameraX (native camera pipeline used by the gesture platform view)
    val cameraxVersion = "1.3.4"
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    implementation("androidx.camera:camera-view:$cameraxVersion")
}

flutter {
    source = "../.."
}