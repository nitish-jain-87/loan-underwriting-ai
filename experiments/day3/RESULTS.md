# Day 3: structured output reliability (5 inputs x 4 runs each)

| Label | Model | Runs | Correct | Wrong values | Invalid output | HTTP errors | Avg latency ms | Max latency ms | Avg prompt tok | Avg completion tok | Failed inputs |
|---|---|---|---|---|---|---|---|---|---|---|---|
| openai | gpt-5.4-mini-2026-03-17 | 20 | 20 | 0 | 0 | 0 | 1179 | 4162 | 332 | 28 | none |
| qwen3-4b | qwen3:4b-instruct | 20 | 16 | 4 | 0 | 0 | 4300 | 5666 | 341 | 34 | 5 |
| qwen3-8b | qwen3:8b | 20 | 16 | 4 | 0 | 0 | 11456 | 37487 | 349 | 40 | 5 |
