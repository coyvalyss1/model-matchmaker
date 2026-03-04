# I Built a Model Matchmaker for Cursor and Claude Code. It Cuts AI Spend by 50-70%.

I've been building with AI agents for a year and a half now. Two products, hundreds of hours of agent-first development. And for most of that time, I used Opus for everything.

Every git commit. Every menu reorder. Every "add this import." Opus.

A few days ago I decided to look at what I'd actually been asking these models to do. I pulled my recent prompt history across several weeks of building and categorized every task. Here's what I found:

60-70% of my work was standard feature implementation. Building pages, writing components, debugging. Sonnet handles this identically to Opus at a fraction of the cost.

15-20% was debugging and troubleshooting. CORS issues, route config, hot reload problems. Sonnet territory, with an occasional escalation to Opus when something got deep.

And then there were the git commits, file renames, import additions, and formatting fixes. I was paying Opus prices for tasks that Haiku handles identically at 90% less cost.

The estimated savings? 50-70% of my AI spend, with zero quality loss.

Here's the thing: I already knew this intellectually. Most of us do. We know we don't need the most expensive model to commit code. But switching models feels like friction. It breaks flow. So we default to the best one and move on.

I wanted something that would make the decision for me.

## What I Built

Model Matchmaker is a local hook for Cursor and Claude Code. Before each prompt is sent, it reads what you're asking and which model you're on, then makes a call:

If you're on Opus asking to git commit, it blocks. "Switch to Haiku. Same result, 90% cheaper."

If you're on Sonnet asking about architecture tradeoffs, it blocks. "Switch to Opus. You need the horsepower."

If you're on the right model, it passes through instantly.

Three files. No dependencies. No proxy. No API calls. Everything runs locally on your machine. Setup takes two minutes.

## How It Works

Two layers work together:

**Layer 1** runs at session start and injects model-awareness context into the conversation. This makes the AI itself aware of model tradeoffs and able to suggest switches in its responses.

**Layer 2** runs before every prompt. It classifies the task using keyword matching (pure bash + python3, no LLM calls) and compares it to the model you've selected. If there's a mismatch, it blocks with a recommendation. If the match is right, it passes through.

The classifier is conservative. It only blocks when confidence is high. A false allow (wasting some money) is always better than a false block (interrupting your flow with a wrong recommendation).

And if you ever disagree, prefix your prompt with `!` to bypass entirely.

## The Results

I tested the classifier against 12 real prompts from my recent sessions. Tasks like "commit all changes and push," "build a meeting transcription page," "evaluate the tradeoffs between proxy vs. hook architecture," and "let's re-order the admin tools." All 12 classified correctly after tuning.

Looking at the full retroactive analysis of my recent work:

- Git operations, menu reordering, route additions that were on Opus could have been on Haiku (90% savings)
- Feature implementation like building new pages and components could have been on Sonnet (75% savings)  
- Architecture decisions and deep analysis stayed on Opus correctly
- Overall estimated savings: 50-70% with identical quality

The log file has been the most interesting part. Every decision is recorded (timestamp, model, recommendation, action, and 20 characters of the prompt). Reviewing it shows patterns I didn't expect; most "build" prompts genuinely don't need Opus.

## Why Not Just Use Cursor's Auto Mode?

Cursor's Auto mode picks from a curated shortlist (GPT-4.1, Claude 4 Sonnet, Gemini 2.5 Pro). It doesn't include Opus or Haiku, so it can't route to the cheapest or most powerful option. Independent testing shows it mostly routes to Sonnet regardless of task complexity, and it optimizes for Cursor's infrastructure costs, not necessarily output quality.

Model Matchmaker is complementary. It works on top of whatever model you've selected, nudging in both directions.

## Why Not a Proxy?

Proxy-based routing introduces real attack surface. Over 91,000 attack sessions targeting LLM proxy endpoints were detected between October 2025 and January 2026. API keys can leak via DNS exfiltration before HTTP-layer tools even see them. And a proxy crash means zero AI access.

Model Matchmaker runs entirely locally. No network calls. No attack surface. If the script hangs, Cursor proceeds normally (fail-open). You're never locked out.

## The Bigger Idea

Here's what I keep thinking about: model selection should be automatic. Not a dropdown. Not a guess. The prompt itself contains enough signal to route correctly.

Cursor's Auto mode is a step in this direction. This hook is a local proof of concept for what that could look like with more granularity, routing across the full spectrum from Haiku to Opus based on what the task actually needs.

The people who get the most out of these tools aren't the ones who use the biggest model for everything. They're the ones who build the infrastructure around the tools so that the tools work better.

Model Matchmaker is open source and takes two minutes to set up:
https://github.com/coyvalyss1/model-matchmaker

---

#CursorAI #ClaudeCode #Anthropic #AIEngineering #DeveloperTools #BuildInPublic
