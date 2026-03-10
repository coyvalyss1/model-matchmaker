#!/bin/bash
# Model Matchmaker Configuration
# Interactive setup for model routing preferences.
# Generates ~/.cursor/hooks/model-matchmaker-config.json
#
# Usage: ./hooks/configure.sh

CONFIG_DIR="$HOME/.cursor/hooks"
CONFIG_FILE="$CONFIG_DIR/model-matchmaker-config.json"
CACHE_FILE="$CONFIG_DIR/model-prices-cache.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$CONFIG_DIR"

echo "=============================================="
echo "  MODEL MATCHMAKER CONFIGURATION"
echo "=============================================="
echo ""

# Load existing config if present
EXISTING_PROVIDER=""
EXISTING_SWITCH=""
if [ -f "$CONFIG_FILE" ]; then
    EXISTING_PROVIDER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('provider_preference',''))" 2>/dev/null)
    EXISTING_SWITCH=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('switch_mode',''))" 2>/dev/null)
    echo "  Existing configuration found."
    echo "  Provider: $EXISTING_PROVIDER | Switch mode: $EXISTING_SWITCH"
    echo ""
fi

# Ensure pricing cache exists
if [ ! -f "$CACHE_FILE" ]; then
    echo "  Fetching pricing data..."
    if [ -f "$SCRIPT_DIR/fetch-prices.sh" ]; then
        bash "$SCRIPT_DIR/fetch-prices.sh" --force
    fi
fi

# Show available models and pricing
if [ -f "$CACHE_FILE" ]; then
    echo "  Available models (live pricing from LiteLLM):"
    echo ""
    MM_CACHE_FILE="$CACHE_FILE" python3 << 'PYEOF'
import json, os

with open(os.environ["MM_CACHE_FILE"]) as f:
    data = json.load(f)

canonical = {}
for key, info in sorted(data["models"].items()):
    prov = info["provider"]
    tier = info["quality_tier"]
    group_key = (prov, tier, key.split("-")[0])
    if group_key not in canonical or len(key) < len(canonical[group_key][0]):
        canonical[group_key] = (key, info)

seen = set()
for (prov, tier, _), (key, info) in sorted(canonical.items(), key=lambda x: (x[0][0], -x[0][1])):
    if key in seen:
        continue
    seen.add(key)
    ic = info["input_cost_per_token"] * 1_000_000
    oc = info["output_cost_per_token"] * 1_000_000
    tier_label = {1: "Tier 1", 2: "Tier 2", 3: "Tier 3"}[tier]
    print(f"    {prov:10s} | {key:30s} | ${ic:>6.2f}/${oc:>6.2f} per MTok | {tier_label}")
PYEOF
    echo ""
else
    echo "  [No pricing cache found -- using defaults]"
    echo ""
fi

# Step 1: Provider preference
echo "----------------------------------------------"
echo "  1. Provider Preference"
echo "----------------------------------------------"
echo ""
echo "  Which model families should routing consider?"
echo ""
echo "    [1] claude  - Anthropic Claude models only"
echo "    [2] openai  - OpenAI GPT models only"
echo "    [3] hybrid  - Both families (cheapest wins)"
echo ""

DEFAULT_PROVIDER="${EXISTING_PROVIDER:-hybrid}"
case "$DEFAULT_PROVIDER" in
    claude) DEFAULT_NUM=1 ;;
    openai) DEFAULT_NUM=2 ;;
    *)      DEFAULT_NUM=3 ;;
esac

read -rp "  Choose [1/2/3] (default: $DEFAULT_NUM): " PROVIDER_CHOICE
PROVIDER_CHOICE="${PROVIDER_CHOICE:-$DEFAULT_NUM}"

case "$PROVIDER_CHOICE" in
    1) PROVIDER="claude" ;;
    2) PROVIDER="openai" ;;
    *) PROVIDER="hybrid" ;;
esac

echo "  -> $PROVIDER"
echo ""

# Step 2: Switch mode
echo "----------------------------------------------"
echo "  2. Switch Behavior"
echo "----------------------------------------------"
echo ""
echo "  When a cheaper model is recommended:"
echo ""
echo "    [1] ask   - Block and show recommendation (you decide)"
echo "    [2] auto  - Auto-switch and notify you"
echo ""

DEFAULT_SWITCH="${EXISTING_SWITCH:-ask}"
case "$DEFAULT_SWITCH" in
    auto) DEFAULT_SNUM=2 ;;
    *)    DEFAULT_SNUM=1 ;;
esac

read -rp "  Choose [1/2] (default: $DEFAULT_SNUM): " SWITCH_CHOICE
SWITCH_CHOICE="${SWITCH_CHOICE:-$DEFAULT_SNUM}"

case "$SWITCH_CHOICE" in
    2) SWITCH_MODE="auto" ;;
    *) SWITCH_MODE="ask" ;;
esac

echo "  -> $SWITCH_MODE"
echo ""

# Step 3: Allowed models (based on provider choice)
echo "----------------------------------------------"
echo "  3. Allowed Models"
echo "----------------------------------------------"
echo ""

if [ "$PROVIDER" = "claude" ]; then
    ALLOWED='["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5"]'
    echo "  Claude models enabled:"
    echo "    - claude-opus-4-6   (Tier 3)"
    echo "    - claude-sonnet-4-6 (Tier 2)"
    echo "    - claude-haiku-4-5  (Tier 1)"
elif [ "$PROVIDER" = "openai" ]; then
    ALLOWED='["gpt-4.1", "gpt-4o", "gpt-4.1-mini", "gpt-4.1-nano"]'
    echo "  OpenAI models enabled:"
    echo "    - gpt-4.1      (Tier 3)"
    echo "    - gpt-4o       (Tier 2)"
    echo "    - gpt-4.1-mini (Tier 1)"
    echo "    - gpt-4.1-nano (Tier 1)"
else
    ALLOWED='["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5", "gpt-4.1", "gpt-4o", "gpt-4.1-mini", "gpt-4.1-nano"]'
    echo "  Hybrid -- all models enabled:"
    echo "    Claude: opus-4-6, sonnet-4-6, haiku-4-5"
    echo "    OpenAI: gpt-4.1, gpt-4o, gpt-4.1-mini, gpt-4.1-nano"
fi
echo ""

# Write config
python3 -c "
import json
from datetime import datetime
config = {
    'provider_preference': '$PROVIDER',
    'allowed_models': $ALLOWED,
    'switch_mode': '$SWITCH_MODE',
    'configured_at': datetime.now().isoformat(),
    'config_version': 1
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
"

echo "=============================================="
echo "  Configuration saved to:"
echo "  $CONFIG_FILE"
echo ""
echo "  Provider:    $PROVIDER"
echo "  Switch mode: $SWITCH_MODE"
echo ""
echo "  Re-run anytime: ./hooks/configure.sh"
echo "  Edit directly:  $CONFIG_FILE"
echo "=============================================="
