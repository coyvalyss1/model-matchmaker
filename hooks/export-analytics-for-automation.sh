#!/bin/bash
# Export analytics data for Cursor Automation consumption
# Output: JSON summary suitable for AI analysis and PR generation

LOG_FILE="$HOME/.cursor/hooks/model-matchmaker.ndjson"
OUTPUT_FILE="$HOME/.cursor/hooks/automation-input.json"

echo "Exporting analytics data for Cursor Automation..."

python3 <<'PYEOF'
import json
import os
from collections import Counter, defaultdict
from datetime import datetime, timedelta

log_file = os.path.expanduser("~/.cursor/hooks/model-matchmaker.ndjson")
output_file = os.path.expanduser("~/.cursor/hooks/automation-input.json")

# Read all entries
entries = []
try:
    with open(log_file) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    entries.append(json.loads(line))
                except:
                    pass
except FileNotFoundError:
    print(f"Error: Log file not found at {log_file}")
    exit(1)

# Filter to recommendations only
recs = [e for e in entries if e.get("event") == "recommendation"]

if not recs:
    print("No recommendation data found")
    exit(1)

# Extract insights
overrides = [e for e in recs if e.get("action") == "OVERRIDE"]
uncertain = [e for e in recs if e.get("recommendation") == "uncertain"]
blocks = [e for e in recs if e.get("action") == "BLOCK"]
haiku_blocks = [e for e in blocks if e.get("recommendation") == "haiku"]
sonnet_blocks = [e for e in blocks if e.get("recommendation") == "sonnet"]
opus_blocks = [e for e in blocks if e.get("recommendation") == "opus"]

# Analyze uncertain prompts for patterns
uncertain_snippets = [e.get("prompt_snippet", "") for e in uncertain]
uncertain_word_counts = [e.get("word_count", 0) for e in uncertain]

# Find common words in uncertain prompts (candidates for new patterns)
word_freq = Counter()
for snippet in uncertain_snippets:
    words = snippet.lower().split()
    word_freq.update(words)

# Most common words (excluding common stopwords)
stopwords = {"a", "the", "is", "in", "to", "of", "and", "for", "on", "with", "this", "that", "it", "at"}
common_words = [(w, c) for w, c in word_freq.most_common(30) if w not in stopwords and len(w) > 3]

# Analyze override patterns
override_details = []
for e in overrides:
    override_details.append({
        "snippet": e.get("prompt_snippet", ""),
        "model": e.get("model", ""),
        "recommended": e.get("recommendation", ""),
        "word_count": e.get("word_count", 0),
    })

# Analyze low-performing recommendations
haiku_snippets = [e.get("prompt_snippet", "") for e in haiku_blocks]

# Calculate key metrics
total = len(recs)
uncertain_rate = len(uncertain) / total * 100 if total > 0 else 0
override_rate = len(overrides) / total * 100 if total > 0 else 0
block_rate = len(blocks) / total * 100 if total > 0 else 0

# Date range
dates = []
for e in recs:
    ts = e.get("ts", "")
    if ts:
        try:
            dates.append(datetime.fromisoformat(ts))
        except:
            pass

date_range = ""
if dates:
    date_range = f"{min(dates).strftime('%Y-%m-%d')} to {max(dates).strftime('%Y-%m-%d')}"

# Export structured data
output = {
    "generated_at": datetime.now().isoformat(),
    "date_range": date_range,
    "summary": {
        "total_prompts": total,
        "uncertain_rate": round(uncertain_rate, 1),
        "override_rate": round(override_rate, 1),
        "block_rate": round(block_rate, 1),
    },
    "issues": {
        "high_uncertain_rate": uncertain_rate > 50,
        "override_count": len(overrides),
        "haiku_blocks_count": len(haiku_blocks),
    },
    "uncertain_analysis": {
        "count": len(uncertain),
        "avg_word_count": round(sum(uncertain_word_counts) / len(uncertain_word_counts), 1) if uncertain_word_counts else 0,
        "sample_snippets": uncertain_snippets[:20],
        "common_words": common_words[:15],
    },
    "override_analysis": {
        "count": len(overrides),
        "details": override_details,
    },
    "block_analysis": {
        "haiku_blocks": len(haiku_blocks),
        "haiku_snippets": haiku_snippets[:10],
        "sonnet_blocks": len(sonnet_blocks),
        "opus_blocks": len(opus_blocks),
    },
    "suggested_improvements": [
        {
            "priority": "HIGH",
            "issue": "Uncertain rate above 50%",
            "recommendation": "Add patterns for short prompts (2-10 words) that appear frequently in uncertain prompts"
        },
        {
            "priority": "MEDIUM",
            "issue": f"{len(haiku_blocks)} Haiku blocks",
            "recommendation": "Review Haiku threshold (currently <60 words) to ensure it's not too aggressive"
        },
        {
            "priority": "LOW",
            "issue": "Context-aware classification",
            "recommendation": "Consider using conversation history or attachments for better classification"
        },
    ],
}

# Write to output file
with open(output_file, "w") as f:
    json.dump(output, f, indent=2)

print(f"✓ Exported analytics data to {output_file}")
print(f"  - {total} prompts analyzed")
print(f"  - {len(uncertain)} uncertain ({uncertain_rate:.1f}%)")
print(f"  - {len(overrides)} overrides ({override_rate:.1f}%)")
print(f"  - {len(blocks)} blocks ({block_rate:.1f}%)")
PYEOF

echo ""
echo "Automation input ready at: $OUTPUT_FILE"
echo "Use this file with Cursor Automations to generate classifier improvements."
