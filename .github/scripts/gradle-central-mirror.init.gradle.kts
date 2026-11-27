// Maven Central 镜像注入。
//
// repo.maven.apache.org 对同一出口 IP 的并发请求会返回 HTTP 429，并直接中断
// Gradle 配置阶段（包括 Flutter 工具链自带的 included build），导致发布构建随机失败。
// 这里在依赖解析前注入 Maven Central 的镜像仓库，命中不了时仍会回落到原仓库。
//
// 该脚本由 CI 复制到 ~/.gradle/init.d/ 后自动生效，不影响本地构建。

val centralMirrorUrl = "https://maven-central.storage-download.googleapis.com/maven2/"

fun RepositoryHandler.addCentralMirror() {
    maven {
        name = "mavenCentralMirror"
        url = uri(centralMirrorUrl)
        content {
            // Android 构件只发布在 Google Maven，避免镜像产生无意义的 404 请求。
            excludeGroupByRegex("androidx.*")
            excludeGroupByRegex("com\\.android.*")
            excludeGroupByRegex("com\\.google\\.android.*")
            excludeGroupByRegex("com\\.google\\.gms.*")
            excludeGroupByRegex("com\\.google\\.firebase.*")
        }
    }
}

beforeSettings {
    pluginManagement.repositories {
        addCentralMirror()
        gradlePluginPortal()
    }
    dependencyResolutionManagement.repositories {
        addCentralMirror()
    }
}
