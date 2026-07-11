import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 加载签名配置
fun loadSigningConfig(): Map<String, String>? {
    val propsFile = rootProject.file("key.properties")
    if (!propsFile.exists()) return null
    val props = Properties()
    props.load(propsFile.inputStream())
    val storeFile = props["storeFile"] as? String ?: return null
    return mapOf(
        "storeFile" to storeFile,
        "storePassword" to (props["storePassword"] as? String ?: return null),
        "keyAlias" to (props["keyAlias"] as? String ?: return null),
        "keyPassword" to (props["keyPassword"] as? String ?: return null),
    )
}

android {
    namespace = "com.smartcampus.smartcampus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.smartcampus.smartcampus"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        val signConfig = loadSigningConfig()
        if (signConfig != null) {
            create("release") {
                storeFile = file(signConfig["storeFile"]!!)
                storePassword = signConfig["storePassword"]
                keyAlias = signConfig["keyAlias"]
                keyPassword = signConfig["keyPassword"]
            }
        }
    }

    buildTypes {
        release {
            val hasSigning = loadSigningConfig() != null
            signingConfig = if (hasSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
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

dependencies {
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
}
