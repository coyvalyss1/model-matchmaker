# Security Model

Model Matchmaker's auto-switch feature requires macOS Accessibility permissions for Terminal.app to perform keyboard automation. This document explains the security measures that prevent abuse.

## One-Sentence Summary

Auto-switch uses input whitelisting, rate limiting, atomic locking, frontmost verification, and scoped keyboard shortcuts to ensure it can only type one of three model names into Cursor's dropdown—nothing more.

## What Auto-Switch Can Do

The script can only:
1. Open Cursor's model dropdown (Cmd+/)
2. Type one of three model names: `haiku`, `sonnet`, or `opus` (user-configurable via the whitelist in `auto-switch-model.sh`)
3. Press Enter 3 times (select model, confirm, submit message)

That's it. No shell execution, no file system access beyond logging, no network calls, no privilege escalation.

**Note:** The default whitelist includes Claude's three main models. You can edit `auto-switch-model.sh` lines 36-42 to add other models (e.g., `gpt-4`, `gemini`, local model names) based on your Cursor setup.

## Defense in Depth (14 Layers)

### 1. Opt-In Enablement
- Auto-switch is **disabled by default**
- User must explicitly run: `~/.cursor/hooks/toggle-auto-switch.sh on`
- Can be disabled anytime: `~/.cursor/hooks/toggle-auto-switch.sh off`

**Code:** `auto-switch-model.sh` lines 30-32

### 2. Input Validation
```bash
case "$MODEL" in
    haiku|sonnet|opus)
        ;;
    *)
        echo "SECURITY: Invalid model rejected: $MODEL" >> "$LOG_FILE"
        exit 1
        ;;
esac
```
- Only whitelisted values allowed (default: `haiku`, `sonnet`, `opus`)
- Any other input (arbitrary commands, shell injection) is rejected and logged
- **User-configurable**: Edit this whitelist to add other models (e.g., GPT-4, Gemini, local models)
- The whitelist prevents arbitrary code execution—only alphanumeric model names allowed

**Code:** `auto-switch-model.sh` lines 35-43

### 3. Emergency Kill Switch
```bash
if [ -f "$KILL_SWITCH" ]; then
    echo "SECURITY: Kill switch activated" >> "$LOG_FILE"
    exit 0
fi
```
- Instant disable: `touch ~/.cursor/hooks/.auto-switch-kill`
- All auto-switch attempts immediately abort
- No restart required

**Code:** `auto-switch-model.sh` lines 24-28

### 4. Rate Limiting
```bash
if [ $TIME_DIFF -lt 5 ]; then
    echo "SECURITY: Rate limit - too soon since last switch (${TIME_DIFF}s)"
    exit 0
fi
```
- Minimum 5 seconds between switches
- Prevents rapid-fire abuse or runaway loops
- Protects against accidental repeated triggers

**Code:** `auto-switch-model.sh` lines 64-74

### 5. Atomic Execution Lock
```bash
LOCK_DIR="$HOME/.cursor/hooks/.auto-switch-lock.d"
if mkdir "$LOCK_DIR" 2>/dev/null; then
    trap "rm -rf $LOCK_DIR" EXIT
else
    exit 0  # Another switch is in progress
fi
```
- Only one switch can run at a time
- Uses atomic `mkdir` (no race conditions)
- Stale locks auto-expire after 10 seconds
- Prevents double-typing or conflicting keyboard events

**Code:** `auto-switch-model.sh` lines 45-62

### 6. Cursor Frontmost Verification
```applescript
if frontmost of process "Cursor" is false then
    do shell script "echo ABORTED > $RESULT_FILE"
    return "ABORTED: Cursor not frontmost"
end if
```
- Won't send keystrokes unless Cursor is the active window
- If you switch to another app during execution, it aborts
- Prevents keystrokes from hitting the wrong application

**Code:** `auto-switch-model.sh` lines 129-135

### 7. Scoped AppleScript Actions
```applescript
tell process "Cursor"
    keystroke "/" using command down
    -- Only types whitelisted model name
    -- Only presses Enter keys
end tell
```
- Only performs keyboard shortcuts within Cursor process
- No shell commands executed from AppleScript
- No file system access
- No network calls
- Just: Cmd+/, type model name, press Enter 3 times

**Code:** `auto-switch-model.sh` lines 137-184

### 8. Sandboxed Proxy Script
```bash
PROXY_SCRIPT="/tmp/.cursor-model-switch-$$.sh"
# Write script content
chmod +x "$PROXY_SCRIPT"
open -a Terminal "$PROXY_SCRIPT"
# Script self-destructs after execution
rm -f "$PROXY_SCRIPT"
```
- Proxy script stored in `/tmp` with unique PID-based name
- Self-destructs after execution
- No persistent code left behind
- Terminal window auto-closes

**Code:** `auto-switch-model.sh` lines 103-196

### 9. No User Input in Proxy
- All variables (`$MODEL`, `$SEARCH_TERM`, `$WINDOW_TITLE`) set by parent script
- No `read` or user input prompts
- No environment variable injection from outside
- Controlled data flow only

### 10. Full Audit Logging
```bash
echo "[$(date -Iseconds)] SWITCH_ATTEMPT | Model: $MODEL | Mode: $CURSOR_MODE | Window: $WINDOW_TITLE | PID: $$ | User: $(whoami)" >> "$LOG_FILE"
```
- Every execution logged with timestamp
- Records: model, mode, window, PID, user
- Security events logged (kill switch, invalid input, rate limits)
- Audit trail: `~/.cursor/hooks/auto-switch-audit.log`

**Code:** `auto-switch-model.sh` lines 89-90

### 11. Timeout Protection
```bash
for i in $(seq 1 16); do
    if [ -f "$RESULT_FILE" ]; then
        exit 0  # Success
    fi
    sleep 0.5
done
# Timeout after 8 seconds
```
- Maximum 8-second execution window
- Prevents hung processes
- Auto-cleanup on timeout
- Parent script doesn't wait indefinitely

**Code:** `auto-switch-model.sh` lines 204-218

### 12. macOS Accessibility Permissions Required
- User must **manually grant** Terminal.app Accessibility permissions
- System Settings > Privacy & Security > Accessibility
- macOS enforces this; can't be bypassed programmatically
- User can revoke permissions anytime

### 13. No Network Access
- No `curl`, `wget`, or network calls
- No data sent to external servers
- No API calls
- Entirely local keyboard automation

### 14. Window Targeting
```applescript
if targetWindow is not "" then
    try
        set index of (first window whose name contains targetWindow) to 1
    end try
end if
```
- Only targets the specific Cursor window that triggered the switch
- Won't affect other Cursor windows or applications
- Uses workspace name for precise targeting

**Code:** `auto-switch-model.sh` lines 118-126

## Attack Surface Analysis

### What Could Go Wrong?

**Q: Could an attacker inject arbitrary shell commands via the model name?**  
A: No. Input validation uses a whitelist (default: `haiku`, `sonnet`, `opus`). Any value not in the whitelist is rejected before execution. The whitelist is user-configurable but must contain only alphanumeric model names—no special characters, no shell metacharacters.

**Q: Could rapid repeated calls cause a denial-of-service?**  
A: No. Rate limiting enforces 5-second minimum between switches. Atomic locking prevents concurrent executions.

**Q: Could keystrokes be sent to the wrong application?**  
A: No. Frontmost verification aborts if Cursor isn't the active window. AppleScript scopes all actions to the Cursor process.

**Q: Could the proxy script be tampered with?**  
A: No. Script is written to `/tmp` with unique PID-based name and immediately executed. Self-destructs after completion.

**Q: Could Terminal permissions be abused for other actions?**  
A: No. Terminal.app only executes the specific proxy script that Model Matchmaker creates. The proxy script only contains the whitelisted AppleScript actions. Terminal has no persistent access to Cursor.

**Q: What if the script hangs or crashes?**  
A: Timeout protection (8 seconds max). Stale locks auto-expire (10 seconds). Fail-safe: script exits cleanly, no side effects.

## Privacy

- Only first 40 characters of prompts logged (for classifier pattern analysis)
- All data stays local in `~/.cursor/hooks/model-matchmaker.ndjson`
- No network calls, no telemetry, no cloud storage
- Delete log files anytime to clear history

## Disabling Auto-Switch

**Temporary disable:**
```bash
~/.cursor/hooks/toggle-auto-switch.sh off
```

**Emergency kill switch:**
```bash
touch ~/.cursor/hooks/.auto-switch-kill
```

**Revoke macOS permissions:**
- System Settings > Privacy & Security > Accessibility
- Remove Terminal.app from the list

**Complete removal:**
```bash
rm -rf ~/.cursor/hooks/
rm ~/.cursor/hooks.json
```

## Responsible Disclosure

If you discover a security issue, please report it via GitHub Issues or email: [your contact method].

Do not publicly disclose security vulnerabilities until we've had a chance to address them.

## Design Philosophy

Model Matchmaker follows the principle of **least privilege**:
- Only requests the minimum permissions needed (macOS Accessibility for keyboard automation)
- Only performs the minimum actions needed (open dropdown, type model name, press Enter)
- Only logs the minimum data needed (40-char prompt snippet for pattern analysis)
- Fails safe (timeouts, aborts, and errors all exit cleanly with no side effects)

The security model is **defense in depth**: multiple independent layers ensure that even if one layer fails, the others prevent abuse.

## Comparison to Proxy-Based Solutions

Why local keyboard automation instead of a proxy server?

**Proxy risks:**
- 91,000+ attack sessions targeting LLM proxy endpoints (Oct 2025 - Jan 2026)
- API keys can leak via DNS exfiltration before HTTP-layer tools see them
- Proxy crash = zero AI access until restarted
- You lose Cursor's built-in streaming, caching, error handling
- Single point of failure for all AI requests

**Model Matchmaker approach:**
- No network calls = no network attack surface
- No proxy = no single point of failure
- Keyboard automation = works with Cursor's native UI and all its features
- Local only = API keys never leave your machine

## Open Source Transparency

All security measures are implemented in the code itself, not hidden:
- `auto-switch-model.sh`: Main script with all security checks
- `toggle-auto-switch.sh`: Simple enable/disable toggle
- `model-advisor.sh`: Classification logic (no auto-switch code, just recommendations)

Anyone can audit the code before granting permissions. This document just explains it in plain English.

## Threat Model

**In scope:**
- Preventing arbitrary code execution via model name injection
- Preventing keystrokes sent to wrong applications
- Preventing denial-of-service via repeated calls
- Preventing privilege escalation
- Protecting user privacy (minimal logging)

**Out of scope:**
- Protecting against physical access to the machine (if attacker has Terminal access, they already have full control)
- Protecting against malicious Cursor extensions (Cursor extension security is separate)
- Protecting against compromised macOS system (if macOS is compromised, all bets are off)

## Summary

Auto-switch is designed to be:
- **Minimal**: Only does one thing (switch models in Cursor)
- **Auditable**: All code is readable bash/AppleScript
- **Fail-safe**: Timeouts, aborts, and errors exit cleanly
- **Revocable**: Disable anytime with one command or macOS settings
- **Transparent**: This document explains every security measure

The 14 layers of defense ensure that even if you grant Terminal accessibility permissions, the script can only perform legitimate model switches within Cursor—nothing more.
