#!/bin/bash
# Session init hook: injects model-awareness context and refreshes pricing data.
# Runs once at session start via the sessionStart hook event.

cat > /dev/null

CONFIG_DIR="$HOME/.cursor/hooks"
CONFIG_FILE="$CONFIG_DIR/model-matchmaker-config.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Background-refresh pricing cache (non-blocking, won't affect timeout)
if [ -f "$SCRIPT_DIR/fetch-prices.sh" ]; then
    bash "$SCRIPT_DIR/fetch-prices.sh" &>/dev/null &
fi

# Build context message based on configuration state
CONTEXT="Model guidance: Haiku is ideal for git ops, renames, formatting, and simple edits. Sonnet is the default for feature work, debugging, and planning. Opus is for architecture decisions, deep analysis, and multi-system reasoning. If you notice the current task is simpler than the model being used, briefly mention it."

if [ ! -f "$CONFIG_FILE" ]; then
    CONTEXT="$CONTEXT NOTE: Model Matchmaker is not configured yet. Run ./hooks/configure.sh to set up model preferences (provider family, switch behavior)."
fi

cat << EOF
{
  "additional_context": "$CONTEXT"
}
EOF

exit 0
