#!/bin/bash
# Fetch and cache LLM pricing data from LiteLLM's open-source pricing dataset.
# Source: https://github.com/BerriAI/litellm/blob/main/model_prices_and_context_window.json
#
# Caching: writes to ~/.cursor/hooks/model-prices-cache.json with 24h TTL.
# Fallback: if fetch fails and no cache exists, writes a hardcoded pricing table.
#
# Usage: ./fetch-prices.sh [--force]
#   --force  Ignore TTL and re-fetch regardless of cache age.

CACHE_DIR="$HOME/.cursor/hooks"
CACHE_FILE="$CACHE_DIR/model-prices-cache.json"
TTL_SECONDS=86400  # 24 hours
LITELLM_URL="https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"

mkdir -p "$CACHE_DIR"

FORCE=false
[ "$1" = "--force" ] && FORCE=true

# Check TTL: skip if cache is fresh (unless --force)
if [ "$FORCE" = false ] && [ -f "$CACHE_FILE" ]; then
    CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if [ $CACHE_AGE -lt $TTL_SECONDS ]; then
        exit 0
    fi
fi

# Fetch from LiteLLM and extract relevant models via Python
RAW=$(curl -sS --max-time 10 "$LITELLM_URL" 2>/dev/null)

if [ -z "$RAW" ]; then
    # Fetch failed -- write hardcoded fallback only if no cache exists
    if [ ! -f "$CACHE_FILE" ]; then
        python3 -c '
import json, sys
from datetime import datetime

fallback = {
    "last_updated": datetime.now().isoformat(),
    "source": "hardcoded_fallback",
    "models": {
        "claude-opus-4-6": {
            "input_cost_per_token": 0.000005,
            "output_cost_per_token": 0.000025,
            "quality_tier": 3,
            "provider": "anthropic",
            "display_name": "Opus 4.6"
        },
        "claude-sonnet-4-6": {
            "input_cost_per_token": 0.000003,
            "output_cost_per_token": 0.000015,
            "quality_tier": 2,
            "provider": "anthropic",
            "display_name": "Sonnet 4.6"
        },
        "claude-haiku-4-5": {
            "input_cost_per_token": 0.000001,
            "output_cost_per_token": 0.000005,
            "quality_tier": 1,
            "provider": "anthropic",
            "display_name": "Haiku 4.5"
        },
        "o3": {
            "input_cost_per_token": 0.000002,
            "output_cost_per_token": 0.000008,
            "quality_tier": 3,
            "provider": "openai",
            "display_name": "o3"
        },
        "gpt-5.4": {
            "input_cost_per_token": 0.0000025,
            "output_cost_per_token": 0.000015,
            "quality_tier": 3,
            "provider": "openai",
            "display_name": "GPT-5.4"
        },
        "gpt-5.3-codex": {
            "input_cost_per_token": 0.00000175,
            "output_cost_per_token": 0.000014,
            "quality_tier": 3,
            "provider": "openai",
            "display_name": "GPT-5.3-Codex"
        },
        "gpt-5.1-codex": {
            "input_cost_per_token": 0.00000125,
            "output_cost_per_token": 0.00001,
            "quality_tier": 3,
            "provider": "openai",
            "display_name": "GPT-5.1-Codex"
        },
        "gpt-4.1": {
            "input_cost_per_token": 0.000002,
            "output_cost_per_token": 0.000008,
            "quality_tier": 3,
            "provider": "openai",
            "display_name": "GPT-4.1"
        },
        "gpt-4o": {
            "input_cost_per_token": 0.0000025,
            "output_cost_per_token": 0.00001,
            "quality_tier": 2,
            "provider": "openai",
            "display_name": "GPT-4o"
        },
        "gpt-4.1-mini": {
            "input_cost_per_token": 0.0000004,
            "output_cost_per_token": 0.0000016,
            "quality_tier": 1,
            "provider": "openai",
            "display_name": "GPT-4.1-mini"
        },
        "gpt-5-nano": {
            "input_cost_per_token": 0.00000005,
            "output_cost_per_token": 0.0000004,
            "quality_tier": 1,
            "provider": "openai",
            "display_name": "GPT-5-nano"
        },
        "gpt-4.1-nano": {
            "input_cost_per_token": 0.0000001,
            "output_cost_per_token": 0.0000004,
            "quality_tier": 1,
            "provider": "openai",
            "display_name": "GPT-4.1-nano"
        }
    }
}
with open(sys.argv[1], "w") as f:
    json.dump(fallback, f, indent=2)
' "$CACHE_FILE"
    fi
    exit 0
fi

# Parse raw LiteLLM JSON -- extract models we care about, normalize structure
echo "$RAW" | python3 -c '
import json, sys, re
from datetime import datetime

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)

# Models to extract: patterns mapped to (quality_tier, display_name)
# LiteLLM uses keys like "claude-opus-4-0", "gpt-4.1", etc.
TARGETS = {
    "anthropic": {
        "patterns": [
            (r"claude.*opus.*4[.-]6", 3),
            (r"claude.*opus.*4[.-]5", 3),
            (r"claude.*sonnet.*4[.-]6", 2),
            (r"claude.*sonnet.*4[.-]5", 2),
            (r"claude.*haiku.*4[.-]5", 1),
        ]
    },
    "openai": {
        "patterns": [
            (r"^o3$", 3),
            (r"^gpt-5\.4", 3),
            (r"^gpt-5\.3-codex$", 3),
            (r"^gpt-5\.1-codex$", 3),
            (r"^gpt-4\.1$", 3),
            (r"^gpt-4o$", 2),
            (r"^gpt-5-nano$", 1),
            (r"^gpt-4\.1-mini$", 1),
            (r"^gpt-4\.1-nano$", 1),
            (r"^gpt-4o-mini$", 1),
        ]
    }
}

models = {}

for key, info in data.items():
    if not isinstance(info, dict):
        continue
    input_cost = info.get("input_cost_per_token")
    output_cost = info.get("output_cost_per_token")
    if input_cost is None or output_cost is None:
        continue

    # Skip provider-prefixed duplicates (anthropic/..., us.anthropic..., eu.anthropic..., etc.)
    if "/" in key or "." in key.split("-")[0]:
        continue

    provider_match = None
    tier = None
    for provider, cfg in TARGETS.items():
        for pattern, t in cfg["patterns"]:
            if re.search(pattern, key, re.IGNORECASE):
                provider_match = provider
                tier = t
                break
        if provider_match:
            break

    if not provider_match:
        continue

    # Keep the entry with the lowest key (most canonical name) per pattern match
    if key in models:
        continue

    display = key.replace("-", " ").title()
    for p, _ in TARGETS[provider_match]["patterns"]:
        if re.search(p, key, re.IGNORECASE):
            break

    models[key] = {
        "input_cost_per_token": float(input_cost),
        "output_cost_per_token": float(output_cost),
        "quality_tier": tier,
        "provider": provider_match,
        "display_name": key,
        "max_input_tokens": info.get("max_input_tokens"),
        "max_output_tokens": info.get("max_output_tokens"),
    }

result = {
    "last_updated": datetime.now().isoformat(),
    "source": "litellm",
    "models": models,
}

cache_path = sys.argv[1]
with open(cache_path, "w") as f:
    json.dump(result, f, indent=2)
' "$CACHE_FILE"

exit 0
