allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. flutter_facebook_auth, facebook_app_events) don't pin
// their own Java/Kotlin JVM targets consistently with this project's — or
// pin an explicit, older one (facebook_app_events hardcodes Java 1.8 in
// its own build.gradle) that only loses to a root-project override applied
// here BEFORE that plugin's own build.gradle runs. Wrapped in afterEvaluate
// so ours always applies last regardless of which one Gradle evaluates
// first. Force every *plugin* subproject (always com.android.library — the
// app module is com.android.application and already sets its own matching
// targets in app/build.gradle.kts, so it's deliberately excluded here to
// avoid re-finalizing its config).
subprojects {
    // evaluationDependsOn(":app") above can leave a given subproject
    // already evaluated by the time this runs for it — afterEvaluate
    // throws rather than running immediately in that case, so this calls
    // the override directly instead whenever that's already happened.
    val applyJvmTargetOverride: () -> Unit = {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }

    if (state.executed) {
        applyJvmTargetOverride()
    } else {
        afterEvaluate { applyJvmTargetOverride() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
