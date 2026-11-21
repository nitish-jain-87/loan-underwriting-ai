#!/usr/bin/env bash
# Day 4 verification. Save as scripts/verify-day4.sh, commit, push, then run from the
# repo root in Git Bash:  bash scripts/verify-day4.sh
# Checks CONTENT, not just presence: the right advisors in the right place, the experiments
# answered by the right model, tools really called, memory really recalled and isolated.
set -u
PASS=0; FAIL=0
ok()    { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()   { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
info()  { echo "  INFO  $1"; }
check() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
val()   { grep -E "^$1=" "$2" 2>/dev/null | cut -d= -f2-; }

cd "$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Not inside a git repo"; exit 1; }
J=src/main/java/com/nitish/underwriting; T=src/test/java/com/nitish/underwriting
A=$J/assistant; RES=src/main/resources; D=experiments/day4

echo "== Git (portfolio gate) =="
git fetch -q origin 2>/dev/null
check "no uncommitted changes"        '[ -z "$(git status --porcelain)" ]'
check "upstream branch set"           'git rev-parse --abbrev-ref @{u}'
check "no unpushed commits"           'git rev-parse @{u} && [ -z "$(git rev-list @{u}..HEAD)" ]'
check "HEAD exists on remote"         'git ls-remote origin | grep -q "$(git rev-parse HEAD)"'

echo "== Secrets =="
check "no OpenAI key in working tree" '! git grep -qE "sk-[A-Za-z0-9_-]{20,}" -- .'
check "no OpenAI key in git history"  '! git log -p --all | grep -qE "sk-[A-Za-z0-9_-]{20,}"'

echo "== Code exists =="
for f in $A/CreditScore.java $A/CreditBureau.java $A/ToolCallRecord.java $A/UnderwritingTools.java \
         $A/AssistantReply.java $A/AssistantConfig.java $A/AssistantService.java $J/api/AssistantController.java \
         $T/assistant/UnderwritingToolsTest.java $T/assistant/ChatMemoryWindowTest.java; do
  check "exists: ${f##*/}" "[ -f $f ]"
done

echo "== Tools =="
check "two @Tool methods"                         "[ \$(grep -c '@Tool(' $A/UnderwritingTools.java) -ge 2 ]"
check "parameters described with @ToolParam"      "grep -q '@ToolParam(' $A/UnderwritingTools.java"
check "tools are per request, not a Spring bean"  "! grep -qE '@(Component|Service|Bean)' $A/UnderwritingTools.java"
check "applicant id validated before lookup"      "grep -q 'APP-' $A/UnderwritingTools.java && grep -q 'IllegalArgumentException' $A/UnderwritingTools.java"
check "DTI computed in Java with BigDecimal"      "grep -q 'BigDecimal' $A/UnderwritingTools.java && grep -q 'RoundingMode' $A/UnderwritingTools.java"
check "tools passed per request (.tools)"         "grep -q '\.tools(' $A/AssistantService.java"
check "tool-call limits set (not 40/150 default)" "grep -qE 'max-total-tool-calls:[[:space:]]*[0-9]' $RES/application.yml && grep -qE 'max-calls-per-tool-default:[[:space:]]*[0-9]' $RES/application.yml"

echo "== Memory =="
check "memory advisor in the assistant"           "grep -q 'MessageChatMemoryAdvisor' $A/AssistantService.java"
check "conversation id passed to the advisor"     "grep -q 'ChatMemory.CONVERSATION_ID' $A/AssistantService.java"
check "window size chosen explicitly"             "grep -qE 'maxMessages\\([0-9]+\\)' $A/AssistantConfig.java"
check "shared ChatClient has NO default advisors/tools" "! grep -qE 'defaultAdvisors|defaultTools' $J/ai/AiConfig.java"
check "intake extraction stays stateless"         "! grep -qE 'ChatMemory|\\.tools\\(' $J/intake/IntakeExtractionService.java"
check "server issues the conversation id"         "grep -q 'UUID.randomUUID' $J/api/AssistantController.java"
check "client-sent ids must be UUIDs (@Pattern)"  "grep -q '@Pattern' $J/api/AssistantController.java"

echo "== Build + tests =="
check "gradle build green"                        './gradlew build -q'
R=build/test-results/test
for t in UnderwritingToolsTest ChatMemoryWindowTest; do
  x=$R/TEST-com.nitish.underwriting.assistant.$t.xml
  check "$t ran with 0 failures" "[ -f $x ] && grep -q 'failures=\"0\"' $x && grep -q 'errors=\"0\"' $x"
done
check "UnderwritingToolsTest has >= 5 tests"      "grep -oE 'tests=\"[0-9]+\"' $R/TEST-com.nitish.underwriting.assistant.UnderwritingToolsTest.xml | grep -qE '\"([5-9]|[1-9][0-9])\"'"

echo "== Raw wire (Step 1) =="
check "wire-A (no tools) saved"                   "[ -f $D/wire-A.json ] && grep -q 'prompt_eval_count' $D/wire-A.json"
check "wire-B: model asked for getCreditScore"    "grep -q 'tool_calls' $D/wire-B.json && grep -q 'getCreditScore' $D/wire-B.json"
check "wire-C: final answer contains 712"         "grep -q '712' $D/wire-C.json"

echo "== Bench =="
for pair in qwen3-4b:qwen3:4b openai:gpt-5.4-mini; do
  label=${pair%%:*}; want=${pair#*:}; S=$D/$label/summary.txt
  check "$label: summary with 15 runs"            "[ \"\$(val runs $S)\" = 15 ]"
  check "$label: answered by $want (config really applied)" \
        "[ \$(ls $D/$label/{score,dti,unknown,notool,inject}-*.json 2>/dev/null | wc -l) -eq 15 ] && ! grep -L '\"model\"[[:space:]]*:[[:space:]]*\"$want' $D/$label/{score,dti,unknown,notool,inject}-*.json | grep -q ."
  check "$label: no HTTP errors"                  "[ \"\$(val http_errors $S)\" = 0 ]"
  check "$label: tools really wired (getCreditScore ran for APP-1001)" \
        "grep -l 'getCreditScore' $D/$label/score-*.json | xargs grep -l 'APP-1001' | grep -q ."
  check "$label: memory isolation (new conversation knew nothing)" "[ \"\$(val memory_isolation $S)\" = PASS ]"
  check "$label: unknown conversation id rejected (400)" "[ \"\$(val bad_conversation_id_http $S)\" = 400 ]"
  r=$(val memory_recall $S)
  if [ "$label" = openai ]; then check "openai: memory recall (turn 2 used APP-1003)" "[ \"$r\" = PASS ]"
  else info "$label: memory recall = ${r:-?} (a FAIL here is a model finding, not a wiring bug, IF openai passes)"; fi
  info "$label: passes score $(val pass_score $S)/3 dti $(val pass_dti $S)/3 unknown $(val pass_unknown $S)/3 inject $(val pass_inject $S)/3 notool $(val pass_notool $S)/3"
done
check "RESULTS.md generated"                      "[ -f $D/RESULTS.md ] && [ \$(grep -c '^| ' $D/RESULTS.md) -ge 3 ]"

echo; echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "DAY 4: READY FOR REVIEW" || { echo "DAY 4: NOT DONE"; exit 1; }
