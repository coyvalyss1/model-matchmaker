# Model Matchmaker - LinkedIn & X Posts

## LinkedIn Post (Short, for feed)

I've been building with AI agents for a year and a half. Two products, thousands of hours of agent-first work. And for most of that time, I used the most expensive models for almost everything—most recently Opus 4.6.

Every git commit. Every menu reorder. Every "add this import." Opus.

After spending around $70-80 per month on Cursor, my bill suddenly jumped to $100. So I pulled my recent prompt history across several weeks of building and categorized every task.

60-70% of the work was standard implementation: building pages, writing components, debugging. Sonnet handles this identically at a fraction of the cost.

15-20% was debugging and troubleshooting. CORS issues, route config, hot reload problems. Sonnet territory, with an occasional escalation to Opus when things got deep.

The rest was git commits, file renames, import additions, formatting fixes. I was paying Opus prices for tasks that Haiku handles identically at 90% less cost.

The estimated savings: 50-70% of my AI spend, with zero quality loss.

I knew this intellectually; most of us do. The problem is that switching models feels like friction, so we default to the best one and move on. I wanted something that would make the decision for me.

So I built Model Matchmaker—a local hook for Cursor and Claude Code. Before each prompt is sent, it reads what you're asking and which model you're on, and either blocks with "switch to Haiku or Sonnet" for simple work, or "switch to Opus" for deep architecture. If you're already on the right model, it lets the prompt through instantly.

Three files. No proxy. No API calls. Runs entirely on your machine.

On a retroactive analysis of my prompts, it would have cut 50-70% of my spend while keeping the same quality. In tests on 12 real prompts it classified every one correctly after tuning.

I wrote up the full story and open-sourced the tool here:
https://github.com/coyvalyss1/model-matchmaker

Curious to hear what your own numbers look like once you run it.

#CursorAI #ClaudeCode #Anthropic #AIEngineering #DeveloperTools #BuildInPublic

---

## X Thread

**Tweet 1:**
I got tired of paying Opus prices to rename files.

So I built a local hook that classifies every prompt before it's sent and tells me which model to use.

3 files. No API calls. Works in @cursor_ai and Claude Code.

Here's what it does and how to set it up. 🧵

**Tweet 2:**
The problem: I was using Opus 4.6 for everything. Git commits. Import additions. Menu reordering. Opus.

I pulled my prompt history and categorized every task. 60-70% was standard work that Sonnet handles identically. Another chunk was git ops that Haiku handles at 90% less cost.

**Tweet 3:**
The estimated waste: 50-70% of my AI spend.

I already knew this. We all do. But switching models feels like friction, so we default to the best one and keep moving.

I wanted something that would make the decision for me.

**Tweet 4:**
Model Matchmaker is a local hook that runs before each prompt:

• Reads what you're asking + which model you're on
• Blocks if overpaying ("use Haiku for git ops")
• Blocks if underpowered ("use Opus for architecture")
• Pass-through if you're already on the right model

**Tweet 5:**
It's:
• 3 files (bash + python3 + JSON)
• No proxy, no API calls, no external services
• Fail-open (if it crashes, your editor proceeds normally)

Override anytime with `!` prefix.

**Tweet 6:**
On a retroactive analysis it would have cut 50-70% of my spend with identical quality.

12/12 test prompts from real sessions classified correctly.

The log file showing every decision is the most interesting part—you see patterns you didn't expect.

**Tweet 7:**
Open source. Two minutes to set up.

https://github.com/coyvalyss1/model-matchmaker

Curious what your breakdown looks like once you run it on your own usage.

@cursor_ai @AnthropicAI #BuildInPublic
