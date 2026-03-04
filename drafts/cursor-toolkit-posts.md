# Cursor Toolkit - All Platform Posts

## GitHub README (Key Sections)

### Tagline
"The power user setup we use to build AI products with Cursor. Free, open source, built by Valyss."

### What's Included
- Git workflow rules (commit safety, structural change guardrails)
- Model selection guide (when to use Haiku/Sonnet/Opus/Gemini)
- Cursor meta-skills (create-rule, create-skill, update-settings, create-subagent, migrate-to-skills)
- Firebase/Gemini/Firestore patterns (common gotchas solved)
- Safe keybindings (disable destructive shortcuts)
- Debug utilities (infinite loop detector for React)
- Documentation workflow template (SESSION_LOG vs docs)

### Setup
[Detailed installation instructions]

---

## Reddit Post (Universal)

**Title:**
The Cursor power user setup I wish I had 18 months ago

**Body:**
I have been building two AI products (DoMoreWorld and Valyss) with Cursor for the past 18 months. Along the way I built up a collection of rules, skills, and utilities that made me way more productive.

Last week I open-sourced the model routing hook (Model Matchmaker). A bunch of people asked "what else is in your setup?" So here's the rest of it.

**What's included:**

Git workflow rules that stop me from accumulating 500+ uncommitted lines across 10 files (this used to happen constantly and would break my flow when I finally tried to commit)

Model selection guide that reminds me when to use Haiku/Sonnet/Opus/Gemini (complements the auto-routing hook)

Cursor meta-skills that teach Cursor how to create new rules and skills for itself (very meta, surprisingly useful)

Firebase/Gemini/Firestore patterns I learned the hard way (snake_case vs camelCase gotchas, common security rules mistakes, API quirks)

Safe keybindings that disable Cmd+Shift+Delete so I stop accidentally deleting browsing data mid-session

Debug utilities like an infinite loop detector for React useEffect (patches useEffect to warn when you're about to lock up the browser)

Documentation workflow template for when to use SESSION_LOG vs proper docs

It is:
- Drop-in files you copy to ~/.cursor/
- No build step, no dependencies
- Designed for agent-first development workflows

I open-sourced it here:
[GitHub link]

What's in your Cursor setup that you couldn't live without? Curious what other power users have in their configs.

---

## LinkedIn Post

Model Matchmaker was one piece of our Cursor setup. Here's the full toolkit.

I have been building with Cursor for 18 months. Two products, thousands of hours of agent-first work. Along the way I built up a collection of rules, skills, and utilities that saved me from repeating the same mistakes.

Last week I open-sourced the model routing hook. A lot of people asked "what else is in your setup?"

So here's the rest:

Git workflow rules that stop me from accumulating 500+ uncommitted lines (this used to break my flow constantly when I finally tried to commit)

Model selection guide that reminds me when each model tier makes sense

Cursor meta-skills that teach Cursor how to extend itself (create-rule, create-skill, etc.)

Firebase/Gemini/Firestore patterns I learned the hard way (snake_case vs camelCase, common security rules mistakes, API quirks)

Safe keybindings that disable destructive shortcuts

Debug utilities like an infinite loop detector for React

Documentation workflow for SESSION_LOG vs proper docs

Everything is drop-in. No build step. Designed for agent-first workflows.

Open source:
[GitHub link]

What's in your setup that you couldn't live without?

#CursorAI #DeveloperTools #BuildInPublic

---

## X Thread

**Tweet 1:**
Model Matchmaker was one piece. Here's the full Cursor toolkit we use to build AI products.

18 months of agent-first development, distilled into drop-in configs. 🧵

**Tweet 2:**
Git workflow rules that stop you from accumulating 500+ uncommitted lines across 10 files.

(I used to do this constantly. Would break my flow every time I finally tried to commit.)

**Tweet 3:**
Model selection guide: when to use Haiku/Sonnet/Opus/Gemini.

Works with the Model Matchmaker hook or standalone. Built from analyzing thousands of real prompts.

**Tweet 4:**
Cursor meta-skills that teach Cursor how to extend itself.

create-rule, create-skill, update-settings, create-subagent, migrate-to-skills.

Very meta. Surprisingly useful.

**Tweet 5:**
Firebase/Gemini/Firestore patterns we learned the hard way:

• snake_case vs camelCase gotchas in Gemini API
• Common Firestore security rules mistakes
• AI data update patterns (PATCH vs replace)

Save yourself the debugging time.

**Tweet 6:**
Safe keybindings: disable Cmd+Shift+Delete so you stop accidentally deleting browsing data mid-session.

(This happened to me way too many times.)

**Tweet 7:**
Debug utilities: infinite loop detector for React useEffect.

Patches useEffect to warn you before you lock up the browser.

**Tweet 8:**
All of it is:
• Drop-in files (copy to ~/.cursor/)
• No build step, no dependencies
• Designed for agent-first workflows

Open source:
[GitHub link]

What's in your setup that you couldn't live without?

@cursor_ai #BuildInPublic
