#!/usr/bin/env bash
# cc-effort-advisor.sh — Silent PreToolUse hook for Claude Code
#
# Fires on Agent tool calls only. Classifies the subagent prompt via
# cc-config.json regex rules. Outputs NOTHING to Claude (zero token overhead).
# Writes classification result to audit log for analytics only.
#
# Wired into ~/.claude/settings.json PreToolUse with matcher: Agent
#
# For all non-Agent tools: immediate silent exit (no overhead at all).

KILL_SWITCH="$HOME/.claude/hooks/.mm-kill"
CONFIG="$HOME/.claude/hooks/cc-config.json"
AUDIT_LOG="$HOME/.claude/hooks/mm-audit.log"

# --- Kill switch: silent exit ---
[ -f "$KILL_SWITCH" ] && exit 0

# --- Read hook input ---
INPUT=$(cat)

# --- Only act on Agent tool calls ---
TOOL=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
[ "$TOOL" != "Agent" ] && exit 0

# --- Dependency check: if jq missing, silent exit ---
command -v jq &>/dev/null || exit 0
[ -f "$CONFIG" ] || exit 0

# --- Extract subagent prompt ---
PROMPT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
inp = d.get('tool_input', {})
if isinstance(inp, dict):
    print(inp.get('prompt', ''))
else:
    print('')
" 2>/dev/null)

[ -z "$PROMPT" ] && exit 0

# --- Classify prompt against config rules ---
DEFAULT_MODEL=$(jq -r '.default.model // "sonnet"' "$CONFIG")
DEFAULT_EFFORT=$(jq -r '.default.effort // "low"' "$CONFIG")
MATCHED_MODEL="$DEFAULT_MODEL"
MATCHED_EFFORT="$DEFAULT_EFFORT"
MATCHED_RULE="default"

RULE_COUNT=$(jq '.rules | length' "$CONFIG")
for i in $(seq 0 $((RULE_COUNT - 1))); do
  PATTERN=$(jq -r ".rules[$i].pattern" "$CONFIG")
  NAME=$(jq -r ".rules[$i].name" "$CONFIG")
  if echo "$PROMPT" | grep -qiE "$PATTERN"; then
    MATCHED_MODEL=$(jq -r ".rules[$i].model" "$CONFIG")
    MATCHED_EFFORT=$(jq -r ".rules[$i].effort" "$CONFIG")
    MATCHED_RULE="$NAME"
    break
  fi
done

# --- Log to audit (no stdout — zero token overhead) ---
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
PROMPT_SNIPPET="${PROMPT:0:60}"
echo "{\"ts\":\"$TS\",\"event\":\"subagent\",\"session_id\":\"$SESSION_ID\",\"rule\":\"$MATCHED_RULE\",\"model\":\"$MATCHED_MODEL\",\"effort\":\"$MATCHED_EFFORT\",\"prompt\":\"$PROMPT_SNIPPET\"}" >> "$AUDIT_LOG"

# --- Silent exit: output nothing to Claude ---
exit 0
