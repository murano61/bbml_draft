import java.util.Properties
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.user06069517634.bbmldraft"
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
        applicationId = "com.user06069517634.bbmldraft"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val props = Properties()
            val propsFile = file("../key.properties")
            if (propsFile.exists()) {
                props.load(propsFile.inputStream())
            }
            val storePath = (props.getProperty("storeFile") ?: System.getenv("UPLOAD_STORE_FILE") ?: "../upload-keystore.jks")
            storeFile = file(storePath)
            storePassword = props.getProperty("storePassword") ?: System.getenv("UPLOAD_STORE_PASSWORD")
            keyAlias = props.getProperty("keyAlias") ?: System.getenv("UPLOAD_KEY_ALIAS") ?: "upload"
            keyPassword = props.getProperty("keyPassword") ?: System.getenv("UPLOAD_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
