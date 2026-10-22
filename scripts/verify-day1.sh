#!/usr/bin/env bash
# =============================================================================
# Week 0 / Day 1 gate. Run from the project root:   ./scripts/verify-day1.sh
#
# macOS / Linux: run in Terminal.
# Windows: run in "Git Bash" (installed with Git for Windows), NOT cmd/PowerShell.
#
# Every FAIL must be fixed before Day 2. WARNs are allowed but read them.
# =============================================================================
set -u

PASS=0; FAIL=0; WARN=0
green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
pass() { PASS=$((PASS+1)); green  "  [PASS] $*"; }
fail() { FAIL=$((FAIL+1)); red    "  [FAIL] $*"; }
warn() { WARN=$((WARN+1)); yellow "  [WARN] $*"; }
section() { printf '\n== %s ==\n' "$*"; }

cd "$(dirname "$0")/.." || exit 1

# Load .env if present (OPENAI_API_KEY, OLLAMA_MODEL). Never echo secrets.
if [ -f .env ]; then set -a; . ./.env; set +a; fi
MODEL="${OLLAMA_MODEL:-llama3.1:8b}"
APP_PORT=8080

# -----------------------------------------------------------------------------
section "1. Java"
if command -v java >/dev/null 2>&1; then
  JV=$(java -version 2>&1 | grep -m1 'version "' | sed -E 's/.*version "([^"]+)".*/\1/')
  MAJOR=${JV%%.*}
  if [ -n "$MAJOR" ] && [ "$MAJOR" -ge 21 ] 2>/dev/null; then pass "java $JV"
  else fail "java is '$JV'. Need 21+. Install Temurin 21 and fix PATH/JAVA_HOME."; fi
else
  fail "java not found on PATH"
fi
if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" -o -x "$JAVA_HOME/bin/java.exe" ]; then
  pass "JAVA_HOME=$JAVA_HOME"
else
  fail "JAVA_HOME not set or doesn't point to a JDK"
fi

# -----------------------------------------------------------------------------
section "2. Git"
if command -v git >/dev/null 2>&1; then
  pass "$(git --version)"
  [ -n "$(git config --get user.name)" ]  && pass "git user.name set"  || fail "git config --global user.name not set"
  [ -n "$(git config --get user.email)" ] && pass "git user.email set" || fail "git config --global user.email not set"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    pass "project is a git repo"
    if git rev-parse HEAD >/dev/null 2>&1; then pass "has at least one commit"; else fail "no commits yet"; fi
    if git remote get-url origin >/dev/null 2>&1; then pass "remote 'origin' = $(git remote get-url origin)"
    else fail "no GitHub remote 'origin'. Create a PUBLIC repo and push."; fi
    if [ -f .env ]; then
      if git ls-files --error-unmatch .env >/dev/null 2>&1; then
        fail ".env IS TRACKED BY GIT. Rotate your API key NOW, then: git rm --cached .env"
      else pass ".env exists and is not tracked"; fi
    fi
  else
    fail "not a git repo. Run: git init"
  fi
else
  fail "git not found"
fi

# -----------------------------------------------------------------------------
section "3. Docker"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    pass "docker daemon running"
    if docker run --rm hello-world >/dev/null 2>&1; then pass "docker run hello-world"
    else fail "docker run hello-world failed"; fi
  else
    fail "docker CLI found but daemon not running. Start Docker Desktop."
  fi
else
  fail "docker not found"
fi

# -----------------------------------------------------------------------------
section "4. Ollama (local LLM)"
if command -v ollama >/dev/null 2>&1; then
  pass "$(ollama --version 2>&1 | tail -1)"
  if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
    pass "Ollama server responding on :11434"
    if ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$MODEL"; then
      pass "model '$MODEL' pulled"
      echo "  ... asking $MODEL a question (first load can take 30-90s)"
      START=$(date +%s)
      RESP=$(curl -s --max-time 180 http://localhost:11434/api/generate \
        -d "{\"model\":\"$MODEL\",\"prompt\":\"Reply with only the word OK.\",\"stream\":false,\"options\":{\"num_predict\":10,\"temperature\":0}}")
      END=$(date +%s)
      if printf '%s' "$RESP" | grep -q '"response"'; then
        pass "model answered in $((END-START))s"
        [ $((END-START)) -gt 60 ] && warn "slow (>60s). Consider llama3.2:3b, set OLLAMA_MODEL in .env"
      else
        fail "model did not answer. Raw: $(printf '%s' "$RESP" | head -c 200)"
      fi
    else
      fail "model '$MODEL' not pulled. Run: ollama pull $MODEL"
    fi
  else
    fail "Ollama installed but server not running. Open the Ollama app or run: ollama serve"
  fi
else
  fail "ollama not found"
fi

# -----------------------------------------------------------------------------
section "5. OpenAI API key"
if [ -n "${OPENAI_API_KEY:-}" ]; then
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 https://api.openai.com/v1/models \
         -H "Authorization: Bearer $OPENAI_API_KEY")
  case "$CODE" in
    200) pass "OpenAI key valid (did you set a monthly spend limit? The script can't check that.)";;
    401) fail "OpenAI rejected the key (401). Regenerate it.";;
    429) warn "OpenAI says 429: no credits or rate-limited. Add \$5-10 credit.";;
    *)   fail "OpenAI check returned HTTP $CODE";;
  esac
else
  warn "OPENAI_API_KEY not set in .env. Day 2 compares local vs hosted; you'll need it."
fi

# -----------------------------------------------------------------------------
section "6. Build (compile + tests)"
chmod +x ./gradlew 2>/dev/null
if ./gradlew clean build --console=plain -q; then
  pass "./gradlew clean build"
else
  fail "./gradlew clean build failed. Read the FIRST error, not the last."
fi

# -----------------------------------------------------------------------------
section "7. App boots and serves HTTP"
if [ -f build/libs/app.jar ]; then
  if curl -s "http://localhost:$APP_PORT" >/dev/null 2>&1; then
    fail "port $APP_PORT already in use. Stop whatever is running there."
  else
    java -jar build/libs/app.jar > build/day1-app.log 2>&1 &
    APP_PID=$!
    UP=0
    for _ in $(seq 1 60); do
      if curl -sf "http://localhost:$APP_PORT/actuator/health" 2>/dev/null | grep -q '"UP"'; then UP=1; break; fi
      sleep 1
    done
    if [ $UP -eq 1 ]; then
      pass "/actuator/health is UP"
      PING=$(curl -s "http://localhost:$APP_PORT/api/ping")
      echo "  /api/ping -> $PING"
      printf '%s' "$PING" | grep -q '"status":"UP"' && pass "/api/ping returns status UP" || fail "/api/ping wrong response"
      printf '%s' "$PING" | grep -q '"activeProfiles"' \
        && pass "Exercise 1.1 done (activeProfiles present)" \
        || fail "Exercise 1.1 not done: /api/ping has no activeProfiles field"
    else
      fail "app didn't become healthy in 60s. See build/day1-app.log"
    fi
    kill "$APP_PID" >/dev/null 2>&1; wait "$APP_PID" 2>/dev/null
  fi
else
  fail "build/libs/app.jar missing (build step failed?)"
fi

# -----------------------------------------------------------------------------
section "8. Notes"
if [ -f docs/week0-notes.md ] && grep -q "Day 1" docs/week0-notes.md \
   && ! grep -q "TODO(day1)" docs/week0-notes.md; then
  pass "docs/week0-notes.md Day 1 section filled in"
else
  fail "Fill in the Day 1 section of docs/week0-notes.md (remove every TODO(day1))"
fi

# -----------------------------------------------------------------------------
printf '\n== RESULT: %d passed, %d failed, %d warnings ==\n' "$PASS" "$FAIL" "$WARN"
if [ "$FAIL" -eq 0 ]; then
  green "Day 1 COMPLETE. Commit, push, then start Day 2."
  exit 0
else
  red "Day 1 NOT complete. Fix every FAIL. Do not start Day 2."
  exit 1
fi
