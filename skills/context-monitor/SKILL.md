---
name: context-monitor
description: Monitor conversation context and prevent MAX mode by warning at token thresholds and generating handoff summaries. Use when context approaches 100K/150K/180K tokens or when working with high-cost files.
---

# MAX Mode Prevention & Context Monitoring

## The Problem

Cursor's MAX mode (Claude Opus 3.5, 200K token context) is expensive and should be reserved for truly complex tasks. Context can balloon quickly when:
- Opening large files (e.g., a 9,378-line React component)
- Loading chat transcripts or logs (1-10MB)
- Accumulating tool calls and responses across long sessions
- Reading multiple files speculatively

**Once context exceeds 200K tokens, the conversation is forced into a new chat with a handoff summary.** This wastes user time and disrupts flow.

## The Solution

**Monitor context throughout the conversation (not just at start).** Warn at thresholds and proactively recommend starting a new chat with a clean handoff.

## Token Thresholds

### 🟡 Yellow Alert (100K tokens)
**Action**: Note the context size internally. No user warning yet.

### 🟠 Orange Alert (150K tokens)
**Action**: Warn the user and suggest wrapping up current work or starting a new chat if the task is open-ended.

**Warning format:**
```
⚠️ Context approaching 150K tokens. Consider starting a new chat after this task to avoid MAX mode. I can generate a handoff summary.
```

### 🔴 Red Alert (180K tokens)
**Action**: Strongly recommend starting a new chat. Offer to generate a handoff summary immediately.

**Warning format:**
```
🚨 Context at 180K tokens (MAX mode limit: 200K). Recommend starting a new chat now. I can generate a handoff summary with:
- Task description
- Progress so far
- Next steps
- @file references
```

## Automatic Triggers

Issue a warning automatically when:

1. **Large file opened** (>3,000 lines):
   - Example: DashboardPage.jsx (9,378 lines) = ~70K tokens
   - Example: useChatManager.jsx (4,178 lines) = ~30K tokens
   - Any file >5,000 lines = likely >40K tokens

2. **Multiple large files in context** (>5 files over 1,000 lines each)

3. **Long conversation** (>50 tool calls in current chat)

4. **Transcript search** (reading agent-transcripts/*.txt files)

5. **Plan file creation** (plans are meta-work that inflate context)

## High-Cost Files (Known)

Track your project's largest files and add them to your monitoring list. Common examples:

- Main dashboard/app components (5,000-10,000 lines)
- Complex state management hooks (3,000-5,000 lines)
- Generated files (API clients, schema definitions)
- Any `.log` file
- Any agent transcript (`.txt` files in agent-transcripts/)

**When opening these files**, immediately note context cost and warn if already over 100K.

**To find your largest files:**
```bash
find . -name "*.jsx" -o -name "*.tsx" -o -name "*.js" -o -name "*.ts" | \
  xargs wc -l | sort -rn | head -20
```

## Handoff Summary Format

When recommending a new chat, generate a concise handoff summary using this template:

```markdown
## Handoff Summary for New Chat

**Task**: [One-line description]

**Progress**:
- [Bullet point 1]
- [Bullet point 2]
- [Bullet point 3]

**Next Steps**:
1. [Action item 1]
2. [Action item 2]
3. [Action item 3]

**Key Files**:
- @path/to/file1.jsx — [what was changed/what needs work]
- @path/to/file2.js — [what was changed/what needs work]

**Context**: [1-2 sentences of critical context that must be preserved]
```

**Handoff example:**

```markdown
## Handoff Summary for New Chat

**Task**: Fix chat component falling back to short responses when user profile is empty

**Progress**:
- Identified root cause: validation guard blocking all saves when user data incomplete
- Removed guard from useChatManager.jsx (lines 2847-2863)
- Added fallback examples to API helper function

**Next Steps**:
1. Test save flow with empty profile
2. Verify data structure generation on first save
3. Deploy to production if test passes

**Key Files**:
- @src/hooks/useChatManager.jsx — Removed validation guard
- @server/helpers/apiHelper.js — Added fallback examples

**Context**: The short-response fallback was a symptom, not the root cause. Real issue was validation logic preventing data generation.
```

## Implementation Guide

### For Cursor AI

At the start of each response:
1. **Check conversation length** (tool call count, file read count)
2. **Check if large files are in context** (match against known high-cost files list)
3. **Estimate current token count** (rough heuristic: 50 tool calls = ~100K tokens; one 9K line file = ~70K tokens)
4. **Issue warning if threshold crossed**

### Mid-Conversation Monitoring

After opening a large file:
```
📊 Context note: DashboardPage.jsx added (~70K tokens). Current context estimate: ~120K tokens.
```

After 30+ tool calls:
```
⚠️ Context approaching 150K tokens (30+ tool calls). Consider wrapping up or starting fresh chat.
```

### Handoff Trigger Phrases

When the user says:
- "This is taking forever"
- "Start a new chat"
- "Can we move to a new conversation?"
- "Feels like we're dragging"
- "MAX mode is too expensive"

**Immediately generate a handoff summary** without asking.

## Cost Comparison

**Typical scenario without monitoring:**
- Start chat: 20K tokens
- Open DashboardPage.jsx: +70K = 90K
- Open useChatManager.jsx: +30K = 120K
- 20 tool calls: +40K = 160K
- Read logs/transcripts: +30K = 190K
- **Triggers MAX mode** (expensive, could have been avoided)

**With monitoring:**
- Warning at 150K → user starts new chat
- New chat: 20K tokens
- Continue work efficiently
- **Savings: 170K tokens** (stays under 200K limit)

## When NOT to Warn

Don't warn if:
- The task is nearly complete (1-2 steps remaining)
- The user explicitly said "use MAX mode" or "I don't care about cost"
- The conversation is already at the final deployment/verification stage

## Testing the Skill

To verify this skill is working:

1. **Open a large file (>5,000 lines)** → Should see context note
2. **Make 30+ tool calls** → Should see 150K warning
3. **Request a new chat** → Should get formatted handoff summary
4. **Open multiple large files** → Should see cumulative context estimate

## Integration with .cursorrules

This skill should be referenced in `.cursorrules` after the "Prior Session Context" section (around line 106):

```markdown
## MAX Mode Prevention & Context Monitoring

Monitor conversation context to avoid triggering MAX mode (200K token limit). See `.cursor/skills/context-monitor/SKILL.md` for full logic.

**Quick reference:**
- 🟡 100K tokens: Note internally
- 🟠 150K tokens: Warn user, suggest wrapping up
- 🔴 180K tokens: Recommend new chat with handoff summary

**High-cost files (auto-warn when opened):**
- Any file >5,000 lines (typically ~40-70K tokens)
- Any file >3,000 lines if other large files already in context
- Any agent transcript or log file

**When recommending new chat**, generate handoff summary with: task description, progress, next steps, @file references, critical context.
```

## Why This Matters

- **Cost control**: MAX mode is expensive. Staying under 200K tokens saves money.
- **Conversation efficiency**: Handoff summaries preserve context without bloating the next chat.
- **User experience**: Proactive warnings let users decide when to break vs. AI forcing it.
- **Strategic file loading**: Knowing the cost of opening a file helps with decision-making.

**This skill should be applied automatically throughout every conversation, not just when explicitly invoked.**
