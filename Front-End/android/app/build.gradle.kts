import java.util.Properties

plugins {
    id("com.android.application")
    // Flutter Gradle Plugin diterapkan setelah Android Gradle Plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
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

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (!storeFilePath.isNullOrBlank()) {
                storeFile = file(storeFilePath)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast {
        val requiredProperties = listOf(
            "storeFile",
            "storePassword",
            "keyAlias",
            "keyPassword",
        )
        val missingProperties = requiredProperties.filter {
            keystoreProperties.getProperty(it).isNullOrBlank()
        }
        val storeFilePath = keystoreProperties.getProperty("storeFile")
        val storeFileExists = !storeFilePath.isNullOrBlank() &&
            file(storeFilePath).isFile

        if (missingProperties.isNotEmpty() || !storeFileExists) {
            throw GradleException(
                "Release signing is not configured. Add all required values " +
                    "to android/key.properties and provide the keystore file.",
            )
        }
    }
}

tasks.configureEach {
    if (name == "signRelease" || name == "signReleaseBundle") {
        dependsOn(verifyReleaseSigning)
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
