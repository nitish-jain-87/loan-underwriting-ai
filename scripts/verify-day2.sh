#!/usr/bin/env bash
# Day 2 verification (v3: notes check removed; token parsing tolerates pretty-printed JSON). Copy to scripts/verify-day2.sh, commit it with your work,
# push, then run from the repo root in Git Bash:  bash scripts/verify-day2.sh
set -u
PASS=0; FAIL=0
ok()    { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()   { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
num()   { tr -d '\r\n' < "$2" 2>/dev/null | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*[0-9]+" | head -1 | grep -oE '[0-9]+$'; }

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Not inside a git repo"; exit 1; }
D=experiments/day2; Q=$D/requests; R=$D/responses; N=notes/day2.md

echo "== Git (portfolio gate) =="
git fetch -q origin 2>/dev/null
check "no uncommitted changes"        '[ -z "$(git status --porcelain)" ]'
check "upstream branch set"           'git rev-parse --abbrev-ref @{u}'
check "no unpushed commits"           'git rev-parse @{u} && [ -z "$(git rev-list @{u}..HEAD)" ]'
check "HEAD exists on remote"         'git ls-remote origin | grep -q "$(git rev-parse HEAD)"'

echo "== Secrets =="
check "no OpenAI key in working tree" '! git grep -qE "sk-[A-Za-z0-9_-]{20,}" -- .'
check "no OpenAI key in git history"  '! git log -p --all | grep -qE "sk-[A-Za-z0-9_-]{20,}"'
check "OPENAI_API_KEY set in env"     '[ -n "${OPENAI_API_KEY:-}" ]'

echo "== Ollama =="
check "ollama server reachable"       'curl -sf http://localhost:11434/api/version'
check "qwen3:8b pulled"               'ollama list | grep -q "qwen3:8b"'
check "live call, think off, done"    'curl -sf http://localhost:11434/api/chat -d "{\"model\":\"qwen3:8b\",\"stream\":false,\"think\":false,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with OK\"}]}" | grep -q "\"done\":true"'

echo "== Ollama experiments =="
for f in 01-ollama-basic 02-ollama-think 03a-state-turn1 03b-state-no-history 03c-state-with-history 04-ollama-injection 06b-ctx-4096; do
  check "$f: request + response with eval_count" "[ -f $Q/$f.json ] && grep -q '\"eval_count\"' $R/$f.json"
done
check "01 request has think:false"    "grep -qE '\"think\": *false' $Q/01-ollama-basic.json"
check "02 request has think:true"     "grep -qE '\"think\": *true' $Q/02-ollama-think.json"
check "02 response has thinking text" "grep -q '\"thinking\"' $R/02-ollama-think.json"
check "04 request has a system msg"   "grep -q '\"system\"' $Q/04-ollama-injection.json"
check "05: 5 runs at temperature 0"   '[ "$(ls $R/05-temp-0-*.json 2>/dev/null | wc -l)" -ge 5 ]'
check "05: 5 runs at temperature 1.5" '[ "$(ls $R/05-temp-1.5-*.json 2>/dev/null | wc -l)" -ge 5 ]'
check "06a request has num_ctx 256"   "grep -qE '\"num_ctx\": *256' $Q/06a-ctx-256.json"
A=$(num prompt_eval_count $R/06a-ctx-256.json); B=$(num prompt_eval_count $R/06b-ctx-4096.json)
check "06a: prompt truncated (${A:-?} <= 256) or rejected" '[ -f $R/06a-ctx-256.json ] && { grep -q "\"error\"" $R/06a-ctx-256.json || { [ -n "$A" ] && [ "$A" -le 256 ]; }; }'
check "06b: full prompt counted (${B:-?} > 256)" '[ -n "$B" ] && [ "$B" -gt 256 ]'

echo "== OpenAI experiments =="
for f in 07-openai-basic 08-openai-injection; do
  check "$f: usage present, no error" "grep -q '\"prompt_tokens\"' $R/$f.json && grep -q '\"completion_tokens\"' $R/$f.json && ! grep -q '\"error\"' $R/$f.json"
done

echo "== Build =="
check "gradle build green"            './gradlew build -q'

echo; echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "DAY 2: READY FOR REVIEW" || { echo "DAY 2: NOT DONE"; exit 1; }
