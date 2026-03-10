#!/bin/bash
# Model Advisor Hook (beforeSubmitPrompt)
# Cost-aware model routing engine.
#
# Classifies prompts by task complexity, looks up real pricing data,
# finds the cheapest capable model in the user's allowed pool, and
# either blocks with a recommendation or auto-switches.
#
# Override: prefix prompt with "!" to bypass entirely.
# Ambiguous choice: prefix with "!1", "!2" etc. to pick from prior options.

INPUT=$(cat)

RESULT=$(echo "$INPUT" | python3 -c '
import json, sys, os, re
from datetime import datetime

HOOKS_DIR = os.path.expanduser("~/.cursor/hooks")
CONFIG_PATH = os.path.join(HOOKS_DIR, "model-matchmaker-config.json")
CACHE_PATH = os.path.join(HOOKS_DIR, "model-prices-cache.json")
PENDING_PATH = os.path.join(HOOKS_DIR, ".pending-choice.json")
LOG_PATH = os.path.join(HOOKS_DIR, "model-matchmaker.ndjson")

def allow():
    print(json.dumps({"continue": True}))
    sys.exit(0)

def allow_with_message(msg):
    print(json.dumps({"continue": True, "user_message": msg}))
    sys.exit(0)

def block(msg):
    print(json.dumps({"continue": False, "user_message": msg}))
    sys.exit(0)

try:
    data = json.load(sys.stdin)
except Exception:
    allow()

prompt = data.get("prompt", "")
model = data.get("model", "").lower()
conversation_id = data.get("conversation_id", "")
generation_id = data.get("generation_id", "")

# --- Override handling ---
stripped = prompt.lstrip()
is_override = stripped.startswith("!")

# Check for numbered choice from ambiguous routing (e.g. "!1", "!2")
numbered_choice = None
if is_override and len(stripped) > 1 and stripped[1].isdigit():
    choice_match = re.match(r"^!(\d+)\s*", stripped)
    if choice_match:
        numbered_choice = int(choice_match.group(1))

if is_override and numbered_choice is not None:
    # Handle pending choice from previous ambiguous block
    if os.path.exists(PENDING_PATH):
        try:
            with open(PENDING_PATH) as f:
                pending = json.load(f)
            os.remove(PENDING_PATH)
            options = pending.get("options", [])
            if 1 <= numbered_choice <= len(options):
                chosen = options[numbered_choice - 1]
                allow_with_message(
                    "Routing to " + chosen.get("display_name", chosen.get("model", "unknown"))
                    + ". Re-send your prompt without the prefix."
                )
        except Exception:
            pass
    allow()

if is_override:
    clean_prompt = stripped[1:].lstrip()
else:
    clean_prompt = prompt

prompt_lower = clean_prompt.lower()
word_count = len(clean_prompt.split())

# --- Load config ---
config = None
try:
    with open(CONFIG_PATH) as f:
        config = json.load(f)
except Exception:
    pass

provider_pref = config.get("provider_preference", "hybrid") if config else "hybrid"
allowed_models = config.get("allowed_models", []) if config else []
switch_mode = config.get("switch_mode", "ask") if config else "ask"

# --- Load pricing cache ---
pricing = {}
try:
    with open(CACHE_PATH) as f:
        cache = json.load(f)
    pricing = cache.get("models", {})
except Exception:
    pass

# --- Model detection ---
# Identify the current model family and tier
def detect_model_info(model_name):
    """Match current model string to a pricing entry and extract metadata."""
    m = model_name.lower()

    # Direct lookup
    if m in pricing:
        p = pricing[m]
        return {
            "key": m,
            "provider": p.get("provider", "unknown"),
            "tier": p.get("quality_tier", 2),
            "input_cost": p.get("input_cost_per_token", 0),
            "output_cost": p.get("output_cost_per_token", 0),
        }

    # Fuzzy match: find the best pricing entry that matches substrings
    best = None
    best_len = 0
    for key, p in pricing.items():
        if key in m or m in key:
            if len(key) > best_len:
                best = (key, p)
                best_len = len(key)

    # Family-based fallback for models not in cache
    if best is None:
        for key, p in pricing.items():
            # Match by family keywords
            if "opus" in m and "opus" in key:
                if best is None or len(key) < best_len:
                    best = (key, p)
                    best_len = len(key)
            elif "sonnet" in m and "sonnet" in key:
                if best is None or len(key) < best_len:
                    best = (key, p)
                    best_len = len(key)
            elif "haiku" in m and "haiku" in key:
                if best is None or len(key) < best_len:
                    best = (key, p)
                    best_len = len(key)
            elif ("o3" in m or m == "o3") and "o3" in key and "codex" not in key:
                best = (key, p)
                break
            elif "5.4" in m and "5.4" in key:
                best = (key, p)
                break
            elif "5.3-codex" in m and "5.3-codex" in key:
                best = (key, p)
                break
            elif "5.1-codex" in m and "5.1-codex" in key:
                best = (key, p)
                break
            elif "5-nano" in m and "5-nano" in key:
                best = (key, p)
                break
            elif "gpt-4.1-nano" in m and "gpt-4.1-nano" in key:
                best = (key, p)
                break
            elif "gpt-4.1-mini" in m and "gpt-4.1-mini" in key:
                best = (key, p)
                break
            elif "gpt-4o-mini" in m and "gpt-4o-mini" in key:
                best = (key, p)
                break
            elif "gpt-4o" in m and "gpt-4o" in key and "mini" not in key:
                best = (key, p)
                break
            elif "gpt-4.1" in m and "gpt-4.1" in key and "mini" not in key and "nano" not in key:
                best = (key, p)
                break

    if best:
        key, p = best
        return {
            "key": key,
            "provider": p.get("provider", "unknown"),
            "tier": p.get("quality_tier", 2),
            "input_cost": p.get("input_cost_per_token", 0),
            "output_cost": p.get("output_cost_per_token", 0),
        }

    # Absolute fallback: detect family from name alone - prioritize newest versions
    if "opus" in m:
        # Prioritize 4.6, fallback to 4.5 pricing
        return {"key": m, "provider": "anthropic", "tier": 3, "input_cost": 0.000005, "output_cost": 0.000025}
    if "sonnet" in m:
        return {"key": m, "provider": "anthropic", "tier": 2, "input_cost": 0.000003, "output_cost": 0.000015}
    if "haiku" in m:
        return {"key": m, "provider": "anthropic", "tier": 1, "input_cost": 0.000001, "output_cost": 0.000005}
    if "o3" in m and not "codex" in m:
        return {"key": m, "provider": "openai", "tier": 3, "input_cost": 0.000002, "output_cost": 0.000008}
    if "5.4" in m:
        return {"key": m, "provider": "openai", "tier": 3, "input_cost": 0.0000025, "output_cost": 0.000015}
    if "5.3-codex" in m or "gpt-5.3-codex" in m:
        return {"key": m, "provider": "openai", "tier": 3, "input_cost": 0.00000175, "output_cost": 0.000014}
    if "5.1-codex" in m or "gpt-5.1-codex" in m:
        return {"key": m, "provider": "openai", "tier": 3, "input_cost": 0.00000125, "output_cost": 0.00001}
    if "5-nano" in m or "gpt-5-nano" in m:
        return {"key": m, "provider": "openai", "tier": 1, "input_cost": 0.00000005, "output_cost": 0.0000004}
    if "gpt-4.1-nano" in m:
        return {"key": m, "provider": "openai", "tier": 1, "input_cost": 0.0000001, "output_cost": 0.0000004}
    if "gpt-4.1-mini" in m:
        return {"key": m, "provider": "openai", "tier": 1, "input_cost": 0.0000004, "output_cost": 0.0000016}
    if "gpt-4o-mini" in m:
        return {"key": m, "provider": "openai", "tier": 1, "input_cost": 0.00000015, "output_cost": 0.0000006}
    if "gpt-4o" in m:
        return {"key": m, "provider": "openai", "tier": 2, "input_cost": 0.0000025, "output_cost": 0.00001}
    if "gpt-4.1" in m:
        return {"key": m, "provider": "openai", "tier": 3, "input_cost": 0.000002, "output_cost": 0.000008}

    return None

current = detect_model_info(model)

# If we cannot identify the model at all, pass through
if current is None:
    if is_override:
        allow()
    allow()

# --- Task classification ---
opus_keywords = [
    "architect", "architecture", "evaluate", "tradeoff", "trade-off",
    "strategy", "strategic", "compare approaches", "why does", "deep dive",
    "redesign", "across the codebase", "investor", "multi-system",
    "complex refactor", "analyze", "analysis", "plan mode", "rethink",
    "high-stakes", "critical decision"
]

haiku_patterns = [
    r"\bgit\s+(commit|push|pull|status|log|diff|add|stash|branch|merge|rebase|checkout)\b",
    r"\bcommit\b.*\b(change|push|all)\b", r"\bpush\s+(to|the|remote|origin)\b",
    r"\brename\b", r"\bre-?order\b", r"\bmove\s+file\b", r"\bdelete\s+file\b",
    r"\badd\s+(import|route|link)\b", r"\bformat\b", r"\blint\b",
    r"\bprettier\b", r"\beslint\b", r"\bremove\s+(unused|dead)\b",
    r"\bupdate\s+(version|package)\b"
]

sonnet_patterns = [
    r"\bbuild\b", r"\bimplement\b", r"\bcreate\b", r"\bfix\b", r"\bdebug\b",
    r"\badd\s+feature\b", r"\bwrite\b", r"\bcomponent\b", r"\bservice\b",
    r"\bpage\b", r"\bdeploy\b", r"\btest\b", r"\bupdate\b", r"\brefactor\b",
    r"\bstyle\b", r"\bcss\b", r"\broute\b", r"\bapi\b", r"\bfunction\b"
]

has_opus_signal = any(kw in prompt_lower for kw in opus_keywords)
is_long_analytical = word_count > 100 and "?" in clean_prompt
is_multi_paragraph = word_count > 200

if has_opus_signal or is_long_analytical or is_multi_paragraph:
    required_tier = 3
elif word_count < 60 and any(re.search(p, prompt_lower) for p in haiku_patterns):
    required_tier = 1
elif any(re.search(p, prompt_lower) for p in sonnet_patterns):
    required_tier = 2
else:
    required_tier = None  # uncertain

# --- Find cheapest model in allowed pool for the required tier ---
def estimate_cost(model_info, input_tokens, output_tokens):
    return (input_tokens * model_info["input_cost"]) + (output_tokens * model_info["output_cost"])

def find_candidates(tier, provider_pref, allowed_list):
    """Find all models in the allowed pool that meet the required tier."""
    candidates = []

    for model_key in allowed_list:
        info = detect_model_info(model_key)
        if info is None:
            continue
        if info["tier"] < tier:
            continue
        if provider_pref == "claude" and info["provider"] != "anthropic":
            continue
        if provider_pref == "openai" and info["provider"] != "openai":
            continue
        candidates.append(info)

    if not candidates and pricing:
        # Fallback: search entire pricing cache
        for key, p in pricing.items():
            t = p.get("quality_tier", 0)
            prov = p.get("provider", "")
            if t < tier:
                continue
            if provider_pref == "claude" and prov != "anthropic":
                continue
            if provider_pref == "openai" and prov != "openai":
                continue
            # Only consider canonical names (no dots in prefix)
            if "." in key.split("-")[0]:
                continue
            candidates.append({
                "key": key,
                "provider": prov,
                "tier": t,
                "input_cost": p.get("input_cost_per_token", 0),
                "output_cost": p.get("output_cost_per_token", 0),
            })

    return candidates

# Estimate tokens for cost calculation
est_input_tokens = int(word_count * 1.3)
est_output_tokens = {1: 500, 2: 2000, 3: 5000}.get(required_tier, 2000)

current_cost = estimate_cost(current, est_input_tokens, est_output_tokens)

recommendation = None
recommended_info = None
savings = 0.0

if required_tier is not None:
    candidates = find_candidates(required_tier, provider_pref, allowed_models)

    if candidates:
        # Sort by total estimated cost (cheapest first)
        def total_cost(c):
            return estimate_cost(c, est_input_tokens, est_output_tokens)

        candidates.sort(key=total_cost)

        cheapest = candidates[0]
        cheapest_cost = total_cost(cheapest)

        if cheapest_cost < current_cost * 0.8:
            # Significant savings -- recommend step-down
            recommendation = cheapest["key"]
            recommended_info = cheapest
            savings = current_cost - cheapest_cost
        elif current["tier"] < required_tier:
            # Current model is underpowered -- recommend step-up
            # Find cheapest model at exactly the required tier
            at_tier = [c for c in candidates if c["tier"] == required_tier]
            if at_tier:
                at_tier.sort(key=total_cost)
                recommendation = at_tier[0]["key"]
                recommended_info = at_tier[0]
                savings = -(total_cost(at_tier[0]) - current_cost)  # negative = costs more

recommended_cost = estimate_cost(recommended_info, est_input_tokens, est_output_tokens) if recommended_info else current_cost

# --- Determine action ---
block_prompt = False
message = ""

if not is_override and recommendation and recommended_info:
    block_prompt = True

    tier_labels = {1: "mechanical", 2: "implementation", 3: "architecture/analysis"}
    task_label = tier_labels.get(required_tier, "general")

    in_per_mtok = recommended_info["input_cost"] * 1_000_000
    out_per_mtok = recommended_info["output_cost"] * 1_000_000
    cur_in_mtok = current["input_cost"] * 1_000_000
    cur_out_mtok = current["output_cost"] * 1_000_000

    rec_display = recommended_info["key"]

    if savings > 0:
        message = (
            "Task: " + task_label + ". "
            + rec_display + " handles this at "
            + chr(36) + f"{in_per_mtok:.2f}/" + chr(36) + f"{out_per_mtok:.2f} per MTok "
            + "(vs " + chr(36) + f"{cur_in_mtok:.2f}/" + chr(36) + f"{cur_out_mtok:.2f} current). "
            + "Est. saving: " + chr(36) + f"{savings:.4f} this request. "
            + "Switch to " + rec_display + " and re-send. (Prefix with ! to override.)"
        )
    else:
        abs_savings = abs(savings)
        message = (
            "Task: " + task_label + ". "
            + "This needs a tier-" + str(required_tier) + " model for best results. "
            + rec_display + " recommended ("
            + chr(36) + f"{in_per_mtok:.2f}/" + chr(36) + f"{out_per_mtok:.2f} per MTok). "
            + "Est. additional cost: " + chr(36) + f"{abs_savings:.4f}. "
            + "Switch to " + rec_display + " and re-send. (Prefix with ! to override.)"
        )

    # Ambiguous routing: if multiple candidates within 20% cost of cheapest, offer choices
    if savings > 0 and required_tier is not None:
        close_candidates = [
            c for c in candidates
            if estimate_cost(c, est_input_tokens, est_output_tokens)
               <= estimate_cost(candidates[0], est_input_tokens, est_output_tokens) * 1.2
            and c["key"] != current["key"]
        ]
        if len(close_candidates) > 1:
            lines = ["Multiple models fit this task (" + task_label + "):"]
            options_for_file = []
            for i, c in enumerate(close_candidates[:4], 1):
                c_cost = estimate_cost(c, est_input_tokens, est_output_tokens)
                c_in = c["input_cost"] * 1_000_000
                c_out = c["output_cost"] * 1_000_000
                lines.append(
                    "  " + str(i) + ". " + c["key"]
                    + " - " + chr(36) + f"{c_cost:.4f} est. ("
                    + c["provider"] + ", " + chr(36) + f"{c_in:.2f}/" + chr(36) + f"{c_out:.2f} MTok)"
                )
                options_for_file.append({
                    "model": c["key"],
                    "display_name": c["key"],
                    "provider": c["provider"],
                    "estimated_cost": round(c_cost, 6),
                })
            lines.append("")
            lines.append("Re-send with: !1 or !2 to choose, or ! to skip routing.")
            message = chr(10).join(lines)

            try:
                pending = {
                    "conversation_id": conversation_id,
                    "options": options_for_file,
                    "created_at": datetime.now().isoformat(),
                }
                os.makedirs(HOOKS_DIR, exist_ok=True)
                with open(PENDING_PATH, "w") as f:
                    json.dump(pending, f)
            except Exception:
                pass

# --- Logging ---
rec_label = recommendation if recommendation else "uncertain"
action = "OVERRIDE" if is_override else ("BLOCK" if block_prompt else "ALLOW")

try:
    os.makedirs(HOOKS_DIR, exist_ok=True)
    snippet = clean_prompt[:40].replace(chr(10), " ").replace(chr(34), chr(39))
    
    # Check if auto-switch is enabled and would be triggered for this block
    auto_switch_enabled = os.path.exists(os.path.join(log_dir, ".auto-switch-enabled"))
    auto_switch_attempted = auto_switch_enabled and block
    
    entry = {
        "event": "recommendation",
        "ts": datetime.now().isoformat(),
        "conversation_id": conversation_id,
        "generation_id": generation_id,
        "model": model,
        "recommendation": rec_label,
        "action": action,
        "word_count": word_count,
        "prompt_snippet": snippet,
        "required_tier": required_tier,
        "current_tier": current["tier"],
        "current_provider": current["provider"],
        "estimated_input_tokens": est_input_tokens,
        "estimated_output_tokens": est_output_tokens,
        "estimated_cost_current": round(current_cost, 6),
        "estimated_cost_recommended": round(recommended_cost, 6),
        "estimated_savings": round(savings, 6),
        "provider_preference": provider_pref,
        "switch_mode": switch_mode,
    }
    with open(LOG_PATH, "a") as f:
        f.write(json.dumps(entry) + chr(10))

    if block_prompt:
        state_path = os.path.join(HOOKS_DIR, ".last-block-state.json")
        block_state = {
            "conversation_id": conversation_id,
            "generation_id": generation_id,
            "blocked_model": model,
            "recommended_model": rec_label,
            "block_ts": datetime.now().isoformat(),
        }
        with open(state_path, "w") as f:
            json.dump(block_state, f)

        # Auto-switch if enabled and switch_mode is auto
        if switch_mode == "auto":
            auto_switch_flag = os.path.join(HOOKS_DIR, ".auto-switch-enabled")
            auto_switch_script = os.path.join(HOOKS_DIR, "auto-switch-model.sh")
            if os.path.exists(auto_switch_flag) and os.path.exists(auto_switch_script):
                # Extract short model name for auto-switch (haiku, sonnet, opus)
                short_name = None
                if "haiku" in rec_label:
                    short_name = "haiku"
                elif "sonnet" in rec_label:
                    short_name = "sonnet"
                elif "opus" in rec_label:
                    short_name = "opus"
                if short_name:
                    import subprocess
                    try:
                        subprocess.Popen(
                            [auto_switch_script, short_name],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                            start_new_session=True,
                        )
                    except Exception:
                        pass
except Exception:
    pass

# --- Output ---
if is_override:
    allow()
elif block_prompt:
    block(message)
else:
    out = {"continue": True}
    if message:
        out["user_message"] = message
    print(json.dumps(out))
')

if [ $? -ne 0 ] || [ -z "$RESULT" ]; then
    echo '{"continue": true}'
    exit 0
fi

echo "$RESULT"
exit 0
