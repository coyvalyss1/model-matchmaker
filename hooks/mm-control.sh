#!/usr/bin/env bash
# mm-control.sh — Model Matchmaker kill switch + status
#
# Source this file once in ~/.zshrc:
#   source ~/model-matchmaker/hooks/mm-control.sh
#
# Provides three shell functions:
#   mm-off     Disable all Model Matchmaker automation instantly
#   mm-on      Re-enable Model Matchmaker
#   mm-status  Show current state, config summary, and recent audit entries

MM_HOOKS_DIR="$HOME/.claude/hooks"
MM_KILL="$MM_HOOKS_DIR/.mm-kill"
MM_HOOK_BACKUP="$MM_HOOKS_DIR/.mm-hook-backup.json"
SETTINGS="$HOME/.claude/settings.json"
AUDIT_LOG="$MM_HOOKS_DIR/mm-audit.log"
CONFIG="$MM_HOOKS_DIR/cc-config.json"

mm-off() {
  # 1. Save current PreToolUse hook entry before removing it
  if command -v jq &>/dev/null && [ -f "$SETTINGS" ]; then
    jq '.hooks.PreToolUse // []' "$SETTINGS" > "$MM_HOOK_BACKUP" 2>/dev/null
  fi

  # 2. Create kill switch file
  touch "$MM_KILL"

  # 3. Remove cc-effort-advisor PreToolUse hook from settings.json
  if command -v jq &>/dev/null && [ -f "$SETTINGS" ]; then
    TMP=$(mktemp)
    jq 'if .hooks.PreToolUse then
          .hooks.PreToolUse = [.hooks.PreToolUse[] | select(.hooks[0].command | test("cc-effort-advisor") | not)]
        else . end' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  fi

  echo "[mm] Model Matchmaker OFF — Claude Code running at default settings."
  echo "     Run mm-on to re-enable."
}

mm-on() {
  # 1. Remove kill switch
  rm -f "$MM_KILL"

  # 2. Restore PreToolUse hook from backup
  if command -v jq &>/dev/null && [ -f "$SETTINGS" ]; then
    if [ -f "$MM_HOOK_BACKUP" ]; then
      TMP=$(mktemp)
      BACKUP_CONTENT=$(cat "$MM_HOOK_BACKUP")
      # Only restore if cc-effort-advisor isn't already present
      ALREADY=$(jq '[.hooks.PreToolUse // [] | .[] | .hooks[0].command | test("cc-effort-advisor")] | any' "$SETTINGS" 2>/dev/null)
      if [ "$ALREADY" != "true" ]; then
        jq --argjson hooks "$BACKUP_CONTENT" '.hooks.PreToolUse = $hooks' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
      fi
    else
      echo "[mm] Warning: no backup found (.mm-hook-backup.json missing)."
      echo "     Re-add the PreToolUse hook manually or re-run the install script."
    fi
  fi

  echo "[mm] Model Matchmaker ON."
}

mm-status() {
  echo ""
  echo "=== Model Matchmaker Status ==="
  echo ""

  # Enabled/disabled
  if [ -f "$MM_KILL" ]; then
    echo "  State:    OFF (kill switch active)"
  else
    HOOK_PRESENT=$(jq '[.hooks.PreToolUse // [] | .[] | .hooks[0].command | test("cc-effort-advisor")] | any' "$SETTINGS" 2>/dev/null)
    if [ "$HOOK_PRESENT" = "true" ]; then
      echo "  State:    ON"
    else
      echo "  State:    ON (kill switch inactive, but PreToolUse hook not found in settings.json)"
    fi
  fi

  # Current settings.json model/effort/thinking
  if command -v jq &>/dev/null && [ -f "$SETTINGS" ]; then
    MODEL=$(jq -r '.model // "not set"' "$SETTINGS")
    EFFORT=$(jq -r '.effortLevel // "not set"' "$SETTINGS")
    THINKING=$(jq -r '.alwaysThinkingEnabled // false' "$SETTINGS")
    echo "  settings.json: model=$MODEL | effortLevel=$EFFORT | alwaysThinkingEnabled=$THINKING"
  fi

  # Active config rules
  if command -v jq &>/dev/null && [ -f "$CONFIG" ]; then
    echo ""
    echo "  Active rules (cc-config.json):"
    DEFAULT_MODEL=$(jq -r '.default.model' "$CONFIG")
    DEFAULT_EFFORT=$(jq -r '.default.effort' "$CONFIG")
    DEFAULT_THINKING=$(jq -r '.default.thinking' "$CONFIG")
    echo "    default → model:$DEFAULT_MODEL effort:$DEFAULT_EFFORT thinking:$DEFAULT_THINKING"
    RULE_COUNT=$(jq '.rules | length' "$CONFIG")
    for i in $(seq 0 $((RULE_COUNT - 1))); do
      NAME=$(jq -r ".rules[$i].name" "$CONFIG")
      RMODEL=$(jq -r ".rules[$i].model" "$CONFIG")
      REFFORT=$(jq -r ".rules[$i].effort" "$CONFIG")
      RTHINKING=$(jq -r ".rules[$i].thinking" "$CONFIG")
      PATTERN=$(jq -r ".rules[$i].pattern" "$CONFIG")
      echo "    $NAME → model:$RMODEL effort:$REFFORT thinking:$RTHINKING  [/$PATTERN/]"
    done
  fi

  # Recent audit entries
  if [ -f "$AUDIT_LOG" ]; then
    echo ""
    echo "  Recent audit (last 5):"
    tail -5 "$AUDIT_LOG" | while IFS= read -r line; do
      echo "    $line"
    done
  else
    echo ""
    echo "  Audit log: no entries yet"
  fi

  echo ""
}
