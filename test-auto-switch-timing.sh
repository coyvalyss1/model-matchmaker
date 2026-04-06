#!/bin/bash
# Test Auto-Switch Timing Fix
# Verifies that the model selector has enough time to open before typing begins

echo "=== Model Matchmaker Auto-Switch Timing Test ==="
echo ""
echo "This test will:"
echo "1. Open Cursor model selector (Cmd+/)"
echo "2. Wait 1.2 seconds (new timing)"
echo "3. Type 'sonnet' into the selector"
echo "4. Wait for result"
echo ""
echo "Watch carefully to see if the text appears in the MODEL SELECTOR or in the CHAT INPUT."
echo ""
echo "Press Enter to start test, Ctrl+C to cancel..."
read

# Make sure Cursor is frontmost
osascript -e 'tell application "Cursor" to activate' 2>/dev/null
sleep 1

# Run the auto-switch script in test mode
~/.cursor/hooks/auto-switch-model.sh sonnet --test

echo ""
echo "Did the text 'sonnet' appear in the model selector dropdown? (y/n)"
read ANSWER

if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
    echo "✅ SUCCESS: Timing fix is working correctly"
    exit 0
else
    echo "❌ FAILED: Text appeared in wrong place"
    echo ""
    echo "Possible causes:"
    echo "1. Model selector takes longer than 1.2s to open on your system"
    echo "2. Cursor version incompatibility"
    echo "3. macOS Accessibility permissions issue"
    echo ""
    echo "Check audit log: tail ~/.cursor/hooks/auto-switch-audit.log"
    exit 1
fi
