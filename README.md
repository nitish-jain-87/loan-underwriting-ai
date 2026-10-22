# Loan Underwriting AI

A multi-agent loan underwriting system built with Java 21, Spring Boot 4 and LangChain4j.
Focus: the enterprise constraints of AI — security, data privacy, token cost, rate limiting, fault tolerance.

> Status: Week 0 — foundation. No AI code yet.

## Run it

Prerequisites: JDK 21, Docker, Ollama. Windows users: use Git Bash.

```bash
cp .env.example .env          # then fill in values
./gradlew build               # compile + test
./gradlew bootRun             # start on :8080
curl localhost:8080/api/ping
```

## Verify the environment

```bash
./scripts/verify-day1.sh
```

## Docs
- `docs/adr/` — architecture decision records
- `docs/week0-notes.md` — learning log
