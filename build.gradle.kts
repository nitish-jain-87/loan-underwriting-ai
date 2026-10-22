// =============================================================================
// loan-underwriting-ai — build file
//
// Day 1 scope: a plain Spring Boot 4 web app that compiles, tests and boots.
// NO LangChain4j yet. You add AI dependencies on Day 5, when you understand
// what they do. Adding dependencies you can't explain is how beginners end up
// with projects they can't debug.
// =============================================================================

import org.springframework.boot.gradle.plugin.SpringBootPlugin
import org.springframework.boot.gradle.tasks.bundling.BootJar

plugins {
    java
    // Check https://spring.io/projects/spring-boot for the newest 4.1.x patch and bump this.
    id("org.springframework.boot") version "4.1.1"
}

group = "com.nitish"
version = "0.0.1-SNAPSHOT"
description = "Multi-agent loan underwriting system (portfolio project)"

java {
    toolchain {
        // Fails fast if JDK 21 is not installed. That is intentional.
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    // Spring Boot's BOM manages all Spring versions, so no version numbers below.
    implementation(platform(SpringBootPlugin.BOM_COORDINATES))
    testImplementation(platform(SpringBootPlugin.BOM_COORDINATES))

    implementation("org.springframework.boot:spring-boot-starter-webmvc")   // Boot 4 name for "starter-web"
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-validation")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
    useJUnitPlatform()
}

// Predictable jar name, so scripts and (later) Dockerfiles don't need globs.
tasks.named<BootJar>("bootJar") {
    archiveFileName.set("app.jar")
}

// Spring Boot also builds a "plain" jar by default. We don't need it.
tasks.named<Jar>("jar") {
    enabled = false
}
