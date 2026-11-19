plugins {
    id("com.android.application")
    // Flutter Gradle Plugin diterapkan setelah Android Gradle Plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.tokokita.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.tokokita.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Menggunakan debug signing agar build release lokal dapat diuji.
            // Atur upload key sendiri sebelum publikasi ke Play Store.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Menyamakan target kompilasi Kotlin dengan Java, yaitu JVM 17.
kotlin {
    compilerOptions {
        jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        )
    }
}

flutter {
    source = "../.."
}
