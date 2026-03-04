# Model Matchmaker - Reddit Posts

**Title:**
I built a local hook that cut my AI costs by 50-70% and sped up 60% of my requests

**Body:**
I use Claude AI models in Cursor. One of my good buddies uses Claude Code. We were both facing the same issue: leaving the model set to the most expensive option and never touching it again.

I built this for Cursor, and in principle it should work the same in Claude Code (both use the same hook system). Anyone here tried this in Claude Code yet?

I pulled a few weeks of my own prompts and found:

~60–70% were standard feature work Sonnet could handle just fine

15–20% were debugging/troubleshooting

a big chunk were pure git / rename / formatting tasks that Haiku handles identically at 90% less cost

The problem is not knowledge; we all know we should switch models. The problem is friction. When you are in flow, you do not want to think about the dropdown.

So I wrote a small local hook that runs before each prompt is sent in Cursor/Claude Code. It sits next to Opus/plan; think of it as an efficient front-end filter that stops the obviously bad matches before they ever hit Opus.

The unexpected benefit: Haiku responds ~3-5x faster than Opus. When 60% of your requests route to a faster model, your entire workflow feels more responsive. Plus you save money and reduce server load.

It:
- reads the prompt + current model
- uses simple keyword rules to classify the task (git ops, feature work, architecture / deep analysis)
- blocks if I am obviously overpaying (e.g. Opus for git commit) and suggests Haiku/Sonnet
- blocks if I am underpowered (Sonnet/Haiku for architecture) and suggests Opus
- lets everything else through
- ! prefix bypasses it completely if I disagree

It is:
- 3 files (bash + python3 + JSON)
- no proxy, no API calls, no external services
- fail-open: if it hangs, Cursor/Claude Code just proceeds normally

On a retroactive analysis: ~50–70% cost savings, ~60% of requests would route to faster models (Haiku/Sonnet), zero quality loss. It got 12/12 real test prompts right after tuning.

I open-sourced it here if anyone wants to use or improve it:
https://github.com/coyvalyss1/model-matchmaker

I am mostly curious what other people's breakdown looks like once you run it on your own usage. Do you see the same "Opus for git commit" pattern, or something different?

Thanks!

---

## r/CursorAI

**Title:**
I built a local hook that cut my AI costs by 50-70% and sped up 60% of my requests

**Body:**
I have been building with AI agents for ~18 months and realized I was doing what a lot of us do: leaving the model set to the most expensive option and never touching it again.

I pulled a few weeks of my own prompts and found:
- ~60–70% were standard feature work Sonnet could handle just fine
- 15–20% were debugging/troubleshooting
- a big chunk were pure git / rename / formatting tasks that Haiku handles identically at 90% less cost

The problem is not knowledge; we all know we should switch models. The problem is friction. When you are in flow, you do not want to think about the dropdown.

So I wrote a small local hook that runs before each prompt is sent in Cursor. Think of it like this: Cursor's Auto mode picks the best model from a pre-selected server-side set. This runs client-side BEFORE the API call and makes sure you are not wildly overpaying for trivial tasks (git commits, formatting, etc.).

The difference: Auto mode still costs you API credits. This blocks the request entirely if you are about to use Opus for a git commit, saving actual money.

The unexpected benefit: Haiku responds ~3-5x faster than Opus. When 60% of your requests route to a faster model, your entire workflow feels snappier.

It:
- reads the prompt + current model
- uses simple keyword rules to classify the task (git ops, feature work, architecture / deep analysis)
- blocks if I am obviously overpaying (e.g. Opus for git commit) and suggests Haiku/Sonnet
- blocks if I am underpowered (Sonnet/Haiku for architecture) and suggests Opus
- lets everything else through
- ! prefix bypasses it completely if I disagree

It is:
- 3 files (bash + python3 + JSON)
- no proxy, no API calls, no external services
- fail-open: if it hangs, Cursor just proceeds normally

On a retroactive analysis: ~50–70% cost savings, ~60% of requests would route to faster models (Haiku/Sonnet), zero quality loss. It got 12/12 real test prompts right after tuning.

I open-sourced it here if anyone wants to use or improve it:
https://github.com/coyvalyss1/model-matchmaker

I am mostly curious what other people's breakdown looks like once you run it on your own usage. Do you see the same "Opus for git commit" pattern, or something different?

---

## r/coding (LINK POST ONLY - no body text allowed)

**Title:**
I built a local hook that cut my AI costs by 50-70% and sped up 60% of my requests

**Link URL:**
https://github.com/coyvalyss1/model-matchmaker

(r/coding only allows link posts. Your GitHub README will do the talking. Make sure your README has a strong opening that explains the problem and value proposition in the first 2-3 lines.)

