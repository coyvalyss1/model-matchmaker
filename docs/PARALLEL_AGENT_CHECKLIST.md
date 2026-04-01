# Parallel Agent Pre-Spawn Checklist

Run through this before making 3+ Task tool calls in a single response.

Each parallel agent is billed separately and carries the full conversation context. 3 parallel Sonnet 4.6 agents = 3x Sonnet 4.6 billing. 3 parallel Opus agents in MAX mode = $105–$627.

---

## The 3 Questions (all must be YES to justify parallel)

**1. Truly independent?**
Can you describe Agent B's task without knowing Agent A's output?
- YES → continue
- NO → run sequentially

**2. Time savings justify cost?**
Would running sequentially block you for >30 minutes on time-sensitive work?
- YES → continue
- NO → run sequentially

**3. Non-overlapping files?**
Will these agents write to different files with no risk of conflict?
- YES → parallel is justified
- NO → run sequentially

---

## Patterns Worth Parallelizing

These are genuinely independent and benefit from parallel execution:

- Backend investigation + iOS investigation + web investigation (3 separate repos)
- Pricing research + technical docs + competitive analysis (no dependencies between angles)
- Unit test generation for 3 unrelated modules
- README + LICENSE + example code for an open-source release (no shared state)

---

## Patterns That Look Parallel But Aren't

These feel like parallel work but have hidden dependencies:

| Pattern | Why It's Sequential |
|---------|-------------------|
| "Explore backend" + "Explore frontend" | Agent 2 often needs Agent 1's API schema |
| "Debug issue X" split across agents | Debugging benefits from sequential context building |
| "Search for all uses of X" in a monorepo | Sequential grep is instantaneous — parallel adds cost, no time savings |
| "Look at files A, B, C" | File reads are cheap; just read them sequentially |
| Any refactor touching shared files | Agents will conflict on the same file |

---

## Cost Estimation Before Spawning

Fill this in before making parallel tool calls:

```
Number of agents: ___
Model: Haiku / Sonnet 4.5 / Sonnet 4.6 / Opus
Estimated cost per agent: $___
Total parallel cost: $___
Sequential cost would be: $___
Time saved by parallel: ___ minutes
```

If "time saved" is <10 minutes, always run sequentially.

---

## Required Statement Before Parallel Tool Calls

Write this in your response before spawning:

> "Running parallel because: [reason]. Independence verified: [yes — they are in separate repos / separate research angles / etc.]."

If you cannot confidently fill in those blanks, switch to sequential.

---

## Quick Decision

```
How much longer would sequential take?

< 10 min   →  Always sequential
10–30 min  →  Sequential unless blocking something else
> 30 min   →  Parallel justified (if truly independent)
```
