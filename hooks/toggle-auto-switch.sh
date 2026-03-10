#!/bin/bash
# Enable/Disable Auto-Switch Feature
# Usage: ./toggle-auto-switch.sh [on|off|status]

ACTION="${1:-status}"
FLAG_FILE="$HOME/.cursor/hooks/.auto-switch-enabled"

case "$ACTION" in
    on|enable)
        touch "$FLAG_FILE"
        echo "[OK] Auto-switch enabled"
        echo "  Model Matchmaker will now automatically switch models when blocked."
        echo "  To disable: ./toggle-auto-switch.sh off"
        ;;
    off|disable)
        rm -f "$FLAG_FILE"
        echo "[OK] Auto-switch disabled"
        echo "  Model Matchmaker will block with a message (original behavior)."
        echo "  To enable: ./toggle-auto-switch.sh on"
        ;;
    status)
        if [ -f "$FLAG_FILE" ]; then
            echo "Auto-switch: ENABLED [OK]"
            echo "  Models will switch automatically when recommended."
        else
            echo "Auto-switch: DISABLED"
            echo "  You'll see block messages and must switch manually."
        fi
        
        # Security status
        echo ""
        echo "Security Status:"
        
        # Check kill switch
        if [ -f "$HOME/.cursor/hooks/.auto-switch-kill" ]; then
            echo "  [STOP] KILL SWITCH ACTIVE - auto-switch is hard-disabled"
        fi
        
        # Check audit log
        if [ -f "$HOME/.cursor/hooks/auto-switch-audit.log" ]; then
            RECENT_COUNT=$(grep "SWITCH_ATTEMPT" "$HOME/.cursor/hooks/auto-switch-audit.log" 2>/dev/null | tail -20 | wc -l | tr -d ' ')
            FAILED_COUNT=$(grep "FAILED" "$HOME/.cursor/hooks/auto-switch-audit.log" 2>/dev/null | tail -20 | wc -l | tr -d ' ')
            echo "  Recent switches (last 20): $RECENT_COUNT"
            if [ "$FAILED_COUNT" -gt 0 ]; then
                echo "  [WARN] Failed attempts: $FAILED_COUNT"
            fi
        else
            echo "  No audit log yet"
        fi
        
        # Check for stale locks
        if [ -f "$HOME/.cursor/hooks/.auto-switch.lock" ]; then
            echo "  [WARN] Stale lock file detected (may indicate issue)"
        fi
        
        echo ""
        echo "Commands:"
        echo "  Enable:  ./toggle-auto-switch.sh on"
        echo "  Disable: ./toggle-auto-switch.sh off"
        echo "  Logs:    tail -20 ~/.cursor/hooks/auto-switch-audit.log"
        ;;
    *)
        echo "Usage: $0 [on|off|status]"
        exit 1
        ;;
esac
