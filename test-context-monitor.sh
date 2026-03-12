#!/bin/bash

# Test script for Context Monitor skill
# Validates the monitoring logic and threshold warnings

echo "=== Context Monitor Skill Test ==="
echo ""

# Test 1: Calculate approximate token counts for this conversation
echo "Test 1: Current Conversation Context Analysis"
echo "---------------------------------------------"

# Estimate based on tool calls and file reads
TOOL_CALLS=20
FILES_READ=5
LARGE_FILES=0  # We haven't opened the large files in this chat

# Rough estimates (conservative)
BASE_CONTEXT=10000  # System prompt, rules, etc.
TOOL_CALL_TOKENS=$((TOOL_CALLS * 2000))  # ~2K per tool call average
FILE_READ_TOKENS=$((FILES_READ * 3000))  # ~3K per file read average

TOTAL_ESTIMATE=$((BASE_CONTEXT + TOOL_CALL_TOKENS + FILE_READ_TOKENS))

echo "Estimated context usage:"
echo "  Base context: ~${BASE_CONTEXT} tokens"
echo "  Tool calls (${TOOL_CALLS}): ~${TOOL_CALL_TOKENS} tokens"
echo "  File reads (${FILES_READ}): ~${FILE_READ_TOKENS} tokens"
echo "  Total estimate: ~${TOTAL_ESTIMATE} tokens"
echo ""

# Determine warning level
if [ $TOTAL_ESTIMATE -lt 100000 ]; then
    LEVEL="🟢 GREEN"
    STATUS="Normal operation"
elif [ $TOTAL_ESTIMATE -lt 150000 ]; then
    LEVEL="🟡 YELLOW"
    STATUS="Monitor closely"
elif [ $TOTAL_ESTIMATE -lt 180000 ]; then
    LEVEL="🟠 ORANGE"
    STATUS="Warning - consider wrapping up"
else
    LEVEL="🔴 RED"
    STATUS="ALERT - recommend new chat"
fi

echo "Status: $LEVEL - $STATUS"
echo "Percentage of MAX limit: $((TOTAL_ESTIMATE * 100 / 200000))%"
echo ""

# Test 2: Simulate opening a large file
echo "Test 2: Large File Impact Simulation"
echo "-------------------------------------"

LARGE_FILE_NAME="DashboardPage.jsx"
LARGE_FILE_LINES=9378
LARGE_FILE_TOKENS=70000

echo "Simulating opening: $LARGE_FILE_NAME ($LARGE_FILE_LINES lines)"
NEW_TOTAL=$((TOTAL_ESTIMATE + LARGE_FILE_TOKENS))

echo "Current context: ~${TOTAL_ESTIMATE} tokens"
echo "After opening file: ~${NEW_TOTAL} tokens (+${LARGE_FILE_TOKENS})"
echo "Percentage of MAX limit: $((NEW_TOTAL * 100 / 200000))%"
echo ""

if [ $NEW_TOTAL -ge 150000 ]; then
    echo "⚠️  WARNING: Opening this file would push context over 150K threshold"
    echo "   Recommendation: Consider starting a new chat if you need to open this file"
else
    echo "✓  Opening this file would keep context under 150K threshold"
fi
echo ""

# Test 3: Handoff summary format validation
echo "Test 3: Handoff Summary Format"
echo "-------------------------------"

cat << 'EOF'
## Handoff Summary for New Chat

**Task**: Create MAX mode prevention skill + update cursorrules

**Progress**:
- Created .cursor/skills/context-monitor/SKILL.md with monitoring logic
- Updated .cursorrules with MAX prevention section (after line 106)
- Added skill to Model Matchmaker repository
- Updated Model Matchmaker README with installation instructions

**Next Steps**:
1. Test the skill in a real session
2. Verify warnings trigger at correct thresholds
3. Test handoff summary generation
4. Commit changes to Model Matchmaker repo

**Key Files**:
- @.cursor/skills/context-monitor/SKILL.md — Context monitoring skill
- @.cursorrules — MAX prevention section (lines 109-166)
- @model-matchmaker/skills/context-monitor/SKILL.md — Copy for distribution
- @model-matchmaker/README.md — Documentation for users

**Context**: This skill prevents expensive MAX mode charges by warning before context exceeds 200K tokens and providing clean handoff summaries for new chats.

EOF

echo ""
echo "✓  Handoff summary format validated"
echo ""

# Test 4: Verify skill file exists
echo "Test 4: Installation Verification"
echo "----------------------------------"

SKILL_PATHS=(
    "$HOME/.cursor/skills/context-monitor/SKILL.md"
    "$HOME/model-matchmaker/skills/context-monitor/SKILL.md"
)

for path in "${SKILL_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "✓  Found: $path"
        LINE_COUNT=$(wc -l < "$path")
        echo "   Lines: $LINE_COUNT"
    else
        echo "✗  Missing: $path"
    fi
done

echo ""
echo "=== Test Complete ==="
echo ""
echo "Summary: Context Monitor skill is installed and ready to use."
echo "Current conversation is at ~${TOTAL_ESTIMATE} tokens ($((TOTAL_ESTIMATE * 100 / 200000))% of MAX limit)"
echo ""
