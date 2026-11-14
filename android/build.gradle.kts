allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Some plugins (e.g. file_picker) are compiled against an old Android SDK while their AndroidX
// dependencies need >= 36. Force every plugin module up to compileSdk 36.
// NOTE: this block must stay ABOVE the evaluationDependsOn(":app") block below.
subprojects {
    afterEvaluate {
        val ext = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val current = ext.javaClass.getMethod("getCompileSdk").invoke(ext) as? Int
            if (current != null && current < 36) {
                ext.javaClass.getMethod("setCompileSdk", Integer::class.java).invoke(ext, 36)
            }
        } catch (e: Exception) {
            logger.warn("compileSdk override skipped for ${project.name}: ${e.message}")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
