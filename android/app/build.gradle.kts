import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        val rawText = stream.bufferedReader(Charsets.UTF_8).readText().replace("\uFEFF", "")
        keystoreProperties.load(rawText.reader())
    }
}

val keyAliasVal = keystoreProperties.getProperty("keyAlias")?.trim()
val keyPasswordVal = keystoreProperties.getProperty("keyPassword")?.trim()
val storePasswordVal = keystoreProperties.getProperty("storePassword")?.trim()
val storeFileVal = keystoreProperties.getProperty("storeFile")?.trim()
val resolvedKeystoreFile = if (!storeFileVal.isNullOrEmpty()) file(storeFileVal) else null

val isReleaseSigningReady =
    !keyAliasVal.isNullOrEmpty() &&
    !keyPasswordVal.isNullOrEmpty() &&
    !storePasswordVal.isNullOrEmpty() &&
    resolvedKeystoreFile != null &&
    resolvedKeystoreFile.exists()

android {
    namespace = "com.tidara.tidara_smartclock"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.tidara.tidara_smartclock"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (isReleaseSigningReady) {
            create("release") {
                keyAlias = keyAliasVal!!
                keyPassword = keyPasswordVal!!
                storeFile = resolvedKeystoreFile!!
                storePassword = storePasswordVal!!
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (isReleaseSigningReady) {
                println("✅ Tidara Release Build: Signing with upload-keystore.jks (alias: $keyAliasVal)")
                signingConfigs.getByName("release")
            } else {
                println("⚠️ Tidara Release Build: key.properties or upload-keystore.jks incomplete, falling back to debug signing")
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
