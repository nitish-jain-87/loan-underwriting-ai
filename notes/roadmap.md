# Roadmap: Spring AI + Agentic AI Portfolio Project (merged plan)

Agreed 2026-10-24, **merged 2026-11-04** with the agentic-AI project into ONE project and ONE repo, and **AWS added 2026-11-04** as a thin, AI-relevant deployment slice (not a cloud course). This file is the single source of truth for the plan. Day-level status lives in `claude/week0-progress.md`; the shareable summary is `OVERVIEW.md`.

## Goal and positioning
Senior Java AI Engineer role (H1B sponsorship). Interview line:
> *"I build production-grade AI features in Java with Spring AI (measured reliability, cost, PII safety, fail-fast config), and I use and build agentic AI to make engineering teams faster."*

Two tracks in one repo, plus a thin AWS slice:
1. **Build AI (Spring AI):** the loan-underwriting system: structured output, tools, RAG, agents, evals, hardening, plus a Spring AI PR-review agent.
2. **Build with AI (agentic dev workflow):** Claude Code on the same repo: `CLAUDE.md` rules, permissions, hooks, skills, subagents, CI automation, MCP. Lessons A1–A6.
3. **Ship it (AWS):** Bedrock as a provider, then deploy on ECS Fargate with Terraform, RDS pgvector, Secrets Manager, GitHub OIDC, CloudWatch. Reference: `claude/aws-ocp-mapping.md`.

## Time budget (honest version)
- **Core + agentic add-ons: 15 h/week.** Add-ons (2–4 h) **replace the weekly buffer day**. There's no slack left, so a slipped day slips the plan.
- **System design: ~3 h/week on top** (18 h/week total). If a week only has 15 h, system design gives way first, then the stretch items. The core never does.
- Length: **7 weeks** (rest of Week 0 + Weeks 1–6) + wrap-up. AWS added ~1 week.
- **AWS cost guardrails:** budget alarm before anything is created, teardown script, never leave RDS/NAT running, record the demo while it's up.
- **Start applying: end of Week 2.**

## Repo
github.com/nitish-jain-87/loan-underwriting-ai: Spring Boot 4.1, Java 21, Gradle (Kotlin DSL), Spring AI 2.0.x.

## Plan

| Phase | Core (Spring AI) | Agentic add-on (Claude Code / AI-ops) · **AWS** |
|---|---|---|
| **Week 0** | D1 toolchain ✅ · D2 raw HTTP ✅ · D3 ChatClient, provider profiles + fail-fast, structured output bench ⏳ · D4 tool calling (`@Tool`, watch the wire) + chat memory | **A1 (Day 5, replaces buffer, 3 h):** Claude Code on the repo. `CLAUDE.md` encoding project rules (LLM never decides, no PII in logs, fail-fast profiles), permission deny-list for secrets/`.env`, a hook that blocks committing API keys, start `DECISIONS.md` (AI override log) |
| **Week 1: Intake agent** | Free text/PDF → validated `LoanApplication`. PII masking before the LLM sees anything. Retry on invalid output, native structured output, Bean Validation + business rules. Eval set (10 hand-labelled applications + scoring test). Token-budget guard | **A2 (3 h):** CI first: GitHub Actions build + tests on every PR, Dependabot, Trivy scan. `java-test-writer` skill for intake tests |
| **Week 2: RAG** | Lending policies in pgvector. Risk agent cites the policy section it used. Chunking, similarity thresholds, retrieval-quality eval | **A3 (2–3 h):** `pr-review` skill (PII, injection, cost, missing tests) as the spec for the Week 5 agent. Read-only `security-reviewer` subagent. **AWS-0 (1.5 h):** account hygiene: root MFA, IAM Identity Center user, `aws sso login`, budget alarm. Nothing deployed |
| **Week 3: Agent workflow** | Intake → risk (tools: credit-score lookup; DTI computed in Java, never by the LLM) → decision, human-in-the-loop for borderline cases. 3 agents total | **A4 (2 h):** agent design patterns applied to this design: workflow vs agent, planner/executor, task-success evals |
| **Week 4: Hardening** | Micrometer token/cost metrics, rate limiter, timeouts / retry / fallback model, prompt-injection guardrail | **AWS-1 (3 h): Amazon Bedrock as the fallback model**: a third provider profile (`bedrock`, Spring AI Bedrock Converse starter; verify the artifact then), IAM-role auth instead of an API key, data stays in your AWS account/region. Same fail-fast guard |
| **Week 5: AI-ops** | Spring AI PR-review agent: GitHub Action → diff → checklist review → structured findings → PR comment, dogfooded on this repo | **A5 (4 h):** `claude-code-action` auto-fixes failing Dependabot PRs (max turns, no test/workflow edits, never merges). **Benchmark:** Spring AI PR agent vs Claude Code `pr-review` skill on the same PRs |
| **Week 6: Ship it on AWS** | — | **AWS-2 (~15 h):** Terraform (small, ~6 resources): ECR, ECS Fargate service + ALB, RDS PostgreSQL + pgvector, Secrets Manager (OpenAI key), IAM task role (Bedrock) vs execution role, CloudWatch logs + Micrometer metrics, GitHub Actions → AWS via **OIDC** (no long-lived keys). Teardown script. Record the demo here |
| **Wrap-up (2–3 days, Week 7)** | README + architecture diagram, 3-minute demo video, interview story bank | Story bank draws on `DECISIONS.md` (one agent-override story per week) |
| Stretch | Log-triage agent over the app's own logs/traces | **A6 (3 h):** Spring AI **MCP server** exposing credit lookup + policy search, with Claude Code as the client |

## AWS slice: rules
- Only AI-relevant AWS. **Cut:** EKS (control-plane cost, and he already knows Kubernetes via OCP), certifications, multi-account AWS Organizations, Lambda rewrites.
- Local Docker Compose stays the dev environment until Week 6. AWS never blocks the core.
- Every AWS lesson maps the concept to its OCP/Helm equivalent first (see `claude/aws-ocp-mapping.md`). His gaps are what OCP hid from him: **IAM, VPC networking, load balancer/DNS/TLS provisioning, cost**.

## Development rules (from A1 onward)
- **Hand-written by Nitish:** the AI core: `ChatClient` usage, tools, RAG pipeline, guardrails, agents, evals. These are the parts interviewers will drill into, so he must be able to explain every line.
- **Agent-written, human-reviewed:** plumbing: Docker Compose, CI YAML, test scaffolding, README drafts.
- Every time the coding agent is overridden or corrected, add a dated entry to `DECISIONS.md` (what it did, why it was wrong, what was done instead). One entry per week feeds the story bank.
- Any agent change that touches test files or workflow files needs explicit human review. Agents never merge.

## System design track (~3 h/week, alongside)
- Each week: whiteboard this repo's architecture at its current stage, out loud, in 30 minutes.
- Each week: one classic problem + one AI system design problem (e.g. RAG at scale, LLM gateway with rate limits and fallback, multi-tenant agent platform).
- DSA: maintenance only, not planned here.

## Interview prep format (decided 2026-11-04)
- **Per lesson:** every lesson (core, agentic, AWS) has three parts per topic: **conceptual → practical → interview questions with answers**, for the topics built that day.
- **At wrap-up:** one consolidated **interview bank** across everything, written once he can connect it all: end-to-end walkthrough of the system, cross-cutting questions ("a request comes in, trace it from ALB to Bedrock and back", "where is PII protected at each hop", "what happens when OpenAI is down"), plus the story bank from `DECISIONS.md`.
- Reason: Q&A on things not yet built gets memorized and collapses at the second follow-up question. Per-lesson Q&A sticks because he just built it; the final bank connects the pieces.

## Interview topics this plan must cover
- **Spring AI / LLM apps:** structured output · RAG · tool calling / agents · evals · cost & latency · safety (prompt injection, PII) · resilience (timeouts, retries, fallbacks, rate limits).
- **Agentic engineering:** agent vs workflow trade-offs · agent guardrails (permissions, hooks, max turns, no-merge) · MCP · skills/subagents · measuring AI-assisted productivity honestly · AI in CI.
- **Cloud (AWS):** deploy and secure this system: IAM roles (task vs execution), secrets, VPC/subnets/security groups, private access to Bedrock, OIDC from CI, cost control, Bedrock vs OpenAI for PII.
- **System design:** this repo's architecture end to end, including where it runs.

## Cut on purpose
More than 3 underwriting agents, Kubernetes / cloud deployment, UI, fine-tuning. Docker Compose + demo video is enough for a portfolio.
