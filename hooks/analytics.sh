#!/bin/bash
# Model Matchmaker Analytics
# Parses NDJSON logs and prints accuracy/usage/cost metrics.
# Usage: ./hooks/analytics.sh [--json] [--days N] [--savings]
#   Options can be in any order.

LOG_PATH="${HOME}/.cursor/hooks/model-matchmaker.ndjson"

if [ ! -f "$LOG_PATH" ]; then
    echo "No analytics data found at $LOG_PATH"
    echo "Start using Model Matchmaker and data will be collected automatically."
    exit 0
fi

# Order-independent argument parsing
DAYS=0
JSON_OUT=false
SAVINGS_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --json) JSON_OUT=true ;;
        --savings) SAVINGS_ONLY=true ;;
        --days) ;; # value handled below
        *)
            # Check if previous arg was --days
            if [ "${prev_arg:-}" = "--days" ]; then
                DAYS="$arg"
            fi
            ;;
    esac
    prev_arg="$arg"
done

MM_LOG_PATH="$LOG_PATH" MM_DAYS="$DAYS" MM_JSON="$JSON_OUT" MM_SAVINGS="$SAVINGS_ONLY" python3 << 'PYEOF'
import json, sys, os
from datetime import datetime, timedelta
from collections import Counter, defaultdict

log_path = os.environ["MM_LOG_PATH"]
days_filter = int(os.environ["MM_DAYS"])
json_out = os.environ["MM_JSON"] == "true"
savings_only = os.environ["MM_SAVINGS"] == "true"

recs = []
completions = []
cutoff = None
if days_filter > 0:
    cutoff = datetime.now() - timedelta(days=days_filter)

with open(log_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except Exception:
            continue
        if cutoff:
            try:
                ts = datetime.fromisoformat(entry.get("ts", ""))
                if ts < cutoff:
                    continue
            except Exception:
                continue
        if entry.get("event") == "recommendation":
            recs.append(entry)
        elif entry.get("event") == "completion":
            completions.append(entry)

total_recs = len(recs)
if total_recs == 0:
    if json_out:
        print(json.dumps({"error": "no data"}))
    else:
        print("No recommendation data found.")
    sys.exit(0)

actions = Counter(r["action"] for r in recs)
rec_types = Counter(r["recommendation"] for r in recs)
models_used = Counter(r["model"] for r in recs)

overrides = [r for r in recs if r["action"] == "OVERRIDE"]
blocks = [r for r in recs if r["action"] == "BLOCK"]
allows = [r for r in recs if r["action"] == "ALLOW"]

override_rate = len(overrides) / total_recs * 100 if total_recs else 0
block_rate = len(blocks) / total_recs * 100 if total_recs else 0

# Override analysis
override_details = Counter()
for o in overrides:
    key = o["model"] + " (rec: " + o["recommendation"] + ")"
    override_details[key] += 1

# Block analysis
block_details = Counter()
for b in blocks:
    key = b["model"] + " -> " + b["recommendation"]
    block_details[key] += 1

# Cost analysis
total_estimated_spend = 0.0
total_estimated_savings = 0.0
cost_by_provider = defaultdict(float)
savings_by_tier = defaultdict(float)

for r in recs:
    cost_current = r.get("estimated_cost_current", 0)
    cost_rec = r.get("estimated_cost_recommended", 0)
    est_savings = r.get("estimated_savings", 0)
    provider = r.get("current_provider", "unknown")
    tier = r.get("required_tier")

    if r["action"] == "BLOCK":
        total_estimated_savings += est_savings
    total_estimated_spend += cost_current
    cost_by_provider[provider] += cost_current
    if tier and est_savings > 0:
        tier_label = {1: "mechanical", 2: "implementation", 3: "architecture"}.get(tier, "other")
        savings_by_tier[tier_label] += est_savings

savings_rate = (total_estimated_savings / (total_estimated_savings + total_estimated_spend) * 100
                if (total_estimated_savings + total_estimated_spend) > 0 else 0)

# Environmental impact estimate
# Rough: $1 LLM cost ~ 0.1 kWh ~ 40g CO2
co2_saved_grams = total_estimated_savings * 40
kwh_saved = total_estimated_savings * 0.1
phone_charges = kwh_saved / 0.012  # ~12Wh per phone charge

# Completion analysis
completion_by_conv = {}
for c in completions:
    cid = c.get("conversation_id", "")
    if cid:
        completion_by_conv[cid] = c

rec_by_conv = defaultdict(list)
for r in recs:
    cid = r.get("conversation_id", "")
    if cid:
        rec_by_conv[cid].append(r)

completed_convs = 0
errored_convs = 0
aborted_convs = 0
override_completed = 0
override_errored = 0
for cid, comp in completion_by_conv.items():
    status = comp.get("status", "")
    had_override = any(r["action"] == "OVERRIDE" for r in rec_by_conv.get(cid, []))
    if status == "completed":
        completed_convs += 1
        if had_override:
            override_completed += 1
    elif status == "error":
        errored_convs += 1
        if had_override:
            override_errored += 1
    elif status == "aborted":
        aborted_convs += 1

# Quick savings summary
if savings_only:
    if json_out:
        print(json.dumps({
            "total_savings": round(total_estimated_savings, 4),
            "total_spend": round(total_estimated_spend, 4),
            "savings_rate": round(savings_rate, 1),
            "co2_saved_grams": round(co2_saved_grams, 1),
        }))
    else:
        print(f"Savings: ${total_estimated_savings:.4f} "
              f"({savings_rate:.1f}% of ${total_estimated_spend:.4f} total) "
              f"| CO2 saved: {co2_saved_grams:.1f}g")
    sys.exit(0)

# Full output
if json_out:
    print(json.dumps({
        "total_recommendations": total_recs,
        "actions": dict(actions),
        "recommendations": dict(rec_types),
        "models_used": dict(models_used),
        "override_rate": round(override_rate, 1),
        "block_rate": round(block_rate, 1),
        "override_details": dict(override_details),
        "block_details": dict(block_details),
        "cost": {
            "total_estimated_spend": round(total_estimated_spend, 4),
            "total_estimated_savings": round(total_estimated_savings, 4),
            "savings_rate": round(savings_rate, 1),
            "by_provider": {k: round(v, 4) for k, v in cost_by_provider.items()},
            "savings_by_tier": {k: round(v, 4) for k, v in savings_by_tier.items()},
        },
        "environment": {
            "co2_saved_grams": round(co2_saved_grams, 1),
            "kwh_saved": round(kwh_saved, 4),
            "phone_charges_equivalent": round(phone_charges, 1),
        },
        "completions": {
            "completed": completed_convs,
            "errored": errored_convs,
            "aborted": aborted_convs,
        },
        "override_outcomes": {
            "completed": override_completed,
            "errored": override_errored,
        },
    }, indent=2))
else:
    print("=" * 55)
    print("  MODEL MATCHMAKER ANALYTICS")
    period = f" (last {days_filter} days)" if days_filter > 0 else ""
    print(f"  {total_recs} recommendations tracked{period}")
    print("=" * 55)

    print(f"\n  Actions:")
    for action, count in actions.most_common():
        pct = count / total_recs * 100
        print(f"    {action:>10}: {count:>4} ({pct:.1f}%)")

    print(f"\n  Override rate: {override_rate:.1f}%")
    print(f"  Block rate:    {block_rate:.1f}%")

    if override_details:
        print(f"\n  Override breakdown (you disagreed):")
        for detail, count in override_details.most_common():
            print(f"    {detail}: {count}")

    if block_details:
        print(f"\n  Block breakdown (model mismatch):")
        for detail, count in block_details.most_common():
            print(f"    {detail}: {count}")

    print(f"\n  Recommendations:")
    for rec, count in rec_types.most_common():
        pct = count / total_recs * 100
        print(f"    {rec:>20}: {count:>4} ({pct:.1f}%)")

    print(f"\n  Models used:")
    for model, count in models_used.most_common():
        print(f"    {model}: {count}")

    # Cost section
    print(f"\n  " + "-" * 45)
    print(f"  COST ANALYSIS")
    print(f"  " + "-" * 45)
    print(f"    Estimated total spend:   ${total_estimated_spend:.4f}")
    print(f"    Estimated total savings: ${total_estimated_savings:.4f}")
    print(f"    Savings rate:            {savings_rate:.1f}%")

    if cost_by_provider:
        print(f"\n    Spend by provider:")
        for prov, cost in sorted(cost_by_provider.items(), key=lambda x: -x[1]):
            print(f"      {prov}: ${cost:.4f}")

    if savings_by_tier:
        print(f"\n    Savings by task tier:")
        for tier, sav in sorted(savings_by_tier.items(), key=lambda x: -x[1]):
            print(f"      {tier}: ${sav:.4f}")

    # Environmental impact
    print(f"\n  " + "-" * 45)
    print(f"  ENVIRONMENTAL IMPACT")
    print(f"  " + "-" * 45)
    print(f"    Est. CO2 saved:     {co2_saved_grams:.1f}g")
    print(f"    Est. energy saved:  {kwh_saved:.4f} kWh")
    if phone_charges >= 0.1:
        print(f"    Equivalent to:      {phone_charges:.1f} phone charges")

    total_completions = completed_convs + errored_convs + aborted_convs
    if total_completions > 0:
        print(f"\n  Task Outcomes ({total_completions} conversations):")
        print(f"    Completed: {completed_convs}")
        print(f"    Errored:   {errored_convs}")
        print(f"    Aborted:   {aborted_convs}")
        if override_completed + override_errored > 0:
            print(f"\n  Override Outcomes:")
            print(f"    Completed after override: {override_completed}")
            print(f"    Errored after override:   {override_errored}")

    # Auto-switch impact tracking
    auto_switched = [e for e in recs if e.get('auto_switch_attempted') == True]
    manual_blocks = [e for e in blocks if not e.get('auto_switch_attempted')]
    
    if auto_switched:
        print(f'\n  Auto-Switch Impact:')
        print(f'    Blocks with auto-switch: {len(auto_switched)}')
        print(f'    Manual blocks: {len(manual_blocks)}')
        auto_switch_rate = len(auto_switched) / len(blocks) * 100 if blocks else 0
        print(f'    Auto-switch rate: {auto_switch_rate:.1f}%')

    print()
    print("=" * 55)
    print(f"  Log file: {log_path}")
    print(f"  Quick check: ./hooks/analytics.sh --savings")
    print("=" * 55)
PYEOF
