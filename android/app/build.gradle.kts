import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningProperties = Properties()
val releaseSigningFile = rootProject.file("key.properties")
if (releaseSigningFile.exists()) {
    releaseSigningFile.inputStream().use(releaseSigningProperties::load)
}
val releaseSigningConfigured = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
).all { !releaseSigningProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "in.paperroute.paper_route"
    compileSdk = 36
    // Current FlutterFire native plugins require NDK 27.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "in.paperroute.paper_route"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Authentication requires Android 6.0 (API 23) or newer.
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = "PaperRoute Dev"
        manifestPlaceholders["usesCleartextTraffic"] = "true"
    }

    flavorDimensions += "environment"
    productFlavors {
        create("development") {
            dimension = "environment"
            applicationId = "in.paperroute.paper_route"
            manifestPlaceholders["appName"] = "PaperRoute Dev"
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        create("production") {
            dimension = "environment"
            applicationId = "in.paperroute.paper_route.prod"
            manifestPlaceholders["appName"] = "PaperRoute"
            manifestPlaceholders["usesCleartextTraffic"] = "false"
        }
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = rootProject.file(
                    releaseSigningProperties.getProperty("storeFile"),
                )
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (releaseSigningConfigured) signingConfigs.getByName("release") else null
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

val verifyProductionReleaseInputs by tasks.registering {
    group = "verification"
    description = "Fails closed until production Firebase and signing inputs exist."
    doLast {
        val firebaseConfig = file("src/production/google-services.json")
        check(firebaseConfig.exists()) {
            "Missing android/app/src/production/google-services.json. " +
                "Register in.paperroute.paper_route.prod in the approved production Firebase project."
        }
        check(releaseSigningConfigured) {
            "Missing complete android/key.properties release signing configuration."
        }
    }
}

tasks.configureEach {
    if (
        name == "processProductionReleaseGoogleServices" ||
        name == "packageProductionRelease" ||
        name == "bundleProductionRelease"
    ) {
        dependsOn(verifyProductionReleaseInputs)
    }
}

flutter {
    source = "../.."
}
