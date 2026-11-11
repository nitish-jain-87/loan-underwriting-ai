#!/usr/bin/env bash
# Day 3 verification. Save as scripts/verify-day3.sh, commit, push, then run from the
# repo root in Git Bash:  bash scripts/verify-day3.sh
# Stop the running app first (it checks that port 8080 is free for the fail-fast test).
set -u
PASS=0; FAIL=0
ok()    { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()   { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
val()   { grep -E "^$1=" "$2" 2>/dev/null | cut -d= -f2-; }

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Not inside a git repo"; exit 1; }
J=src/main/java/com/nitish/underwriting; T=src/test/java/com/nitish/underwriting
RES=src/main/resources; D=experiments/day3

echo "== Git (portfolio gate) =="
git fetch -q origin 2>/dev/null
check "no uncommitted changes"        '[ -z "$(git status --porcelain)" ]'
check "upstream branch set"           'git rev-parse --abbrev-ref @{u}'
check "no unpushed commits"           'git rev-parse @{u} && [ -z "$(git rev-list @{u}..HEAD)" ]'
check "HEAD exists on remote"         'git ls-remote origin | grep -q "$(git rev-parse HEAD)"'

echo "== Secrets =="
check "no OpenAI key in working tree" '! git grep -qE "sk-[A-Za-z0-9_-]{20,}" -- .'
check "no OpenAI key in git history"  '! git log -p --all | grep -qE "sk-[A-Za-z0-9_-]{20,}"'
check "openai profile reads key from env" "grep -qE 'api-key:[[:space:]]*\\\$\\{OPENAI_API_KEY\\}' $RES/application-openai.yml"

echo "== Dependencies =="
check "Spring AI BOM 2.0.x"           "grep -qE 'spring-ai-bom:2\\.0\\.[0-9]+' build.gradle.kts"
check "Ollama starter"                "grep -q 'spring-ai-starter-model-ollama' build.gradle.kts"
check "OpenAI starter"                "grep -q 'spring-ai-starter-model-openai' build.gradle.kts"

echo "== Provider config =="
check "base: chat model off by default"      "grep -qE '^[[:space:]]*chat:[[:space:]]*none' $RES/application.yml"
check "local: selects ollama"                "grep -qE 'chat:[[:space:]]*ollama' $RES/application-local.yml"
check "local: model qwen3:4b"                "grep -qE 'model:[[:space:]]*qwen3:4b' $RES/application-local.yml"
check "local: think off"                     "grep -qE 'think:[[:space:]]*false' $RES/application-local.yml"
check "local: num-ctx set explicitly"        "grep -qE 'num-ctx:[[:space:]]*[0-9]+' $RES/application-local.yml"
check "openai: selects openai"               "grep -qE 'chat:[[:space:]]*openai' $RES/application-openai.yml"

echo "== Code =="
for f in $J/ai/AiProviderGuard.java $J/ai/AiConfig.java $J/intake/LoanRequest.java \
         $J/intake/ExtractionResult.java $J/intake/IntakeExtractionService.java \
         $J/api/IntakeController.java $T/ai/AiProviderGuardTest.java $T/StartupFailFastTest.java; do
  check "exists: ${f##*/}" "[ -f $f ]"
done
check "LoanRequest is a record"              "grep -q 'record LoanRequest' $J/intake/LoanRequest.java"
check "service uses BeanOutputConverter"     "grep -q 'BeanOutputConverter' $J/intake/IntakeExtractionService.java"
check "context test pins a provider profile" "grep -q '@ActiveProfiles(\"local\")' $T/UnderwritingApplicationTests.java"

echo "== Build (includes the fail-fast tests) =="
check "gradle build green"                   './gradlew build -q'

echo "== Fail-fast, for real =="
if [ -f build/libs/app.jar ]; then
  out=$(env -u SPRING_PROFILES_ACTIVE timeout 90 java -jar build/libs/app.jar --server.port=0 2>&1); rc=$?
  check "no profile: app exits non-zero"     "[ $rc -ne 0 ] && [ $rc -ne 124 ]"
  check "no profile: error names the fix"    "echo \"\$out\" | grep -q 'Exactly one AI provider profile'"
else bad "build/libs/app.jar missing"; bad "fail-fast not tested"; fi

echo "== Reliability bench (5 inputs x 4 runs) =="
for pair in qwen3-4b:qwen3:4b qwen3-8b:qwen3:8b openai:gpt-5.4-mini; do
  label=${pair%%:*}; want=${pair#*:}; S=$D/$label/summary.txt
  check "$label: summary with 20 runs"       "[ \"\$(val runs $S)\" = 20 ]"
  check "$label: answered by $want (config really applied)" \
        "[ \$(ls $D/$label/run-*.json 2>/dev/null | wc -l) -eq 20 ] && ! grep -L '\"model\"[[:space:]]*:[[:space:]]*\"$want' $D/$label/run-*.json | grep -q ."
  check "$label: no HTTP errors"             "[ \"\$(val http_errors $S)\" = 0 ]"
done
for label in qwen3-4b qwen3-8b; do
  c=$(val avg_completion_tokens $D/$label/summary.txt)
  check "$label: thinking really off (avg completion ${c:-?} < 200 tokens)" "[ -n \"$c\" ] && [ $c -lt 200 ]"
done
check "RESULTS.md generated"                 "[ -f $D/RESULTS.md ] && [ \$(grep -c '^| ' $D/RESULTS.md) -ge 4 ]"

echo; echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "DAY 3: READY FOR REVIEW" || { echo "DAY 3: NOT DONE"; exit 1; }
