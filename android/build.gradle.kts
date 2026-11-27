
allprojects {
    repositories {
        // Maven Central 对同一出口 IP 的并发请求会返回 HTTP 429 并中断依赖解析。
        // 优先走 Maven Central 镜像，未命中时回落 google() / mavenCentral()。
        maven {
            name = "mavenCentralMirror"
            url = uri("https://maven-central.storage-download.googleapis.com/maven2/")
            content {
                // Android 构件只发布在 Google Maven，避免镜像产生无意义的 404 请求。
                excludeGroupByRegex("androidx.*")
                excludeGroupByRegex("com\\.android.*")
                excludeGroupByRegex("com\\.google\\.android.*")
                excludeGroupByRegex("com\\.google\\.gms.*")
                excludeGroupByRegex("com\\.google\\.firebase.*")
            }
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}