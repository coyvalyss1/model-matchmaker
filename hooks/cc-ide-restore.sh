#!/usr/bin/env bash
# cc-ide-restore.sh — Stop hook for Claude Code IDE sessions
#
# Fires when Claude finishes responding. Resets model + effortLevel +
# alwaysThinkingEnabled back to the defaults in cc-config.json.
#
# This ensures that a +/++ override or a deep-work classification doesn't
# persist into the next message (each message gets freshly classified).
#
# Wired into ~/.claude/settings.json Stop hook.

KILL_SWITCH="$HOME/.claude/hooks/.mm-kill"
CONFIG="$HOME/.claude/hooks/cc-config.json"
SETTINGS="$HOME/.claude/settings.json"

# --- Kill switch: silent exit ---
[ -f "$KILL_SWITCH" ] && exit 0

# --- Dependency check ---
command -v jq &>/dev/null || exit 0
[ -f "$CONFIG" ] || exit 0
[ -f "$SETTINGS" ] || exit 0

# --- Read defaults from config ---
DEFAULT_MODEL=$(jq -r '.default.model // "sonnet"' "$CONFIG")
DEFAULT_EFFORT=$(jq -r '.default.effort // "low"' "$CONFIG")
DEFAULT_THINKING=$(jq -r '.default.thinking // false' "$CONFIG")

# --- Map short alias to full model ID ---
case "$DEFAULT_MODEL" in
  haiku)  FULL_DEFAULT="claude-haiku-4-5-20251001" ;;
  sonnet) FULL_DEFAULT="claude-sonnet-4-6" ;;
  opus)   FULL_DEFAULT="claude-opus-4-6" ;;
  *)      FULL_DEFAULT="$DEFAULT_MODEL" ;;
esac

# --- Restore settings.json to defaults ---
TMP=$(mktemp)
jq --arg model "$FULL_DEFAULT" \
   --arg effort "$DEFAULT_EFFORT" \
   --argjson thinking "$DEFAULT_THINKING" \
   '.model = $model | .effortLevel = $effort | .alwaysThinkingEnabled = $thinking' \
   "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

exit 0
