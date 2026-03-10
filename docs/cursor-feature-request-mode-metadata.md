# Feature Request: Add Mode and Model Metadata to Hook Payloads

## Summary

Add `mode` and `current_model_display_name` fields to hook payloads (especially `beforeSubmitPrompt`) to enable mode-aware tooling without UI scraping workarounds.

## Problem

Model Matchmaker is a local hook that helps users avoid overpaying for simple tasks (git commits on Opus) and underpowering complex tasks (architecture questions on Haiku). It works by classifying prompts and recommending the right model.

**Current limitation:** Cursor has different modes (Agent, Plan, Debug, Ask) with different model availability:
- **Plan mode**: Haiku is unavailable (grayed out)
- **Agent/Debug/Ask modes**: All models available

The hook receives `model` (e.g., `"claude-4.6-opus-high"`) but not:
1. Which **mode** the user is in
2. Which models are **available** in that mode

This forces workarounds:
- Manual mode logging: `~/.cursor/hooks/log-cursor-mode.sh plan`
- UI scraping via AppleScript to detect mode
- Hardcoded dropdown positions per mode for keyboard automation

## Proposed Solution

### Add to `beforeSubmitPrompt` payload:

```json
{
  "prompt": "...",
  "model": "claude-4.6-opus-high",
  "mode": "plan",  // NEW: "agent" | "plan" | "debug" | "ask"
  "model_display_name": "Opus",  // NEW: Human-readable name
  "available_models": ["opus", "sonnet"],  // NEW: Models available in current mode
  "conversation_id": "...",
  "generation_id": "..."
}
```

### Benefits

1. **Mode-aware recommendations** — Hook can say "Switch to Agent mode for Haiku" instead of "Switch to Haiku" (which fails in Plan mode)
2. **No UI scraping** — No need for AppleScript hacks to detect mode
3. **No manual logging** — Mode is known automatically
4. **Better user experience** — Recommendations are always actionable
5. **Enables auto-mode switching** — Hook could auto-switch mode when needed (with user permission)

### Use Cases

**Example 1: Haiku in Plan Mode**
```
User in Plan mode asks: "git commit these changes"
Hook sees: mode="plan", model="opus", available_models=["opus","sonnet"]
Hook recommends: "Switch to Agent mode for cheaper Haiku, or use Sonnet"
```

**Example 2: Mode-Aware Routing**
```
User in Plan mode asks architectural question
Hook sees: mode="plan" (designed for planning)
Hook says: "Plan mode is perfect for this, continue with current model"
```

**Example 3: Auto-Mode Switching**
```
User in Plan mode asks simple git commit question
Hook sees: mode="plan", optimal_model="haiku", available=false
Hook could: Auto-switch to Agent mode, then to Haiku
```

## Implementation Details

### Required Fields

All three fields are **required** for hooks to work without workarounds:

```json
{
  "mode": "plan" | "agent" | "debug" | "ask",
  "model_display_name": "Opus",
  "available_models": ["opus", "sonnet", "haiku"]
}
```

**Why all three are needed:**
1. `mode` - Context for what the user is trying to do (planning vs implementation)
2. `model_display_name` - Human-readable name for user-facing messages
3. `available_models` - Ground truth of what's selectable (can't be inferred from mode alone - availability may change independently)

Without `available_models`, hooks must hardcode assumptions about what's available in each mode, which breaks when Cursor changes model availability.

## Why This Matters

Model Matchmaker has proven demand:
- **120+ GitHub stars and 12 forks in 48 hours** (strong signal people want this)
- **50-70% more prompts within the same budget** (users ship more, build better projects)
- 3-5x speed improvement for simple tasks
- Used by teams to enforce intelligent model routing

**Cursor benefits:** Users who maximize their budget build more impressive projects, creating better word-of-mouth and showcases.

But the current implementation requires:
- 3 workaround scripts (`log-cursor-mode.sh`, `auto-switch-model.sh`, UI detection)
- Manual mode tracking by users
- Fragile keyboard automation that breaks on UI changes

Adding `mode` to hooks would make these tools **just work** without hacks.

## Related Work

- Model Matchmaker: https://github.com/coyvalyss1/model-matchmaker (MIT license)
- Auto-switch implementation: Uses keyboard automation via AppleScript
- GitHub Issue #7: Auto-mode switching investigation

**Note:** Model Matchmaker is open source (MIT). Feel free to incorporate the classification logic directly into Cursor as a native feature if that's easier than building hooks support. The repo includes all the prompt classification and model routing logic.

## Why Current Workarounds Don't Work

The core problem: **hooks can't do this work from within Cursor**. 

Current implementation requires:
1. **External terminal process** — Hooks must spawn a separate Terminal.app process to get Accessibility permissions for keyboard automation (Cursor hooks don't have these permissions)
2. **Hardcoded UI positions** — No API to query model positions, so we hardcode arrow key counts (e.g., "Sonnet is 6 down from current"). Breaks when modes change model availability.
3. **Manual mode tracking** — Users run `log-cursor-mode.sh` to tell the system what mode they're in, because hooks can't detect it

**What we need:** Hooks that can work entirely within Cursor without external terminal processes or UI automation.

Alternatives considered:
- **UI scraping via AppleScript** (current) — Requires external Terminal.app, breaks on UI changes
- **Heuristics** — Can't reliably distinguish Plan vs Agent mode
- **Manual logging** — Users forget, breaks auto-switch flow

None solve the fundamental issue: hooks need first-class access to mode and model metadata.

**Note:** Claude Code's `UserPromptSubmit` hook has the same limitation — no mode field in their payload either. **You can gain immediate competitive differentiation by shipping this first.**

## Backward Compatibility

Adding optional fields to hook payloads is backward compatible. Existing hooks ignore unknown fields.

## Request

Please add `mode` (and optionally `model_display_name` and `available_models`) to hook payloads, especially `beforeSubmitPrompt`. This would enable robust mode-aware tooling without fragile workarounds.

---

**Contact:** @coybyron (GitHub), Model Matchmaker maintainer
