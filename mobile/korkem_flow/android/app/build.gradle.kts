import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials, kept out of the repository.
//
// `android/key.properties` is gitignored and holds the upload keystore's paths
// and passwords. It is absent on a fresh clone and on CI, which is why every
// use below is guarded rather than assumed.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "kz.korkem.korkem_flow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "kz.korkem.korkem_flow"
        minSdk = flutter.minSdkVersion
        // Google Play requires API 36 for new apps from 31 August 2026.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // A profile build gets the same loopback-only cleartext exception a debug
    // build has. It is a measurement tool, never a shipped artefact, and
    // without this the only thing measurable against the development bench is
    // the login screen failing to reach it — which is precisely the screen
    // whose frame timings do not matter.
    //
    // The resource is *shared* with src/debug rather than copied. Two files
    // that must stay identical eventually will not, and the one that drifts
    // would be the one nobody reads.
    //
    // Release is untouched and keeps cleartext blocked: docs/privacy_policy.md
    // tells users Android blocks unencrypted HTTP, and that has to stay true
    // of what ships.
    sourceSets {
        getByName("profile") {
            res.srcDir("src/debug/res")
        }
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Signed with the real upload key when one is configured. Without
            // it the build still works — `flutter run --release` has to — but
            // it falls back to the debug key, and the check below makes that
            // loud rather than something discovered at upload time.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Fails an app-bundle build that would produce an unpublishable artefact.
//
// A debug-signed AAB is rejected by Play, but only after the upload — this
// turns a slow round trip into an immediate, explanatory build failure.
tasks.matching { it.name.startsWith("bundle") && it.name.contains("Release") }
    .configureEach {
        doFirst {
            if (!hasUploadKey) {
                throw GradleException(
                    "No android/key.properties: this bundle would be signed with the " +
                        "debug key and rejected by Google Play. See docs/play_release.md.",
                )
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
