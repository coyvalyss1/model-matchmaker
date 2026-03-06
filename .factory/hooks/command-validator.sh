#!/bin/bash
# Droid PreToolUse hook: validates Execute commands for dangerous patterns.

INPUT=$(cat)

RESULT=$(echo "$INPUT" | python3 -c '
import json, sys, re

try:
    data = json.load(sys.stdin)
except:
    print(json.dumps({"continue": True}))
    sys.exit(0)

tool_name = data.get("tool_name", "")
if tool_name != "Execute":
    print(json.dumps({"continue": True}))
    sys.exit(0)

tool_input = data.get("tool_input", {})
command = tool_input.get("command", "")

dangerous_patterns = [
    (r"rm\s+-rf\s+/", "Attempting to delete root directory"),
    (r"rm\s+-rf\s+~", "Attempting to delete home directory"),
    (r":\(\)\{\s*:\|:&\s*\};:", "Fork bomb detected"),
    (r"curl.*\|\s*bash", "Piping remote script to bash"),
    (r"wget.*\|\s*sh", "Piping remote script to shell"),
    (r"git\s+push\s+--force", "Force pushing to remote (use with caution)"),
    (r"chmod\s+-R\s+777", "Setting world-writable permissions recursively"),
    (r"sudo\s+rm", "Using sudo with rm command"),
]

for pattern, warning in dangerous_patterns:
    if re.search(pattern, command, re.IGNORECASE):
        message = f"⚠️  Dangerous command detected: {warning}\n\nCommand: {command[:100]}\n\nIf you are certain, prefix your prompt with ! to override."
        print(json.dumps({"continue": False, "user_message": message}))
        sys.exit(0)

print(json.dumps({"continue": True}))
')

if [ $? -ne 0 ] || [ -z "$RESULT" ]; then
    echo '{"continue": true}'
    exit 0
fi

echo "$RESULT"
exit 0
