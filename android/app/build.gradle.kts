plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// 1. On ajoute les imports nécessaires
import java.util.Properties
        import java.io.FileInputStream

        android {
            namespace = "com.studiotsi.bnssa"
            compileSdk = 36
            ndkVersion = flutter.ndkVersion

            compileOptions {
                isCoreLibraryDesugaringEnabled = true
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }


            defaultConfig {
                applicationId = "com.studiotsi.bnssa"
                minSdk = flutter.minSdkVersion
                targetSdk = 36
                versionCode = flutter.versionCode
                versionName = flutter.versionName
                multiDexEnabled = true
            }

            // 2. On charge le fichier key.properties
            val keystoreProperties = Properties()
            val keystorePropertiesFile = rootProject.file("key.properties")
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(FileInputStream(keystorePropertiesFile))
            }

            // 3. On configure la signature "release"
            signingConfigs {
                create("release") {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                }
            }

            buildTypes {
                release {
                    // 4. On utilise la config "release" au lieu de "debug"
                    signingConfig = signingConfigs.getByName("release")
                    // shrinkResources = true // Optionnel : réduit la taille de l'app
                    // minifyEnabled = true   // Optionnel : protège le code
                }
            }
        }

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}