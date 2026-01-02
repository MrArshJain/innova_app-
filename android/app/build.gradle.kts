plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    // We removed the 'namespace' line. 
    // It will now use the package name from AndroidManifest.xml
    
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        // We removed 'applicationId'. 
        // It will now use the package name from AndroidManifest.xml
        
        minSdkVersion 23
        targetSdkVersion 34
        versionCode 1
        versionName "1.0"
        multiDexEnabled true 
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1' 
}
