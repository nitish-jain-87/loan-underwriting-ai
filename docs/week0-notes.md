# Week 0 Notes

Write in your own words. If you can't explain it here, you can't explain it in an interview.

## Day 1 — Toolchain

| Tool | Version installed | Where from |
|---|---|---|
| JDK | 21 | Adoptium.net |
| IntelliJ IDEA | 2026.2.3 | Jetbrains.com |
| Docker | 4.96.2 | Docker.com |
| Ollama | 0.40.8 | Ollama.com |
| Local model | qwen3:8b | `ollama pull ...` |

**Machine:** OS Windows, RAM 32 GB

**What broke during setup and how I fixed it** (there is always something):
Docker failed because WSL 2 wasn’t installed

**How long the local model took to answer the first time vs the second time, and why I think it differs:**
- 6s vs 4s

**Exercise 1.1 — what `Environment.getActiveProfiles()` returns when no profile is set, and why that matters for Day 5:**
- empty array

## Day 2 — Raw HTTP to an LLM
(next)
