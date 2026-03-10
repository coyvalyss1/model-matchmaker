This is exciting! 

Two thoughts on what AI automation needs as it scales:

1. Intelligent model routing — tooling to maximize user budget and build better products
2. Security guardrails — prevent secrets from slipping through as automation increases

WORKFLOW I'M AUTOMATING: INTELLIGENT MODEL SELECTION

I built Model Matchmaker (GitHub link in my forum profile), an open source hook that classifies prompts and routes to the right model. Users get 50-70% more prompts within the same budget by not burning Opus on git commits or using Haiku for architecture decisions for example. 

Proven demand: 120+ stars and 12 forks in 48 hours

Proof it works:
- Retroactive analysis of my own prompts: 70% were overpaying (simple tasks on Opus)
- I'm seeing 3-5x faster iteration on simple tasks (Haiku vs Opus/Sonnet)
- I'm building more within same budget → better projects → better Cursor showcases

AUTOMATIONS + INTELLIGENT MODEL ROUTING

Automations would be perfect for intelligent model selection. If a cloud agent spins up to triage bug reports overnight, it should automatically use the cheapest model that can handle the task, not default to the most expensive one.

Users who maximize their budget build more impressive projects, creating better word-of-mouth and showcases. That outcome gets even better with automations running unattended work efficiently.

BLOCKER: MODE AND MODEL METADATA

For intelligent model routing to work in automations (or hooks), we need mode and model metadata in payloads. I submitted a feature request for this (see my other forum posts). Short version: hooks currently can't see which mode the user is in or which models are available, forcing fragile workarounds.

With that metadata, automations could intelligently route: "This is a triage task, use Haiku. This is architecture, use Opus." That's the same problem Model Matchmaker solves for interactive sessions, now applied to unattended cloud agents.

INTEGRATION I'D LOVE TO SEE

Model selection as a first-class automation capability. Not just "use this model" but "use the best model that meets these criteria" (complexity score, code generation vs analysis, etc.).

The classification logic is MIT-licensed and open source. Happy to collaborate on making intelligent model routing a native Cursor capability.

CURSOR RULES FOR SECURITY (OUT OF THE BOX)

A model hallucinated during a credential rotation task and displayed a production secret in the chat UI, directly contradicting the security practices it was implementing. I caught it before damage, but this shouldn't be possible.

Bug report in my other forum posts.

WHAT I’M PROPOSING

Include secrets safety protections as default Cursor rules that:

1. Block dangerous commands (cat .env, echo $SECRET) with clear error messages

2. Warn on risky patterns (hardcoded keys, fallback values like process.env.KEY || ‘sk_test_…’)

3. Force .gitignore verification before git add to prevent accidental commits

4. Provide escape hatch: cursor.secretsProtection: false for users who need it

WHY THIS BENEFITS CURSOR

Zero-day protection for new users — prevents embarrassing security incidents before they happen

Competitive positioning — Cursor becomes known as security-conscious by default (users appreciate this, competitors don’t have it)

Prevents negative word-of-mouth — better to be proactive than reactive to “I accidentally exposed my API key to an AI”

Reduces support burden — stops the “oops I exposed secrets” support tickets

HOW I BUILT THIS

Secrets Safety Rules (in my .cursorrules):
- NEVER run: cat .env, echo $SECRET, secret-viewing commands
- NEVER run secret-generating commands via Shell tool (output enters AI context)
- NEVER hardcode secrets or use fallback values
- ALWAYS add secret files to .gitignore BEFORE creating them

Public Content Security (in .cursor/rules/public-content-security.mdc):
- Prevents accidental exposure in open-source repos, docs, READMEs
- Blocks Firebase IDs, storage buckets, Cloud Function URLs, collection names
- Forces .gitignore verification before git add

PROOF IT WORKS

These rules have caught several near-misses:
- Agent tried to cat .env to check a variable name → blocked
- Agent tried to log Firebase secret to verify it loaded → blocked
- Agent created a repo and tried git add . before .gitignore was complete → blocked

OPEN SOURCE RELEASE

I’m releasing these as part of a broader Cursor Toolkit repo (rules, skills, and workflows for production-grade AI-assisted development). The secrets safety rules are one component, alongside git workflow best practices, model selection guidance, cross-platform development patterns, and proposal writing frameworks.

Feel free to incorporate these rules into the default agent system prompt or ship as default .cursorrules templates. Happy to collaborate on adapting them for broader use!

