# Model Matchmaker Auto-Switch Setup

## Status: ✅ PRODUCTION READY

Auto-switch is working reliably with Terminal window auto-cleanup.

## What It Does

When Model Matchmaker detects you're using the wrong model:

1. Blocks the submission with a helpful message
2. Automatically switches to the recommended model
3. Opens the dropdown, types the model name, presses Enter 3 times (select model, confirm, submit message)
4. Terminal window flashes briefly (~1 second), then closes
5. Your message is automatically sent with the correct model

## How It Works

- Uses Cursor's built-in keyboard shortcuts: `Cmd /` to open model dropdown
- Navigates with arrow keys and Enter to select the target model
- Proxies through Terminal.app (which has macOS Accessibility permissions)
- Terminal window auto-closes after each switch completes

## Setup (Already Done!)

Auto-switch is **enabled by default**. 

**To disable:**
```bash
~/.cursor/hooks/toggle-auto-switch.sh off
```

**To re-enable:**
```bash
~/.cursor/hooks/toggle-auto-switch.sh on
```

**To check status:**
```bash
~/.cursor/hooks/toggle-auto-switch.sh status
```

## Security

- Input validation (only haiku/sonnet/opus allowed)
- Rate limiting (5 second minimum between switches)
- Execution lock (prevents concurrent switches)
- Kill switch (`touch ~/.cursor/hooks/.auto-switch-kill`)
- Audit logging (`~/.cursor/hooks/auto-switch-audit.log`)
- Cursor frontmost verification (won't send keystrokes if you switch away)

## Testing

Test manually from Terminal:
```bash
~/.cursor/hooks/auto-switch-model.sh haiku --test
```

Watch Cursor's model dropdown open, navigate to Haiku, and select it.

## Known Behavior

- Terminal window opens briefly (necessary for macOS Accessibility permissions)
- Window auto-closes ~1 second after switch completes
- Auto-switch presses Enter 3 times: select model, confirm, submit message
- Your message is automatically sent with the correct model
- Entire flow takes ~3-4 seconds from block to submission
- First time each model is switched may take up to 8 seconds (max timeout for result)

## Troubleshooting

**Model won't switch:**
- Check audit log: `tail ~/.cursor/hooks/auto-switch-audit.log`
- Verify Cursor is the frontmost window when you send
- Verify auto-switch is enabled: `~/.cursor/hooks/toggle-auto-switch.sh status`

**Typing appears in chat input instead of model selector:**
- Fixed in April 2026 — increased delay from 0.8s to 1.2s before typing
- If still happening, model selector may be slow to open on your system
- Manual workaround: open model selector, wait 2 seconds, then use arrow keys
- Report to maintainer with system specs if persistent

**Terminal window not closing:**
- Rare; osascript may have permissions issues
- Manually close the Terminal window
- Next switch should work normally

## How Model Matchmaker Works

Model Matchmaker classifies your prompts:

- **Haiku** (cheapest): git, rename, format, lint, simple mechanical tasks
- **Sonnet** (balanced): build, implement, create, fix, debug, component work
- **Opus** (most capable): architecture, analyze, tradeoffs, deep analysis, multi-system

When you're on the wrong model, it blocks and recommends the right one. Auto-switch makes the change instantly.

## Override Without Switching

Prefix any prompt with `!` to bypass the recommendation and use your current model:
```
! git status --this-is-important-keep-opus
```

This sends with your current model, no block, no auto-switch.

## Performance

- Auto-switch adds ~3-4 seconds to the submission flow
- 5-second rate limit prevents rapid repeated switches
- Audit log shows every attempt (successful or failed)
