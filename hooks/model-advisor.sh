#!/bin/bash
# Model Advisor Hook (beforeSubmitPrompt)
# Step-down: block + recommend Haiku/Sonnet when overpaying.
# Step-up: block + recommend Opus when on Sonnet/Haiku for complex tasks.
# Override: prefix prompt with "!" to bypass entirely.
#
# MODEL CAPABILITIES — Strategy B: Step-Up Routing (updated March 2026)
# - Haiku 4.5:   Git ops, renames, formatting. Fast, cheap. 1-3s. $0.01-0.05/req
# - Sonnet 4.5:  DEFAULT for 80% of work. Features, debugging, refactors. 3-6s. $0.08-0.30/req
# - Sonnet 4.6:  Complex work, architecture, regressions, when 4.5 fails. 3-8s. $0.10-0.50/req
# - Opus 4.0:    BLOCKED. Sonnet 4.6 matches quality at 90% less cost. $1-5/req ($35-209 MAX)
#
# Step-up policy: Haiku → Sonnet 4.5 (default) → Sonnet 4.6 (complex) → Opus (! override only)
# Override policy: Use ! prefix only if Sonnet 4.6 has failed twice on the same task.

INPUT=$(cat)

RESULT=$(echo "$INPUT" | python3 -c '
import json, sys, os, re
from datetime import datetime

try:
    data = json.load(sys.stdin)
except:
    print(json.dumps({"continue": True}))
    sys.exit(0)

prompt = data.get("prompt", "")
model = data.get("model", "").lower()
attachments = data.get("attachments", [])
conversation_id = data.get("conversation_id", "")
generation_id = data.get("generation_id", "")

# #region agent log
# Debug: capture hook input structure and full prompt for mode detection
try:
    debug_path = os.path.expanduser("~/.cursor/debug-f47d6c.log")
    import time
    debug_entry = {
        "sessionId": "f47d6c",
        "timestamp": int(time.time() * 1000),
        "location": "model-advisor.sh:hook-input",
        "message": "Hook input keys and mode detection",
        "hypothesisId": "mode_detection",
        "data": {
            "all_keys": list(data.keys()),
            "has_mode": "mode" in data,
            "mode_value": data.get("mode", "NOT_PRESENT"),
            "hook_event_name": data.get("hook_event_name", "NOT_PRESENT"),
            "transcript_path": data.get("transcript_path", "NOT_PRESENT"),
            "cursor_version": data.get("cursor_version", "NOT_PRESENT"),
            "prompt_length": len(prompt),
            "prompt_first_300": prompt[:300],
            "prompt_contains_plan_mode": "plan mode" in prompt.lower() or "Plan mode" in prompt,
            "model": model,
            "workspace_roots": data.get("workspace_roots", []),
        }
    }
    with open(debug_path, "a") as df:
        df.write(json.dumps(debug_entry) + chr(10))
except:
    pass
# #endregion agent log

# Detect Cursor mode from hook input or prompt text
cursor_mode = data.get("mode", "").lower()
if not cursor_mode:
    # Infer mode from prompt content (Cursor adds system reminders)
    if "plan mode" in prompt.lower():
        cursor_mode = "plan"
    elif "debug mode" in prompt.lower():
        cursor_mode = "debug"
    elif "ask mode" in prompt.lower():
        cursor_mode = "ask"
    else:
        cursor_mode = "agent"

# Write mode to state file so auto-switch can read it
try:
    mode_path = os.path.join(os.path.expanduser("~/.cursor/hooks"), ".cursor-mode")
    with open(mode_path, "w") as mf:
        mf.write(cursor_mode)
except:
    pass

is_override = prompt.lstrip().startswith("!")

if is_override:
    clean_prompt = prompt.lstrip()[1:].lstrip()
else:
    clean_prompt = prompt

prompt_lower = clean_prompt.lower()
word_count = len(clean_prompt.split())

is_opus = "opus" in model
is_sonnet = "sonnet" in model
is_haiku = "haiku" in model

if not (is_opus or is_sonnet or is_haiku):
    if is_override:
        print(json.dumps({"continue": True}))
        sys.exit(0)
    print(json.dumps({"continue": True}))
    sys.exit(0)

opus_keywords = [
    "architect", "architecture", "evaluate", "tradeoff", "trade-off",
    "strategy", "strategic", "compare approaches", "why does", "deep dive",
    "redesign", "across the codebase", "investor", "multi-system",
    "complex refactor", "analyze", "analysis", "plan mode", "rethink",
    "high-stakes", "critical decision"
]

# Sonnet 4.6-specific signals (step up from 4.5 default)
sonnet_46_keywords = [
    "regression", "was working before", "stopped working", "used to work",
    "performance", "optimize", "security", "audit", "vulnerability",
    "novel", "sophisticated", "intricate", "deep dive",
    "multi-system", "cross-platform", "architecture decision",
    "evaluate approach", "compare approaches", "tradeoff", "trade-off"
]

has_opus_signal = any(kw in prompt_lower for kw in opus_keywords)
has_sonnet_46_signal = any(kw in prompt_lower for kw in sonnet_46_keywords)
is_long_analytical = word_count > 100 and "?" in clean_prompt
is_multi_paragraph = word_count > 200

# Route complex tasks to appropriate Sonnet version (Opus blocked for cost control)
if has_opus_signal or is_long_analytical or is_multi_paragraph:
    if has_sonnet_46_signal:
        recommendation = "sonnet-4.6"  # Complex work with specific 4.6 signals
    else:
        recommendation = "sonnet-4.5"  # Default complex work — 4.5 handles it
else:
    # Short prompt patterns (2-10 words) - high confidence despite brevity
    short_haiku_prompts = [
        r"^git\s+status\s*$",
        r"^git\s+commit\s*$",
        r"^git\s+push\s*$",
        r"^git\s+diff\s*$",
        r"^git\s+log\s*$",
        r"^commit\s+(this|all|changes)\s*$",
        r"^push\s+to\s+\w+\s*$",
        r"^rename\s+\w+(\s+to\s+\w+)?\s*$",
        r"^delete\s+\w+\s*$",
        r"^format\s+(this|code|file)\s*$",
        r"^lint\s+(this|code|file)?\s*$",
    ]
    
    short_sonnet_prompts = [
        r"^fix\s+(this|the)\s+\w+\s*$",
        r"^(build|create|add)\s+(a\s+)?\w+\s*$",
        r"^update\s+\w+\s*$",
        r"^test\s+\w+\s*$",
        r"^debug\s+\w+\s*$",
        r"^implement\s+\w+\s*$",
        r"^write\s+(a\s+)?\w+\s*$",
    ]
    
    short_opus_prompts = [
        r"^analyze\s+\w+\s*$",
        r"^evaluate\s+\w+\s*$",
        r"^compare\s+\w+\s+(and|vs)\s+\w+\s*$",
        r"^why\s+(does|is|are)\s+",
        r"^should\s+(i|we)\s+",
    ]
    
    # Check short prompt patterns first (takes precedence)
    recommendation = None
    if word_count <= 10:
        if any(re.search(p, prompt_lower) for p in short_haiku_prompts):
            recommendation = "haiku"
        elif any(re.search(p, prompt_lower) for p in short_opus_prompts):
            recommendation = "sonnet"  # Changed from "opus" - route to Sonnet 4.6
        elif any(re.search(p, prompt_lower) for p in short_sonnet_prompts):
            recommendation = "sonnet"
    
    # If no short pattern matched, use existing longer-form patterns
    if recommendation is None:
        haiku_patterns = [
            r"\bgit\s+(commit|push|pull|status|log|diff|add|stash|branch|merge|rebase|checkout)\b",
            r"\bcommit\b.*\b(change|push|all)\b", r"\bpush\s+(to|the|remote|origin)\b",
            r"\brename\b", r"\bre-?order\b", r"\bmove\s+file\b", r"\bdelete\s+file\b",
            r"\badd\s+(import|route|link)\b", r"\bformat\b", r"\blint\b",
            r"\bprettier\b", r"\beslint\b", r"\bremove\s+(unused|dead)\b",
            r"\bupdate\s+(version|package)\b"
        ]
        # Tightened threshold: 40 words (was 60) + exclude debugging-related prompts
        is_haiku_task = (
            word_count < 40 and 
            any(re.search(p, prompt_lower) for p in haiku_patterns) and
            not any(kw in prompt_lower for kw in ["bug", "issue", "error", "broken", "fails", "failing"])
        )

        sonnet_patterns = [
            r"\bbuild\b", r"\bimplement\b", r"\bcreate\b", r"\bfix\b", r"\bdebug\b",
            r"\badd\s+feature\b", r"\bwrite\b", r"\bcomponent\b", r"\bservice\b",
            r"\bpage\b", r"\bdeploy\b", r"\btest\b", r"\bupdate\b", r"\brefactor\b",
            r"\bstyle\b", r"\bcss\b", r"\broute\b", r"\bapi\b", r"\bfunction\b",
            # Tuned from March 2026 override analysis (146 false negatives)
            r"let.s update the plan", r"update the plan", r"create the plan",
            r"let.s build the plan", r"let.s implement", r"ok let.s build",
            r"let.s also", r"yes,?\s+let.s", r"let.s discuss", r"let.s consider",
            r"reality bot.*check", r"does this pass", r"smell test",
            r"any holes", r"is this sound", r"let.s look at the patterns",
            r"here are the console logs", r"let.s fix minor", r"let.s look at it",
            r"update plan to", r"let.s do it\b", r"let.s build this",
            r"let.s create a plan", r"let.s add to", r"let.s log and figure",
        ]
        is_sonnet_task = any(re.search(p, prompt_lower) for p in sonnet_patterns)

        if is_haiku_task:
            recommendation = "haiku"
        elif is_sonnet_task:
            recommendation = "sonnet"
        else:
            recommendation = None

block = False
message = ""

if not is_override:
    if recommendation == "haiku" and (is_opus or is_sonnet):
        block = True
        if is_opus:
            message = "This looks like a simple mechanical task (git, rename, format). Haiku handles these identically at ~90% less cost than Opus. Switch to Haiku and re-send. (Prefix with ! to override.)"
        else:
            message = "This looks like a simple mechanical task. Haiku handles these identically at ~80% less cost than Sonnet. Switch to Haiku and re-send. (Prefix with ! to override.)"
    elif recommendation in ("sonnet", "sonnet-4.5") and is_opus:
        block = True
        message = "Standard implementation work. Sonnet 4.5 handles this at ~95% less cost with the same quality. Switch to Sonnet 4.5 and re-send. (Prefix with ! to override.)"
    elif recommendation == "sonnet-4.6" and is_opus:
        block = True
        message = "Complex work detected. Sonnet 4.6 matches Opus quality at ~90% less cost. Switch to Sonnet 4.6 and re-send. (Prefix with ! to override only if Sonnet 4.6 has already failed on this task.)"
    elif recommendation in ("sonnet", "sonnet-4.5", "sonnet-4.6") and is_haiku:
        block = True
        message = "This needs more than Haiku can handle. Switch to Sonnet 4.5 for better results. (Prefix with ! to override.)"
    elif is_opus:
        # Block all remaining Opus usage — step-up routing handles complex work
        block = True
        message = "Opus is disabled for cost control ($1-5/call, $35-209 in MAX mode). Use Sonnet 4.5 for standard work or Sonnet 4.6 for complex tasks — both handle Opus-level work at 90-95% less cost. Switch to Sonnet and re-send. (Prefix with ! only if Sonnet 4.6 has failed twice on this exact task.)"

rec = recommendation if recommendation else "uncertain"
action = "OVERRIDE" if is_override else ("BLOCK" if block else "ALLOW")

try:
    log_dir = os.path.expanduser("~/.cursor/hooks")
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, "model-matchmaker.ndjson")
    snippet = clean_prompt[:40].replace(chr(10), " ").replace(chr(34), chr(39))
    
    # Check if auto-switch is enabled and would be triggered for this block
    auto_switch_enabled = os.path.exists(os.path.join(log_dir, ".auto-switch-enabled"))
    auto_switch_attempted = auto_switch_enabled and block
    
    # Cost tier for analytics tracking
    if rec == "haiku":
        cost_tier = "low"
    elif rec in ("sonnet-4.5", "sonnet") and "4.6" not in model:
        cost_tier = "medium"
    elif rec == "sonnet-4.6" or "4.6" in model:
        cost_tier = "medium-high"
    else:
        cost_tier = "high"

    entry = {
        "event": "recommendation",
        "ts": datetime.now().isoformat(),
        "conversation_id": conversation_id,
        "generation_id": generation_id,
        "model": model,
        "recommendation": rec,
        "action": action,
        "word_count": word_count,
        "prompt_snippet": snippet,
        "auto_switch_attempted": auto_switch_attempted,
        "cost_tier": cost_tier,
    }
    with open(log_path, "a") as f:
        f.write(json.dumps(entry) + "\n")
    
    # Save block metadata for compliance tracking
    if block:
        state_path = os.path.join(log_dir, ".last-block-state.json")
        block_state = {
            "conversation_id": conversation_id,
            "generation_id": generation_id,
            "blocked_model": model,
            "recommended_model": rec,
            "block_ts": datetime.now().isoformat(),
        }
        with open(state_path, "w") as f:
            json.dump(block_state, f)
        
        # Check if auto-switch is enabled
        auto_switch_flag = os.path.join(log_dir, ".auto-switch-enabled")
        if os.path.exists(auto_switch_flag):
            # Trigger auto-switch via keyboard automation
            auto_switch_script = os.path.join(log_dir, "auto-switch-model.sh")
            if os.path.exists(auto_switch_script):
                import subprocess
                try:
                    # Pass workspace info so auto-switch can target the correct Cursor window
                    workspace_roots = data.get("workspace_roots", [])
                    workspace_name = ""
                    if workspace_roots:
                        workspace_name = os.path.basename(workspace_roots[0])
                    
                    env = os.environ.copy()
                    env["WINDOW_TITLE"] = workspace_name
                    env["CONVERSATION_ID"] = conversation_id
                    
                    subprocess.Popen([auto_switch_script, rec], 
                                   stdout=subprocess.DEVNULL, 
                                   stderr=subprocess.DEVNULL,
                                   start_new_session=True,
                                   env=env)
                except:
                    pass
except:
    pass

if is_override:
    print(json.dumps({"continue": True}))
elif block:
    print(json.dumps({"continue": False, "user_message": message}))
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
