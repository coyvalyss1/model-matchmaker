# Feature Request: Add Mode and Model Metadata to Hook Payloads

**Category:** Hooks API Enhancement  
**Use Case:** Mode-aware tooling (Model Matchmaker, cost optimization, workflow automation)

## Summary

Add `mode` and `model_display_name` fields to hook payloads (especially `beforeSubmitPrompt`) to enable mode-aware recommendations without UI scraping workarounds.

---

## The Problem

I built [Model Matchmaker](https://github.com/coyvalyss1/model-matchmaker), an open source hook that helps users build more within their budget by avoiding overpaying for simple tasks (git commits on Opus) and underpowering complex work (architecture on Haiku). It classifies prompts and recommends the right model.

**Current blocker:** Cursor modes (Agent/Plan/Debug/Ask) have different model availability:
- Plan mode: Haiku unavailable (grayed out)
- Other modes: All models available

The hook receives `model: "claude-4.6-opus-high"` but NOT:
- Which **mode** the user is in
- Which models are **available** in that mode

This forces workarounds:
- ❌ Manual mode logging (`~/.cursor/hooks/log-cursor-mode.sh plan`)
- ❌ UI scraping via AppleScript to detect mode
- ❌ Hardcoded dropdown positions per mode

---

## Proposed Solution

Add to `beforeSubmitPrompt` payload:

```json
{
  "prompt": "git commit these changes",
  "model": "claude-4.6-opus-high",
  "mode": "plan",  // NEW: "agent" | "plan" | "debug" | "ask"
  "model_display_name": "Opus",  // NEW: Human-readable name
  "available_models": ["opus", "sonnet"],  // NEW: What's selectable
  "conversation_id": "...",
  "generation_id": "..."
}
```

---

## Why This Benefits Cursor

**Immediate competitive differentiation:** Claude Code's `UserPromptSubmit` hook has the same limitation (no mode field). Ship this first and claim superior hooks API as a differentiator.

**User outcomes translate to better marketing:**
- Users get **50-70% more prompts within their budget** → ship more impressive projects
- More impressive projects → better word-of-mouth and showcases for Cursor
- Faster iteration (3-5x for simple tasks) → higher user satisfaction

**Proven demand:**
- Model Matchmaker: **120+ GitHub stars, 12 forks in 48 hours** (strong signal)
- Used by teams for intelligent model routing
- Currently requires fragile workarounds; native support makes it seamless

---

## How It Works

**With mode metadata, hooks can:**
1. Give actionable recommendations ("Switch to Agent mode for Haiku" vs "Switch to Haiku" which fails in Plan)
2. Auto-switch modes when appropriate (e.g., Plan→Agent for simple tasks)
3. Adapt routing logic per mode (Plan is designed for planning, so architectural questions should stay)

**Example:**
```
User in Plan mode: "git commit these changes"
Hook sees: mode="plan", model="opus", haiku not available
Hook recommends: "Switch to Agent mode for Haiku (90% cheaper)"
OR auto-switches if enabled: Plan→Agent, Opus→Haiku
```

---

## Minimal Implementation

These fields are all **required** for hooks to work properly:

```json
{
  "mode": "plan" | "agent" | "debug" | "ask",
  "model_display_name": "Opus",  // Human-readable name
  "available_models": ["opus", "sonnet"]  // What's actually selectable
}
```

**Why all three are needed:**
- `mode` alone isn't enough - model availability can change independently
- `model_display_name` enables user-facing messages ("Switch to Sonnet" not "Switch to claude-sonnet-4")
- `available_models` tells hooks what's actually selectable (no guessing, no hardcoded logic)

**Note:** Model Matchmaker is MIT-licensed open source. Feel free to incorporate the classification logic directly into Cursor as a native feature. The repo includes the prompt classifier and model routing logic.

---

## Backward Compatibility

✅ Adding optional fields to hook payloads is backward compatible. Existing hooks ignore unknown fields.

---

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

---

## Related

- Auto-mode switching investigation: https://github.com/coyvalyss1/model-matchmaker/issues/7

Would love to see this in the hooks API! Happy to provide more details or help with implementation if useful.
