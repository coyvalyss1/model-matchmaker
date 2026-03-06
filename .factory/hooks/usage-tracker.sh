#!/bin/bash
# Droid PostToolUse hook: tracks tool usage statistics.

INPUT=$(cat)

python3 -c '
import json, sys, os
from datetime import datetime

try:
    data = json.load(sys.stdin)
except:
    sys.exit(0)

tool_name = data.get("tool_name", "unknown")
session_id = os.environ.get("FACTORY_SESSION_ID", "unknown")

try:
    log_dir = os.path.join(os.environ.get("FACTORY_PROJECT_DIR", "."), ".factory/hooks")
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, "usage-stats.log")
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(log_path, "a") as f:
        f.write(f"[{ts}] session={session_id} tool={tool_name}\n")
except:
    pass
' <<< "$INPUT"

echo '{"continue": true}'
exit 0
