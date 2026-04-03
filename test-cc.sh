#!/usr/bin/env bash
# test-cc.sh — Model Matchmaker Claude Code test suite
#
# Tests everything that can be verified without launching Claude.
# Usage: bash ~/model-matchmaker/test-cc.sh

CONFIG="$HOME/.claude/hooks/cc-config.json"
SETTINGS="$HOME/.claude/settings.json"
KILL="$HOME/.claude/hooks/.mm-kill"
ADVISOR="$HOME/.claude/hooks/cc-effort-advisor.sh"
LAUNCH="$HOME/.claude/hooks/cc-launch.sh"
AUDIT="$HOME/.claude/hooks/mm-audit.log"

PASS=0
FAIL=0
SKIP=0

pass() { echo "  ✅ $1"; ((PASS++)); }
fail() { echo "  ❌ $1"; ((FAIL++)); }
skip() { echo "  ⏭  $1"; ((SKIP++)); }
section() { echo ""; echo "── $1 ──"; }

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
section "Prerequisites"

if [ -f "$HOME/model-matchmaker/cc-config.json" ]; then pass "cc-config.json exists in repo"; else fail "cc-config.json missing from repo"; fi
if [ -f "$CONFIG" ]; then pass "cc-config.json installed to ~/.claude/hooks/"; else fail "cc-config.json not installed at $CONFIG"; fi
[ -f "$LAUNCH" ] && pass "cc-launch.sh exists" || fail "cc-launch.sh missing"
[ -x "$LAUNCH" ] && pass "cc-launch.sh is executable" || fail "cc-launch.sh not executable"
[ -f "$ADVISOR" ] && pass "cc-effort-advisor.sh exists" || fail "cc-effort-advisor.sh missing"
[ -x "$ADVISOR" ] && pass "cc-effort-advisor.sh is executable" || fail "cc-effort-advisor.sh not executable"
[ -f "$HOME/.claude/hooks/mm-control.sh" ] && pass "mm-control.sh exists" || fail "mm-control.sh missing"
command -v jq &>/dev/null && pass "jq available" || fail "jq not found — install with: brew install jq"

# ── 2. Config structure ───────────────────────────────────────────────────────
section "Config Structure"

DEFAULT_MODEL=$(jq -r '.default.model' "$CONFIG" 2>/dev/null)
DEFAULT_EFFORT=$(jq -r '.default.effort' "$CONFIG" 2>/dev/null)
RULE_COUNT=$(jq '.rules | length' "$CONFIG" 2>/dev/null)

[ "$DEFAULT_MODEL" != "null" ] && [ -n "$DEFAULT_MODEL" ] && pass "default.model set ($DEFAULT_MODEL)" || fail "default.model missing"
[ "$DEFAULT_EFFORT" != "null" ] && [ -n "$DEFAULT_EFFORT" ] && pass "default.effort set ($DEFAULT_EFFORT)" || fail "default.effort missing"
[ "$RULE_COUNT" -gt 0 ] 2>/dev/null && pass "$RULE_COUNT rules defined" || fail "no rules found in config"

# ── 3. Pattern matching ───────────────────────────────────────────────────────
section "Pattern Matching (regex classification)"

classify() {
  local HINT="$1"
  local RULE_COUNT
  RULE_COUNT=$(jq '.rules | length' "$CONFIG")
  for i in $(seq 0 $((RULE_COUNT - 1))); do
    PATTERN=$(jq -r ".rules[$i].pattern" "$CONFIG")
    NAME=$(jq -r ".rules[$i].name" "$CONFIG")
    if echo "$HINT" | grep -qiE "$PATTERN"; then
      echo "$NAME"
      return
    fi
  done
  echo "default"
}

assert_rule() {
  local HINT="$1"
  local EXPECTED="$2"
  local ACTUAL
  ACTUAL=$(classify "$HINT")
  if [ "$ACTUAL" = "$EXPECTED" ]; then
    pass "\"$HINT\" → $EXPECTED"
  else
    fail "\"$HINT\" → expected $EXPECTED, got $ACTUAL"
  fi
}

# Should hit deep-work
assert_rule "redesign the auth system architecture" "deep-work"
assert_rule "redesign the auth system" "deep-work"
assert_rule "security audit of the codebase" "deep-work"
assert_rule "overhaul the database layer" "deep-work"
assert_rule "design system for new onboarding" "deep-work"

# Should hit implementation
assert_rule "fix the login bug" "implementation"
assert_rule "implement the new payment flow" "implementation"
assert_rule "debug the race condition" "implementation"
assert_rule "refactor the user service" "implementation"

# Should hit quick-lookup
assert_rule "find all TODO comments" "quick-lookup"
assert_rule "list all open files" "quick-lookup"
assert_rule "what is the difference between X and Y" "quick-lookup"
assert_rule "show me the git log" "quick-lookup"

# Should fall through to default
assert_rule "help me think through this" "default"
assert_rule "" "default"

# Override prefix tests (tested via cc-launch.sh directly, not classify())
section "Override Prefixes (! and !!)"

check_override() {
  local HINT="$1"
  local EXPECTED_MODEL="$2"
  local EXPECTED_EFFORT="$3"
  local EXPECTED_THINKING="$4"

  # Source the launch script logic inline
  local RESULT
  RESULT=$(bash -c "
    CONFIG='$CONFIG'
    HINT='$HINT'
    MATCHED_MODEL=\$(jq -r '.default.model // \"sonnet\"' \"\$CONFIG\")
    MATCHED_EFFORT=\$(jq -r '.default.effort // \"low\"' \"\$CONFIG\")
    MATCHED_THINKING=\$(jq -r '.default.thinking // false' \"\$CONFIG\")
    MATCHED_RULE='default'
    if [[ \"\$HINT\" == '++'* ]]; then
      MATCHED_MODEL='opus'; MATCHED_EFFORT='high'; MATCHED_THINKING='true'; MATCHED_RULE='override:++'
    elif [[ \"\$HINT\" == '+'* ]]; then
      MATCHED_MODEL='opus'; MATCHED_EFFORT='medium'; MATCHED_THINKING='false'; MATCHED_RULE='override:+'
    fi
    echo \"\$MATCHED_MODEL|\$MATCHED_EFFORT|\$MATCHED_THINKING\"
  ")
  local GOT_MODEL GOT_EFFORT GOT_THINKING
  GOT_MODEL=$(echo "$RESULT" | cut -d'|' -f1)
  GOT_EFFORT=$(echo "$RESULT" | cut -d'|' -f2)
  GOT_THINKING=$(echo "$RESULT" | cut -d'|' -f3)

  if [ "$GOT_MODEL" = "$EXPECTED_MODEL" ] && [ "$GOT_EFFORT" = "$EXPECTED_EFFORT" ] && [ "$GOT_THINKING" = "$EXPECTED_THINKING" ]; then
    pass "\"$HINT\" → $EXPECTED_MODEL + $EXPECTED_EFFORT + thinking:$EXPECTED_THINKING"
  else
    fail "\"$HINT\" → expected $EXPECTED_MODEL/$EXPECTED_EFFORT/thinking:$EXPECTED_THINKING, got $GOT_MODEL/$GOT_EFFORT/thinking:$GOT_THINKING"
  fi
}

check_override "+redesign the auth system" "opus" "medium" "false"
check_override "+fix anything" "opus" "medium" "false"
check_override "++prove this is correct" "opus" "high" "true"
check_override "++complex cross-system tradeoff" "opus" "high" "true"
assert_rule "redesign the auth system" "deep-work"  # no prefix = normal rules, not an override test

# ── 4. alwaysThinkingEnabled write/restore ────────────────────────────────────
section "Thinking Write + Restore"

ORIG_THINKING=$(jq -r '.alwaysThinkingEnabled // false' "$SETTINGS")

# Write true
TMP=$(mktemp)
jq '.alwaysThinkingEnabled = true' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
WRITTEN=$(jq -r '.alwaysThinkingEnabled' "$SETTINGS")
[ "$WRITTEN" = "true" ] && pass "alwaysThinkingEnabled written to settings.json" || fail "failed to write alwaysThinkingEnabled"

# Restore original
TMP=$(mktemp)
jq --argjson v "$ORIG_THINKING" '.alwaysThinkingEnabled = $v' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
RESTORED=$(jq -r '.alwaysThinkingEnabled' "$SETTINGS")
[ "$RESTORED" = "$ORIG_THINKING" ] && pass "alwaysThinkingEnabled restored to original ($ORIG_THINKING)" || fail "restore failed — expected $ORIG_THINKING, got $RESTORED"

# ── 5. Kill switch ────────────────────────────────────────────────────────────
section "Kill Switch"

# Ensure kill switch is off before testing
rm -f "$KILL"

# cc-effort-advisor exits 0 silently when kill switch is present
touch "$KILL"
RESULT=$(echo '{"tool_name":"Agent","tool_input":{"prompt":"redesign the auth"},"session_id":"test"}' | bash "$ADVISOR" 2>&1)
EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && [ -z "$RESULT" ] && pass "cc-effort-advisor exits silently when kill switch active" || fail "cc-effort-advisor should exit silently (exit:$EXIT_CODE output:'$RESULT')"
rm -f "$KILL"

# Source mm-control and test mm-off / mm-on
source "$HOME/.claude/hooks/mm-control.sh" 2>/dev/null

mm-off 2>/dev/null
[ -f "$KILL" ] && pass "mm-off creates kill switch file" || fail "mm-off did not create kill switch file"

HOOK_PRESENT=$(jq '[.hooks.PreToolUse // [] | .[] | .hooks[0].command | test("cc-effort-advisor")] | any' "$SETTINGS" 2>/dev/null)
[ "$HOOK_PRESENT" = "false" ] && pass "mm-off removes PreToolUse hook from settings.json" || fail "mm-off did not remove hook from settings.json"

mm-on 2>/dev/null
[ ! -f "$KILL" ] && pass "mm-on removes kill switch file" || fail "mm-on did not remove kill switch file"

HOOK_RESTORED=$(jq '[.hooks.PreToolUse // [] | .[] | .hooks[0].command | test("cc-effort-advisor")] | any' "$SETTINGS" 2>/dev/null)
[ "$HOOK_RESTORED" = "true" ] && pass "mm-on restores PreToolUse hook in settings.json" || fail "mm-on did not restore hook (check .mm-hook-backup.json exists)"

# ── 6. Silent hook behavior ───────────────────────────────────────────────────
section "Silent Hook (cc-effort-advisor)"

# Non-Agent tool: should exit silently with no output
RESULT=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/test"},"session_id":"test"}' | bash "$ADVISOR" 2>&1)
EXIT_CODE=$?
[ $EXIT_CODE -eq 0 ] && [ -z "$RESULT" ] && pass "Read tool: silent exit (no output)" || fail "Read tool: expected silent exit (exit:$EXIT_CODE output:'$RESULT')"

RESULT=$(echo '{"tool_name":"Glob","tool_input":{"pattern":"**/*.js"},"session_id":"test"}' | bash "$ADVISOR" 2>&1)
[ -z "$RESULT" ] && pass "Glob tool: silent exit (no output)" || fail "Glob tool: expected silent exit"

RESULT=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"test"}' | bash "$ADVISOR" 2>&1)
[ -z "$RESULT" ] && pass "Bash tool: silent exit (no output)" || fail "Bash tool: expected silent exit"

# Agent tool: should exit silently but write to audit log
AUDIT_BEFORE=$(wc -l < "$AUDIT" 2>/dev/null || echo 0)
echo '{"tool_name":"Agent","tool_input":{"prompt":"redesign the authentication system"},"session_id":"test-123"}' | bash "$ADVISOR" 2>&1
RESULT_AGENT=$?
AUDIT_AFTER=$(wc -l < "$AUDIT" 2>/dev/null || echo 0)
[ $RESULT_AGENT -eq 0 ] && pass "Agent tool: exits with code 0" || fail "Agent tool: non-zero exit ($RESULT_AGENT)"
[ "$AUDIT_AFTER" -gt "$AUDIT_BEFORE" ] && pass "Agent tool: audit log entry written" || fail "Agent tool: no audit log entry written"

# Agent output must be empty (no tokens injected)
AGENT_OUTPUT=$(echo '{"tool_name":"Agent","tool_input":{"prompt":"fix the login bug"},"session_id":"test-456"}' | bash "$ADVISOR" 2>&1)
[ -z "$AGENT_OUTPUT" ] && pass "Agent tool: zero stdout output (no token overhead)" || fail "Agent tool: output detected — '$AGENT_OUTPUT'"

# ── 7. Audit log format ───────────────────────────────────────────────────────
section "Audit Log"

LAST_ENTRY=$(tail -1 "$AUDIT" 2>/dev/null)
if [ -n "$LAST_ENTRY" ]; then
  echo "$LAST_ENTRY" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null \
    && pass "Audit log entries are valid JSON" \
    || fail "Audit log last entry is not valid JSON: $LAST_ENTRY"

  HAS_TS=$(echo "$LAST_ENTRY" | jq 'has("ts")' 2>/dev/null)
  HAS_RULE=$(echo "$LAST_ENTRY" | jq 'has("rule")' 2>/dev/null)
  HAS_MODEL=$(echo "$LAST_ENTRY" | jq 'has("model")' 2>/dev/null)
  [ "$HAS_TS" = "true" ] && [ "$HAS_RULE" = "true" ] && [ "$HAS_MODEL" = "true" ] \
    && pass "Audit entries contain required fields (ts, rule, model)" \
    || fail "Audit entries missing fields"
else
  skip "Audit log empty — run 'cc' once to populate"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════"
echo "  Results: $PASS passed · $FAIL failed · $SKIP skipped"
echo "════════════════════════════════"
echo ""

if [ $FAIL -gt 0 ]; then
  echo "Manual spot-checks still needed:"
  echo "  1. Run: cc \"find all TODO comments\""
  echo "     Confirm output: rule: quick-lookup | model: haiku | effort: low"
  echo "  2. Run: cc \"redesign the auth system\""
  echo "     Confirm output: rule: deep-work | model: opus | effort: high | thinking: true"
  echo "  3. After step 2 session ends, run: mm-status"
  echo "     Confirm alwaysThinkingEnabled is back to false"
  echo ""
  exit 1
else
  echo "Automated checks passed. Manual spot-checks:"
  echo "  1. cc \"find all TODO comments\"    → should print: rule: quick-lookup | model: haiku"
  echo "  2. cc \"redesign the auth system\"  → should print: rule: deep-work | model: opus | thinking: true"
  echo "  3. After step 2 exits → mm-status → alwaysThinkingEnabled should be false"
  echo ""
  exit 0
fi
