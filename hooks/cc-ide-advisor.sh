#!/usr/bin/env bash
# cc-ide-advisor.sh — UserPromptSubmit hook for Claude Code IDE sessions
#
# Fires on every user message in the IDE. Classifies the prompt via
# cc-config.json regex rules and writes model + effortLevel + alwaysThinkingEnabled
# to settings.json BEFORE Claude processes the message.
#
# Supports +/++ prefix overrides: type "+fix the login bug" or "++prove this"
# directly in the IDE chat — no terminal or cc command needed.
#
# Wired into ~/.claude/settings.json UserPromptSubmit hook.
# Paired with cc-ide-restore.sh (Stop hook) which resets to defaults after each response.

KILL_SWITCH="$HOME/.claude/hooks/.mm-kill"
CONFIG="$HOME/.claude/hooks/cc-config.json"
SETTINGS="$HOME/.claude/settings.json"
AUDIT_LOG="$HOME/.claude/hooks/mm-audit.log"

# --- Kill switch: silent exit ---
[ -f "$KILL_SWITCH" ] && exit 0

# --- Dependency check ---
command -v jq &>/dev/null || exit 0
[ -f "$CONFIG" ] || exit 0
[ -f "$SETTINGS" ] || exit 0

# --- Read hook input ---
INPUT=$(cat)

# --- Extract user prompt ---
PROMPT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
# UserPromptSubmit payload has 'prompt' key
print(d.get('prompt', ''))
" 2>/dev/null)

# --- Load defaults from config ---
DEFAULT_MODEL=$(jq -r '.default.model // "sonnet"' "$CONFIG")
DEFAULT_EFFORT=$(jq -r '.default.effort // "low"' "$CONFIG")
DEFAULT_THINKING=$(jq -r '.default.thinking // false' "$CONFIG")

MATCHED_MODEL="$DEFAULT_MODEL"
MATCHED_EFFORT="$DEFAULT_EFFORT"
MATCHED_THINKING="$DEFAULT_THINKING"
MATCHED_RULE="default"

# --- Override prefix detection (++ before +) ---
# ++ = opus + high + thinking on
# +  = opus + medium + thinking off
if [[ "$PROMPT" == "++"* ]]; then
  MATCHED_MODEL="opus"
  MATCHED_EFFORT="high"
  MATCHED_THINKING="true"
  MATCHED_RULE="override:++"
elif [[ "$PROMPT" == "+"* ]]; then
  MATCHED_MODEL="opus"
  MATCHED_EFFORT="medium"
  MATCHED_THINKING="false"
  MATCHED_RULE="override:+"
else
  # --- Classify prompt against config rules (top-to-bottom, first match wins) ---
  if [ -n "$PROMPT" ]; then
    RULE_COUNT=$(jq '.rules | length' "$CONFIG")
    for i in $(seq 0 $((RULE_COUNT - 1))); do
      PATTERN=$(jq -r ".rules[$i].pattern" "$CONFIG")
      NAME=$(jq -r ".rules[$i].name" "$CONFIG")
      if echo "$PROMPT" | grep -qiE "$PATTERN"; then
        MATCHED_MODEL=$(jq -r ".rules[$i].model" "$CONFIG")
        MATCHED_EFFORT=$(jq -r ".rules[$i].effort" "$CONFIG")
        MATCHED_THINKING=$(jq -r ".rules[$i].thinking" "$CONFIG")
        MATCHED_RULE="$NAME"
        break
      fi
    done
  fi
fi

# --- Map short alias to full model ID ---
case "$MATCHED_MODEL" in
  haiku)  FULL_MODEL="claude-haiku-4-5-20251001" ;;
  sonnet) FULL_MODEL="claude-sonnet-4-6" ;;
  opus)   FULL_MODEL="claude-opus-4-6" ;;
  *)      FULL_MODEL="$MATCHED_MODEL" ;;  # pass through if already a full ID
esac

# --- Write model + effortLevel + alwaysThinkingEnabled to settings.json ---
TMP=$(mktemp)
jq --arg model "$FULL_MODEL" \
   --arg effort "$MATCHED_EFFORT" \
   --argjson thinking "$MATCHED_THINKING" \
   '.model = $model | .effortLevel = $effort | .alwaysThinkingEnabled = $thinking' \
   "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

# --- Audit log ---
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
PROMPT_SNIPPET="${PROMPT:0:60}"
echo "{\"ts\":\"$TS\",\"event\":\"ide-classify\",\"session_id\":\"$SESSION_ID\",\"rule\":\"$MATCHED_RULE\",\"model\":\"$FULL_MODEL\",\"effort\":\"$MATCHED_EFFORT\",\"thinking\":$MATCHED_THINKING,\"prompt\":\"$PROMPT_SNIPPET\"}" >> "$AUDIT_LOG"

# --- Silent exit: output nothing ---
exit 0
