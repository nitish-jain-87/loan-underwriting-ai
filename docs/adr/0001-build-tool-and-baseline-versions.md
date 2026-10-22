# ADR 0001: Build tool and baseline versions

**Status:** Accepted
**Date:** 2026-10

## Context
Starting a Spring Boot portfolio project that will integrate LangChain4j for LLM calls.

## Decision
- **Gradle (Kotlin DSL)** with the wrapper committed, so anyone can build with `./gradlew` and no local Gradle install.
- **Java 21 LTS**, enforced with a Gradle toolchain.
- **Spring Boot 4.1.x.** Spring Boot 3.5 OSS support ended June 2026. LangChain4j supports Boot 4 through its `*-spring-boot4-starter` artifacts.
- Spring versions come from the Spring Boot BOM, never hand-pinned.

## Consequences
- LangChain4j starters MUST be the `-spring-boot4-starter` variants. The `-spring-boot-starter` ones are for Boot 3 and will break autoconfiguration.
- Boot 4 uses Jackson 3. Expect JSON-library friction in older examples found online.
