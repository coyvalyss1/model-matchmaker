# Stop Paying Opus Prices to Rename Files

I've been building with AI agents for a year and a half. Two products, hundreds of hours of agent-first work. And until last week, I used Opus for everything.

Every git commit. Every import addition. Every menu reorder. Opus.

So I pulled my recent prompt history and categorized every task. 60-70% was standard implementation work that Sonnet handles identically. Another chunk was git commits and file renames that Haiku handles at 90% less cost. The estimated waste: 50-70% of my AI spend.

I already knew this. Most of us do. But switching models feels like friction, so we default to the best one.

I wanted something that would make the decision for me. So I built one.

## Model Matchmaker

It's a local hook for @cursor_ai and Claude Code. Before each prompt is sent, it classifies the task and compares it to the model you're on.

On Opus asking to git commit? Blocked. "Switch to Haiku, 90% cheaper, same result."

On Sonnet asking about architecture tradeoffs? Blocked. "Switch to Opus, you need the horsepower."

On the right model? Passes through instantly. Override anytime with `!`.

Three files. No proxy. No API calls. No dependencies. Pure bash + python3. Everything local. Two minutes to set up.

## What the Data Shows

I ran a retroactive analysis on several weeks of real prompts:

- Git ops, renames, route additions on Opus → should have been Haiku (90% savings)
- Feature implementation on Opus → should have been Sonnet (75% savings)
- Architecture and deep analysis → stayed on Opus correctly
- 12/12 test prompts from real sessions classified correctly

The log file is the most interesting part. Every decision gets recorded, and reviewing it reveals patterns you don't expect. Most "build" prompts genuinely don't need Opus.

## Why Not Auto Mode?

Cursor's Auto picks from 3 models (GPT-4.1, Sonnet, Gemini Pro). No Opus, no Haiku. Can't route to the cheapest or most powerful. Tests show it mostly picks Sonnet regardless.

Model Matchmaker is complementary. It works on top of your selected model, nudging both directions.

## Why Not a Proxy?

91,000+ attack sessions targeting LLM proxy endpoints detected Oct 2025 to Jan 2026. API keys can leak via DNS exfiltration. Proxy crash = zero AI access.

This runs entirely locally. No network calls. If the script hangs, Cursor proceeds normally. You're never locked out.

## The Point

Model selection should be automatic. The prompt contains enough signal to route correctly. This hook is a proof of concept for what that looks like with full Haiku-to-Opus granularity.

The people who get the most from these tools are the ones who build the infrastructure around them.

Open source. Two minutes. Three files.

https://github.com/coyvalyss1/model-matchmaker

@cursor_ai @AnthropicAI #BuildInPublic #AIEngineering
