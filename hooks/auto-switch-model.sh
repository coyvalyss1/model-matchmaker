#!/bin/bash
# Auto-Switch Model via Keyboard Automation
# Uses Cmd+/ to open model dropdown, then arrow keys to navigate to target model.
# 
# Cursor's official keyboard shortcuts:
# - Cmd+/: Loop between AI models (opens dropdown)
# - Arrow keys + Enter: Navigate and select
#
# Proxy approach: Cursor's subprocess doesn't have macOS Accessibility permissions,
# so we write a temp script and execute via Terminal.app (which does have them).
#
# Usage: ./auto-switch-model.sh <model_name> [--test]
# Example: ./auto-switch-model.sh "sonnet"
# Test mode: ./auto-switch-model.sh "sonnet" --test (bypasses enable check)

MODEL="$1"
TEST_MODE="${2:-}"
LOG_FILE="$HOME/.cursor/hooks/auto-switch-audit.log"
CIRCUIT_FILE="$HOME/.cursor/hooks/.auto-switch-circuit"
LOCK_FILE="$HOME/.cursor/hooks/.auto-switch.lock"
KILL_SWITCH="$HOME/.cursor/hooks/.auto-switch-kill"
AUTO_SWITCH_FLAG="$HOME/.cursor/hooks/.auto-switch-enabled"

# SECURITY: Emergency kill switch
if [ -f "$KILL_SWITCH" ]; then
    echo "[$(date -Iseconds)] SECURITY: Kill switch activated" >> "$LOG_FILE"
    exit 0
fi

# SECURITY: Check if auto-switch is enabled (skip in test mode)
if [ "$TEST_MODE" != "--test" ] && [ ! -f "$AUTO_SWITCH_FLAG" ]; then
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

# SECURITY: Execution lock - prevent simultaneous executions
if [ -f "$LOCK_FILE" ]; then
    LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
    if [ $LOCK_AGE -lt 10 ]; then
        echo "[$(date -Iseconds)] SECURITY: Lock exists, switch in progress" >> "$LOG_FILE"
        exit 0
    else
        rm -f "$LOCK_FILE"
    fi
fi

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# SECURITY: Rate limiting - prevent rapid-fire switching
CURRENT_TIME=$(date +%s)
if [ -f "$CIRCUIT_FILE" ]; then
    LAST_SWITCH=$(cat "$CIRCUIT_FILE" 2>/dev/null || echo 0)
    TIME_DIFF=$((CURRENT_TIME - LAST_SWITCH))
    
    if [ $TIME_DIFF -lt 5 ]; then
        echo "[$(date -Iseconds)] SECURITY: Rate limit - too soon since last switch (${TIME_DIFF}s)" >> "$LOG_FILE"
        exit 0
    fi
fi

echo "$CURRENT_TIME" > "$CIRCUIT_FILE"

# Detect current Cursor mode (affects dropdown positions)
MODE_FILE="$HOME/.cursor/hooks/.cursor-mode"
CURSOR_MODE="agent"  # default
if [ -f "$MODE_FILE" ]; then
    CURSOR_MODE=$(cat "$MODE_FILE" 2>/dev/null || echo "agent")
fi

# Window targeting from environment (set by model-advisor.sh)
WINDOW_TITLE="${WINDOW_TITLE:-}"
CONVERSATION_ID="${CONVERSATION_ID:-}"

# Audit log
echo "[$(date -Iseconds)] SWITCH_ATTEMPT | Model: $MODEL | Mode: $CURSOR_MODE | Window: $WINDOW_TITLE | PID: $$ | User: $(whoami)" >> "$LOG_FILE"

# Search-based model selection: type model name into dropdown search bar
SEARCH_TERM="$MODEL"
if [ "$CURSOR_MODE" = "plan" ] && [ "$MODEL" = "haiku" ]; then
    echo "[$(date -Iseconds)] INFO | Haiku not available in Plan mode, switching to Sonnet" >> "$LOG_FILE"
    MODEL="sonnet"
    SEARCH_TERM="sonnet"
fi

# Proxy via Terminal.app to get Accessibility permissions
# Cursor's subprocess doesn't inherit macOS Accessibility/Automation permissions,
# so we write a temp script and execute it through Terminal.app which has them.
PROXY_SCRIPT="/tmp/.cursor-model-switch-$$.sh"
RESULT_FILE="/tmp/.cursor-model-switch-$$-result.txt"

cat > "$PROXY_SCRIPT" << PROXY_EOF
#!/bin/bash

# Capture the window title to target this specific Cursor window
WINDOW_TITLE="$WINDOW_TITLE"

osascript - "$MODEL" "$SEARCH_TERM" "\$WINDOW_TITLE" <<'APPLESCRIPT_EOF'
on run argv
    set targetModel to item 1 of argv
    set searchTerm to item 2 of argv
    set targetWindow to item 3 of argv
    
    -- Activate Cursor and bring the correct window to front
    tell application "Cursor"
        activate
        if targetWindow is not "" then
            try
                set index of (first window whose name contains targetWindow) to 1
            end try
        end if
    end tell
    delay 0.5
    
    -- Verify Cursor is frontmost
    tell application "System Events"
        if frontmost of process "Cursor" is false then
            do shell script "echo ABORTED > $RESULT_FILE"
            return "ABORTED: Cursor not frontmost"
        end if
    end tell
    
    -- Open model dropdown with Cmd+/, then type to search using key codes
    tell application "System Events"
        tell process "Cursor"
            keystroke "/" using command down
            delay 0.8
            
            -- Type model name using key codes (avoids keyboard layout issues)
            -- h=4, a=0, i=34, k=40, u=32
            -- s=1, o=31, n=45, e=14, t=17
            -- p=35
            repeat with c in (characters of searchTerm)
                set ch to c as text
                if ch is "a" then
                    key code 0
                else if ch is "e" then
                    key code 14
                else if ch is "h" then
                    key code 4
                else if ch is "i" then
                    key code 34
                else if ch is "k" then
                    key code 40
                else if ch is "n" then
                    key code 45
                else if ch is "o" then
                    key code 31
                else if ch is "p" then
                    key code 35
                else if ch is "s" then
                    key code 1
                else if ch is "t" then
                    key code 17
                else if ch is "u" then
                    key code 32
                end if
                delay 0.05
            end repeat
            
            delay 1.5
            
            -- Enter to select model (dropdown closes, focus returns to chat)
            key code 36
        end tell
    end tell
    
    return "SUCCESS"
end run
APPLESCRIPT_EOF

echo "EXIT:\$?" > "$RESULT_FILE"

# Self-destruct: delete script and close the Terminal window (from working 8b36d92)
sleep 0.2
rm -f "$PROXY_SCRIPT"
osascript -e 'tell application "Terminal" to close front window' 2>/dev/null &
PROXY_EOF

chmod +x "$PROXY_SCRIPT"

# Execute through Terminal.app
# Uses 'open' which doesn't require Apple Event permissions
open -a Terminal "$PROXY_SCRIPT"

# Wait for result (up to 8 seconds)
for i in $(seq 1 16); do
    if [ -f "$RESULT_FILE" ]; then
        RESULT=$(cat "$RESULT_FILE")
        rm -f "$PROXY_SCRIPT" "$RESULT_FILE"
        
        if echo "$RESULT" | grep -q "EXIT:0"; then
            echo "[$(date -Iseconds)] SUCCESS | Model: $MODEL" >> "$LOG_FILE"
        else
            echo "[$(date -Iseconds)] FAILED | Model: $MODEL | Result: $RESULT" >> "$LOG_FILE"
        fi
        exit 0
    fi
    sleep 0.5
done

echo "[$(date -Iseconds)] TIMEOUT | Model: $MODEL" >> "$LOG_FILE"
rm -f "$PROXY_SCRIPT" "$RESULT_FILE"

# Close any orphaned Terminal window from the failed proxy script
osascript -e 'tell application "Terminal" to close front window' 2>/dev/null &
