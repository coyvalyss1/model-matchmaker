#!/bin/bash
# Droid UserPromptSubmit hook: classifies tasks and recommends appropriate models.

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

if prompt.lstrip().startswith("!"):
    print(json.dumps({"continue": True}))
    sys.exit(0)

prompt_lower = prompt.lower()
word_count = len(prompt.split())

is_opus = "opus" in model
is_sonnet = "sonnet" in model
is_haiku = "haiku" in model

if not (is_opus or is_sonnet or is_haiku):
    print(json.dumps({"continue": True}))
    sys.exit(0)

opus_keywords = [
    "architect", "architecture", "evaluate", "tradeoff", "trade-off",
    "strategy", "strategic", "compare approaches", "why does", "deep dive",
    "redesign", "across the codebase", "investor", "multi-system",
    "complex refactor", "analyze", "analysis", "plan mode", "rethink",
    "high-stakes", "critical decision"
]

has_opus_signal = any(kw in prompt_lower for kw in opus_keywords)
is_long_analytical = word_count > 100 and "?" in prompt
is_multi_paragraph = word_count > 200

if has_opus_signal or is_long_analytical or is_multi_paragraph:
    recommendation = "opus"
else:
    haiku_patterns = [
        r"\bgit\s+(commit|push|pull|status|log|diff|add|stash|branch|merge|rebase|checkout)\b",
        r"\bcommit\b.*\b(change|push|all)\b", r"\bpush\s+(to|the|remote|origin)\b",
        r"\brename\b", r"\bre-?order\b", r"\bmove\s+file\b", r"\bdelete\s+file\b",
        r"\badd\s+(import|route|link)\b", r"\bformat\b", r"\blint\b",
        r"\bprettier\b", r"\beslint\b", r"\bremove\s+(unused|dead)\b",
        r"\bupdate\s+(version|package)\b"
    ]
    is_haiku_task = word_count < 60 and any(re.search(p, prompt_lower) for p in haiku_patterns)

    sonnet_patterns = [
        r"\bbuild\b", r"\bimplement\b", r"\bcreate\b", r"\bfix\b", r"\bdebug\b",
        r"\badd\s+feature\b", r"\bwrite\b", r"\bcomponent\b", r"\bservice\b",
        r"\bpage\b", r"\bdeploy\b", r"\btest\b", r"\bupdate\b", r"\brefactor\b",
        r"\bstyle\b", r"\bcss\b", r"\broute\b", r"\bapi\b", r"\bfunction\b"
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

if recommendation == "haiku" and (is_opus or is_sonnet):
    block = True
    if is_opus:
        message = "This looks like a simple mechanical task (git, rename, format). Haiku handles these identically at ~90% less cost than Opus. Switch to Haiku and re-send. (Prefix with ! to override.)"
    else:
        message = "This looks like a simple mechanical task. Haiku handles these identically at ~80% less cost than Sonnet. Switch to Haiku and re-send. (Prefix with ! to override.)"
elif recommendation == "sonnet" and is_opus:
    block = True
    message = "Standard implementation work. Sonnet handles this at ~80% less cost with the same quality. Switch to Sonnet and re-send. (Prefix with ! to override.)"
elif recommendation == "opus" and (is_sonnet or is_haiku):
    block = True
    message = "This looks like architecture, deep analysis, or multi-system work. Switch to Opus for better results, then re-send. (Prefix with ! to override.)"

try:
    log_dir = os.path.join(os.environ.get("FACTORY_PROJECT_DIR", "."), ".factory/hooks")
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, "model-advisor.log")
    snippet = prompt[:20].replace("\n", " ") + ("..." if len(prompt) > 20 else "")
    action = "BLOCK" if block else "ALLOW"
    rec = recommendation if recommendation else "uncertain"
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(log_path, "a") as f:
        f.write(f"[{ts}] model={model} rec={rec} action={action} prompt=\"{snippet}\"\n")
except:
    pass

if block:
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
