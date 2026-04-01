# Model Capabilities & Cost Reference

**Strategy: Step-Up Routing** — Haiku → Sonnet 4.5 → Sonnet 4.6 → Opus (blocked)

Use the cheapest model that can handle the task. Step up only when needed.

---

## Model Tiers

### Haiku 4.5 — Mechanical Tasks
**Cost:** ~$0.01–0.05 per request

**Use for:**
- Git operations (commit, push, pull, status, diff, log)
- File renames, moves, deletions
- Adding imports or routes
- Formatting and linting
- Simple boilerplate generation

**Do not use for:**
- Debugging (even "simple" bugs)
- Multi-file changes
- Anything with "why", "evaluate", or "analyze"
- Any task where the output quality matters

**Speed:** 1–3s

---

### Sonnet 4.5 — Standard Work (Default)
**Cost:** ~$0.08–0.30 per request

**Use for:**
- Feature implementation (standard complexity)
- Basic debugging and bug fixes
- Multi-file changes (straightforward)
- Code review
- Standard refactors
- Documentation updates
- Planning and writing
- Most daily implementation work

**Step up to 4.6 when:**
- Sonnet 4.5 gives a low-quality or incomplete response
- The task involves regression debugging ("was working before")
- Architecture decisions with significant tradeoffs
- Performance or security analysis

**Speed:** 3–6s  
**Context window:** 200K tokens

---

### Sonnet 4.6 — Complex Work
**Cost:** ~$0.10–0.50 per request

**Use for:**
- Complex debugging (regressions, multi-system issues)
- Architecture decisions
- Novel feature design
- Performance optimization
- Security analysis
- When Sonnet 4.5 has already failed on the task

**Quality level:** Matches or exceeds Opus 4.0 on most tasks

**Speed:** 3–8s  
**Context window:** 200K tokens

---

### Opus 4.0 — BLOCKED
**Cost:** ~$1–5 per request (standard), $35–209 in MAX mode

**Status:** Blocked by Model Matchmaker for cost control.

**Override policy:** Prefix prompt with `!` only if Sonnet 4.6 has failed twice on the same task.

**Why blocked:** Sonnet 4.6 matches Opus quality on 90%+ of tasks at 90% less cost. The cases where Opus genuinely outperforms 4.6 are rare enough that the cost is not justified as a default.

---

## Step-Up Decision Tree

```
Is this a mechanical task? (git, rename, format)
  YES → Haiku 4.5
  NO  → Is this standard implementation/debugging/planning?
          YES → Sonnet 4.5 (default)
          NO  → Is this regression debugging, architecture, or performance?
                  YES → Sonnet 4.6
                  NO  → Has Sonnet 4.6 already failed on this exact task?
                          YES → Override with ! and try Opus
                          NO  → Start with Sonnet 4.5
```

---

## Cost Per Request (Cursor Billing Estimates)

| Model | Single Request | 3 Parallel Agents | MAX Mode Spike |
|-------|---------------|-------------------|----------------|
| Haiku 4.5 | $0.01–0.05 | $0.03–0.15 | N/A |
| Sonnet 4.5 | $0.08–0.30 | $0.24–0.90 | $2–10 |
| Sonnet 4.6 | $0.10–0.50 | $0.30–1.50 | $5–20 |
| Opus 4.0 | $1–5 | $3–15 | $35–209 |

*Cursor subsidizes by ~18x vs. raw API rates. Estimates reflect Cursor billing, not API list price.*

---

## Monthly Budget Math

- Hard limit: $310/month
- Target: <$200/month
- Wiggle room: $110 for R&D spikes

**To stay under $200:**
- Default to Sonnet 4.5, not 4.6 or Opus (saves $80–120/month vs. always using 4.6)
- Step up to 4.6 only for complex work (saves $20–40/month vs. blanket 4.6 usage)
- Minimize parallel agents (saves $50–100/month)
- Let Model Matchmaker block you (saves $20–40/month from Opus blocks)

---

## Quick Reference

```
Simple mechanical task (git, rename, format)  →  Haiku 4.5
Standard feature / debug / refactor / plan    →  Sonnet 4.5  ← DEFAULT
Complex / architecture / regression           →  Sonnet 4.6
Sonnet 4.6 fails twice on same task           →  ! override → Opus
```
