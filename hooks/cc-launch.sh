#!/usr/bin/env bash
# cc-launch.sh — Claude Code pre-launch classifier
#
# Reads cc-config.json, classifies the task hint via regex,
# sets ANTHROPIC_MODEL + CLAUDE_CODE_EFFORT_LEVEL env vars,
# writes alwaysThinkingEnabled to settings.json, then launches claude.
# Restores alwaysThinkingEnabled on exit.
#
# Usage:
#   cc                          # launches with default settings
#   cc "redesign the auth system"  # classifies hint, picks tier
#
# Install: alias cc='~/.claude/hooks/cc-launch.sh'

CONFIG="$HOME/.claude/hooks/cc-config.json"
SETTINGS="$HOME/.claude/settings.json"
KILL_SWITCH="$HOME/.claude/hooks/.mm-kill"
AUDIT_LOG="$HOME/.claude/hooks/mm-audit.log"

# --- Kill switch check ---
if [ -f "$KILL_SWITCH" ]; then
  echo "[mm] Model Matchmaker is OFF (kill switch active). Launching with default settings."
  exec claude "$@"
fi

# --- Dependency check ---
if ! command -v jq &>/dev/null; then
  echo "[mm] Warning: jq not found. Launching claude without classification."
  exec claude "$@"
fi

if [ ! -f "$CONFIG" ]; then
  echo "[mm] Warning: $CONFIG not found. Launching claude without classification."
  exec claude "$@"
fi

# --- Join all args into hint string ---
HINT="${*:-}"

# --- Load config ---
DEFAULT_MODEL=$(jq -r '.default.model // "sonnet"' "$CONFIG")
DEFAULT_EFFORT=$(jq -r '.default.effort // "low"' "$CONFIG")
DEFAULT_THINKING=$(jq -r '.default.thinking // false' "$CONFIG")

MATCHED_MODEL="$DEFAULT_MODEL"
MATCHED_EFFORT="$DEFAULT_EFFORT"
MATCHED_THINKING="$DEFAULT_THINKING"
MATCHED_RULE="default"

# --- Override prefix detection (before rules classifier) ---
# ++ = opus + high + thinking on
# +  = opus + medium + thinking off
if [[ "$HINT" == "++"* ]]; then
  MATCHED_MODEL="opus"
  MATCHED_EFFORT="high"
  MATCHED_THINKING="true"
  MATCHED_RULE="override:++"
  HINT="${HINT:2}"  # strip prefix for cleaner audit log
elif [[ "$HINT" == "+"* ]]; then
  MATCHED_MODEL="opus"
  MATCHED_EFFORT="medium"
  MATCHED_THINKING="false"
  MATCHED_RULE="override:+"
  HINT="${HINT:1}"  # strip prefix
else
  # --- Classify hint against rules (top-to-bottom, first match wins) ---
  if [ -n "$HINT" ]; then
    RULE_COUNT=$(jq '.rules | length' "$CONFIG")
    for i in $(seq 0 $((RULE_COUNT - 1))); do
      PATTERN=$(jq -r ".rules[$i].pattern" "$CONFIG")
      NAME=$(jq -r ".rules[$i].name" "$CONFIG")
      if echo "$HINT" | grep -qiE "$PATTERN"; then
        MATCHED_MODEL=$(jq -r ".rules[$i].model" "$CONFIG")
        MATCHED_EFFORT=$(jq -r ".rules[$i].effort" "$CONFIG")
        MATCHED_THINKING=$(jq -r ".rules[$i].thinking" "$CONFIG")
        MATCHED_RULE="$NAME"
        break
      fi
    done
  fi
fi

# --- Backup current alwaysThinkingEnabled ---
PREV_THINKING=$(jq -r '.alwaysThinkingEnabled // false' "$SETTINGS" 2>/dev/null || echo "false")

# --- Race condition guard: warn if thinking was left ON unexpectedly ---
if [ "$PREV_THINKING" = "true" ] && [ "$MATCHED_THINKING" = "false" ]; then
  echo "[mm] ⚠ thinking was left ON from a previous session — resetting to off"
fi

# --- Write alwaysThinkingEnabled to settings.json ---
TMP=$(mktemp)
jq --argjson thinking "$MATCHED_THINKING" '.alwaysThinkingEnabled = $thinking' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

# --- Restore thinking on exit (trap covers normal exit + Ctrl-C + crashes) ---
restore_thinking() {
  jq --argjson thinking "$PREV_THINKING" '.alwaysThinkingEnabled = $thinking' "$SETTINGS" > /tmp/.mm-restore-tmp 2>/dev/null \
    && mv /tmp/.mm-restore-tmp "$SETTINGS"
}
trap restore_thinking EXIT

# --- Audit log ---
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"ts\":\"$TS\",\"event\":\"launch\",\"rule\":\"$MATCHED_RULE\",\"model\":\"$MATCHED_MODEL\",\"effort\":\"$MATCHED_EFFORT\",\"thinking\":$MATCHED_THINKING,\"hint\":\"${HINT:0:60}\"}" >> "$AUDIT_LOG"

# --- Print summary ---
echo "[mm] rule: $MATCHED_RULE | model: $MATCHED_MODEL | effort: $MATCHED_EFFORT | thinking: $MATCHED_THINKING"

# --- Launch Claude Code with env vars set ---
ANTHROPIC_MODEL="$MATCHED_MODEL" \
CLAUDE_CODE_EFFORT_LEVEL="$MATCHED_EFFORT" \
  claude
