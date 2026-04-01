# Token Usage Optimization Guide

A practical reference for keeping Cursor costs under control without slowing down your work.

---

## Quick Wins (Zero Effort)

**1. Use Sonnet 4.5 as your default** (not 4.6, not Opus)
- Sonnet 4.5 handles 80% of daily work well
- Step up to 4.6 only when 4.5 falls short
- 90% cheaper than Opus per request

**2. Let Model Matchmaker block you**
- 85% compliance rate means you agree with it most of the time
- Each Opus block saves $1–5
- Each Sonnet 4.6→4.5 step-down saves $0.10–0.20

**3. Start new chats for new topics**
- Each message in a long chat carries the full prior context
- A 50-message chat costs 3–5x more per message than a fresh chat
- Rule of thumb: new chat every major topic shift

**4. Default to sequential agents**
- Parallel only when truly blocked >30 min
- Each parallel agent = 1x full context cost
- See `PARALLEL_AGENT_CHECKLIST.md` before spawning 3+ agents

---

## Large File Editing (Cost-Effective Patterns)

Large files (>1,000 lines) are the biggest single source of context bloat. Never load the full file when you only need part of it.

### Bad Pattern (expensive)
```
"Fix the bug in LifePageV7.jsx"
→ AI reads entire 10,000-line file into context (~75K tokens)
```

### Good Pattern (cheap)
```
"Read lines 500–600 of LifePageV7.jsx where the useEffect is defined"
→ AI reads 100 lines (~750 tokens) — 100x less context
```

### Targeted Edit Pattern
Use `StrReplace` with precise old/new strings — no full file load needed:
```
"In LifePageV7.jsx, replace:
  const [foo, setFoo] = useState(null)
with:
  const [foo, setFoo] = useState([])"
```

### When You Must Work With a Large File
1. Read only the relevant section (specify line range)
2. Make the change with StrReplace (not full rewrite)
3. Verify with a targeted read of the changed section only
4. Never ask "what does this file do?" on a large file — use Grep instead

### High-Cost Files to Watch
These files are large enough to significantly impact context:
- `valyss-app/client/src/pages/life/LifePageV7.jsx` (~10,000 lines, ~75K tokens)
- `valyss-app/client/src/hooks/useLifeRXChatV4.jsx` (~3,000 lines, ~25K tokens)
- Any file >5,000 lines
- Any agent transcript or log file

---

## Cursor Settings That Save Tokens

These settings are configured in `~/Library/Application Support/Cursor/User/settings.json`:

| Setting | Value | What It Does |
|---------|-------|--------------|
| `cursor.general.enableIndexing` | `true` | Uses codebase index instead of reading full files repeatedly |
| `cursor.general.maxFileSizeMB` | `5` | Skips huge files from auto-context (you can still read them explicitly) |
| `cursor.general.gitignoreEnabled` | `true` | Respects .gitignore — won't auto-include node_modules, build/, etc. |
| `cursor.cpp.disableCaching` | `false` | Enables response caching (reduces redundant API calls) |
| `cursor.chat.maxTokens` | `4096` | Caps response length — prevents runaway generations |
| `cursor.composer.contextLimit` | `50000` | Limits Composer context window (prevents 200K+ sessions) |
| `ai.thinkingEnabled` | `false` | Hides reasoning tokens (already set — keeps this off) |

**Note on maxFileSizeMB:** This only affects auto-context inclusion. You can still explicitly read any file with the Read tool or by opening it. If you need to edit a large file, use targeted line reads + StrReplace rather than loading the whole thing.

---

## Parallel Agent Cost Reality

Each parallel agent is billed separately and carries the full conversation context.

| Agents | Model | Rough Cursor Cost |
|--------|-------|------------------|
| 1 sequential | Sonnet 4.5 | $0.08–0.30 |
| 3 parallel | Sonnet 4.5 | $0.24–0.90 |
| 3 parallel | Sonnet 4.6 | $0.30–1.50 |
| 3 parallel | Opus | $3–15 |
| 5 parallel | Opus (R&D session) | $25–85 |

**The March 2026 spike:** A single R&D session with 3–5 parallel Opus agents cost ~$150. The same work done sequentially with Sonnet 4.5 would have cost ~$5–15.

Before spawning parallel agents, run through `PARALLEL_AGENT_CHECKLIST.md`.

---

## Monthly Cost Review

Run this at the start of each month (takes 5 minutes):

```bash
# Check last 30 days of Model Matchmaker activity
cd ~/.cursor/hooks && bash analytics.sh --days 30

# Key metrics to check:
# - Uncertain rate (target: <50%)
# - Haiku compliance (target: >80%)
# - Opus blocks (each = $3-5 saved)
# - Sonnet 4.6→4.5 step-downs (each = $0.15 saved)
```

Then check your Cursor billing page for actual spend vs. target (<$200).

See `MONTHLY_COST_REVIEW.md` for the full template.

---

## Model Selection Cheat Sheet

```
Git, rename, format, lint          →  Haiku 4.5
Feature, debug, refactor, plan     →  Sonnet 4.5  ← DEFAULT
Regression, architecture, perf     →  Sonnet 4.6
Sonnet 4.6 failed twice            →  ! override → Opus
```
