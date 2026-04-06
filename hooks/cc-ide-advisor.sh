#!/usr/bin/env bash
# cc-ide-advisor.sh — UserPromptSubmit hook for Claude Code IDE sessions (Three-Tier)
#
# Fires on every user message in the IDE. Classifies the prompt via cc-config.json
# and uses a three-tier approach for cost optimization:
#
# Tier 1 (Silent): Pass through with effortLevel optimization when cost delta is small
# Tier 2 (Clipboard): Block + copy prompt to clipboard for expensive mismatches
# Tier 3 (Auto): Full automation when auto-switch is enabled (opt-in)
#
# Supports +/++ prefix overrides: "+fix bug" or "++prove theorem"
# Supports ! prefix to bypass blocking entirely
#
# Wired into ~/.claude/settings.json UserPromptSubmit hook.
# Paired with cc-ide-restore.sh (Stop hook) which resets to defaults after each response.

KILL_SWITCH="$HOME/.claude/hooks/.mm-kill"
CONFIG="$HOME/.claude/hooks/cc-config.json"
SETTINGS="$HOME/.claude/settings.json"
AUDIT_LOG="$HOME/.claude/hooks/mm-audit.log"
AUTO_SWITCH_FLAG="$HOME/.claude/hooks/.mm-auto-switch-enabled"
PENDING_PROMPT_FILE="$HOME/.claude/hooks/.pending-prompt.txt"

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
print(d.get('prompt', ''))
" 2>/dev/null)

# --- Handle ! override prefix (bypass all blocking) ---
if [[ "$PROMPT" == "!"* ]]; then
  # Strip prefix and pass through
  PROMPT="${PROMPT:1}"
  IS_OVERRIDE=true
else
  IS_OVERRIDE=false
fi

# --- Handle slash commands (pass through without classification) ---
if [[ "$PROMPT" == "/"* ]]; then
  # Slash command like /model or /compact — pass through immediately
  exit 0
fi

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
  *)      FULL_MODEL="$MATCHED_MODEL" ;;
esac

# --- Read current session model from settings.json ---
CURRENT_MODEL=$(jq -r '.model // "claude-sonnet-4-6"' "$SETTINGS")

# Extract short alias from current model
case "$CURRENT_MODEL" in
  *haiku*)  CURRENT_ALIAS="haiku" ;;
  *opus*)   CURRENT_ALIAS="opus" ;;
  *)        CURRENT_ALIAS="sonnet" ;;
esac

# --- Three-Tier Decision Logic ---

# If ! override prefix, pass through regardless of mismatch
if [ "$IS_OVERRIDE" = true ]; then
  TIER="override"
  ACTION="pass-through"
  
# If models match, pass through silently
elif [ "$MATCHED_MODEL" = "$CURRENT_ALIAS" ]; then
  TIER="match"
  ACTION="pass-through"
  
# Expensive mismatches: opus → haiku or opus → sonnet (save $0.80-5.00)
elif [ "$CURRENT_ALIAS" = "opus" ] && [ "$MATCHED_MODEL" != "opus" ]; then
  TIER="expensive-mismatch"
  ACTION="block"
  
# Upward mismatches: haiku/sonnet → higher tier (add hint but pass through)
elif [ "$CURRENT_ALIAS" = "haiku" ] && [ "$MATCHED_MODEL" = "sonnet" ]; then
  TIER="upward-hint"
  ACTION="pass-through-with-hint"
  
elif [ "$CURRENT_ALIAS" = "haiku" ] && [ "$MATCHED_MODEL" = "opus" ]; then
  TIER="upward-hint"
  ACTION="pass-through-with-hint"
  
elif [ "$CURRENT_ALIAS" = "sonnet" ] && [ "$MATCHED_MODEL" = "opus" ]; then
  TIER="upward-hint"
  ACTION="pass-through-with-hint"
  
# Small overpay: sonnet → haiku task (overpay ~$0.03-0.10, accept for zero friction)
elif [ "$CURRENT_ALIAS" = "sonnet" ] && [ "$MATCHED_MODEL" = "haiku" ]; then
  TIER="small-overpay"
  ACTION="pass-through"
  
# Default: pass through
else
  TIER="unknown"
  ACTION="pass-through"
fi

# --- Write effort + thinking to settings.json (always, even when blocking) ---
TMP=$(mktemp)
jq --arg model "$CURRENT_MODEL" \
   --arg effort "$MATCHED_EFFORT" \
   --argjson thinking "$MATCHED_THINKING" \
   '.model = $model | .effortLevel = $effort | .alwaysThinkingEnabled = $thinking' \
   "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"

# --- Audit log ---
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
PROMPT_SNIPPET="${PROMPT:0:60}"
echo "{\"ts\":\"$TS\",\"event\":\"ide-classify\",\"session_id\":\"$SESSION_ID\",\"rule\":\"$MATCHED_RULE\",\"recommended\":\"$MATCHED_MODEL\",\"current\":\"$CURRENT_ALIAS\",\"tier\":\"$TIER\",\"action\":\"$ACTION\",\"effort\":\"$MATCHED_EFFORT\",\"thinking\":$MATCHED_THINKING,\"prompt\":\"$PROMPT_SNIPPET\"}" >> "$AUDIT_LOG"

# --- Execute action based on tier ---

if [ "$ACTION" = "block" ]; then
  # Tier 2/3: Expensive mismatch — block and copy to clipboard
  echo "$PROMPT" | pbcopy 2>/dev/null
  
  # Calculate cost savings message
  if [ "$MATCHED_MODEL" = "haiku" ]; then
    SAVINGS="\$1-5"
  else
    SAVINGS="\$0.80-4.70"
  fi
  
  TASK_TYPE=$(echo "$MATCHED_RULE" | sed 's/-/ /g')
  
  # Check if auto-switch is enabled
  if [ -f "$AUTO_SWITCH_FLAG" ]; then
    # Tier 3: Spawn automation
    echo "$PROMPT" > "$PENDING_PROMPT_FILE"
    
    # Spawn background automation (detached)
    (
      sleep 0.5
      "$HOME/.claude/hooks/cc-auto-switch-ide.sh" "$MATCHED_MODEL" "$PROMPT" &
    ) &
    
    # Output block message
    jq -n --arg reason "🤖 [Model Matchmaker] Switching to $MATCHED_MODEL and resending automatically...

(Detected $TASK_TYPE task on opus — saves $SAVINGS per message)" \
      '{"decision": "block", "reason": $reason}'
  else
    # Tier 2: Clipboard block (manual)
    jq -n --arg reason "💰 [Model Matchmaker] Cost optimization

This is a $TASK_TYPE task. $MATCHED_MODEL costs $SAVINGS less than opus with identical results.

✓ Your prompt is copied to clipboard

To continue:
1. Type: /model $MATCHED_MODEL
2. Paste: ⌘V
3. Send

(Prefix with ! to override and use opus anyway)" \
      '{"decision": "block", "reason": $reason}'
  fi
  
elif [ "$ACTION" = "pass-through-with-hint" ]; then
  # Tier 1: Upward mismatch — pass through with hint
  
  HINT="Note: This looks like a task that may benefit from $MATCHED_MODEL's deeper reasoning (current model: $CURRENT_ALIAS). Run \`/model $MATCHED_MODEL\` if $CURRENT_ALIAS's response isn't sufficient."
  
  jq -n --arg ctx "$HINT" '{
    "hookSpecificOutput": {
      "hookEventName": "UserPromptSubmit",
      "additionalContext": $ctx
    }
  }'
  
elif [ "$ACTION" = "pass-through" ]; then
  # Tier 1: Silent pass-through (no output)
  exit 0
  
else
  # Fallback: pass through
  exit 0
fi
