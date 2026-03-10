# Future Enhancements

Roadmap of capabilities beyond what's buildable with today's Cursor hook architecture.

## Layer 1: Block-and-Respond State Machine (Implemented)

The current system uses a file-based state machine for multi-step user interaction:

- Hook blocks with numbered choices when routing is ambiguous
- User re-sends with `!1`, `!2` prefix to select
- State persists via `.pending-choice.json` (single-use, deleted after read)

This works within the existing 2-second hook timeout and requires no Cursor changes.

## Layer 2: Local Sidecar Dashboard (Deferred)

A lightweight Python HTTP server on `localhost:8484` that runs alongside Cursor.

### What it provides
- Real-time savings dashboard with live cost ticker
- Interactive model preference UI (click instead of editing JSON)
- Historical cost charts and trend analysis
- Provider comparison visualizer
- Environmental impact tracker

### Architecture
- The hook reads/writes shared state files (already dashboard-ready):
  - `model-prices-cache.json` -- pricing data
  - `model-matchmaker-config.json` -- user preferences
  - `model-matchmaker.ndjson` -- event log
  - `.pending-choice.json` -- active routing decisions
- The dashboard reads these same files via filesystem watch
- No changes to Cursor or hooks required -- pure additive

### Implementation notes
- Single-file Python server using `http.server` + static HTML/JS
- File watcher (`watchdog` or polling) for live updates
- No external dependencies beyond Python stdlib for the server
- Frontend: vanilla JS with Chart.js for visualizations

## Layer 3: Structured Hook Responses (Cursor Feature Request)

Proposal to the Cursor team for richer hook response schemas.

### Current limitation
Hooks can only return `{"continue": bool, "user_message": string}`. The `user_message` is a plain text string -- no buttons, no structured choices, no rich formatting.

### Proposed extension
```json
{
  "continue": false,
  "choices": [
    {"label": "Use Haiku ($0.005)", "action": "haiku", "shortcut": "1"},
    {"label": "Use GPT-4.1-nano ($0.002)", "action": "nano", "shortcut": "2"},
    {"label": "Override", "action": "override", "shortcut": "!"}
  ],
  "user_message": "Two models fit this task. Pick one:"
}
```

### Cursor would
- Render choices as clickable buttons in the hook response UI
- On click, call the hook again with a `selected_action` field in the input JSON
- Support keyboard shortcuts (1, 2, !) for power users

### Impact
- Makes the entire hook ecosystem more interactive for all developers
- Enables richer pre-commit checks, code review gates, compliance workflows
- Eliminates the need for the block-and-respond prefix workaround

### Prior art
- `docs/cursor-feature-request-mode-metadata.md` in this repo
- Cursor forum feature requests

## Layer 4: Persistent Hook Processes (Aspirational)

Long-running hook processes that maintain state across prompts.

### Concept
- Instead of spawning a new process per hook event, Cursor connects to a persistent daemon
- Communication via local socket or stdio pipe
- The daemon maintains in-memory state: conversation history, cumulative costs, learned preferences

### What this enables
- Zero-latency responses (no process spawn overhead)
- Conversation-aware routing (knows what models were used earlier in the thread)
- Learning from overrides in real-time (adjusts recommendations mid-session)
- Streaming UI updates (progress bars, live cost calculations)

### Requirements
- Cursor would need a daemon management layer (start/stop/restart hooks)
- Health check / watchdog for crashed daemons
- Graceful fallback to spawn-per-event if daemon is unavailable
- Significant platform evolution

## Design Principle

All current state files are structured as clean JSON so any future layer can read/write them without modifying hook code. The data layer is dashboard-ready today.
