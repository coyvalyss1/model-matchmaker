#!/usr/bin/env bash
# cc-auto-switch-ide.sh — Auto-switch model and re-send prompt in Claude Code IDE (Tier 3)
#
# Spawned by cc-ide-advisor.sh when auto-switch is enabled and an expensive mismatch is detected.
# Uses AppleScript to type /model command and paste the prompt back into Claude Code webview.
#
# Usage: ./cc-auto-switch-ide.sh <model_name> <prompt_text>
# Example: ./cc-auto-switch-ide.sh "haiku" "list all TODO comments"

MODEL="$1"
PROMPT="$2"
LOG_FILE="$HOME/.claude/hooks/mm-audit.log"
KILL_SWITCH="$HOME/.claude/hooks/.mm-kill"

# SECURITY: Emergency kill switch
if [ -f "$KILL_SWITCH" ]; then
    echo "[$(date -Iseconds)] SECURITY: Kill switch activated" >> "$LOG_FILE"
    exit 0
fi

# SECURITY: Input validation - only allow whitelisted model names
case "$MODEL" in
    haiku|sonnet|opus)
        ;;
    *)
        echo "[$(date -Iseconds)] SECURITY: Invalid model rejected: $MODEL" >> "$LOG_FILE"
        exit 1
        ;;
esac

# Audit log
echo "[$(date -Iseconds)] IDE_AUTO_SWITCH | Model: $MODEL | PID: $$ | User: $(whoami)" >> "$LOG_FILE"

# Wait for block message to render
sleep 0.7

# Copy prompt to clipboard (backup in case AppleScript fails)
echo "$PROMPT" | pbcopy 2>/dev/null

# Execute AppleScript automation
osascript <<EOF
tell application "System Events"
  tell process "Cursor"
    -- Focus Claude Code input (Esc key)
    key code 53
    delay 0.4
    
    -- Type /model command
    keystroke "/model $MODEL"
    delay 0.2
    key code 36  -- Enter
    delay 1.3
    
    -- Refocus input
    key code 53
    delay 0.4
    
    -- Paste saved prompt
    keystroke "v" using command down
    delay 0.4
    
    -- Submit
    key code 36  -- Enter
  end tell
end tell
EOF

APPLESCRIPT_EXIT=$?

if [ $APPLESCRIPT_EXIT -eq 0 ]; then
    echo "[$(date -Iseconds)] IDE_AUTO_SWITCH_SUCCESS | Model: $MODEL" >> "$LOG_FILE"
else
    echo "[$(date -Iseconds)] IDE_AUTO_SWITCH_FAILED | Model: $MODEL | Exit: $APPLESCRIPT_EXIT" >> "$LOG_FILE"
fi

exit 0
