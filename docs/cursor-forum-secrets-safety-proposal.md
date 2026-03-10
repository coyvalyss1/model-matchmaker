# Follow-up: Built-in Secrets Safety Rules for Cursor

## Context

Following up on my previous post about the IDE revealing secrets through terminal output and AI context. I've built Cursor rules that prevent this, and I think these should ship out-of-the-box with Cursor.

---

## The Rules I Created

I created two levels of protection that have completely solved this issue for me:

### 1. Secrets Safety Rules (`.cursorrules`)

```markdown
## Secrets Safety

- NEVER hardcode API keys, passwords, or tokens in code
- NEVER use fallback values for secrets: `process.env.KEY || 'sk_test_...'`
- NEVER run: `cat .env`, `echo $SECRET`, `firebase functions:secrets:access`
- NEVER run secret-generating or secret-setting commands via Shell tool (output enters AI context)
- ALWAYS use environment variables or Firebase Secrets Manager
- ALWAYS add secret files to `.gitignore` BEFORE creating them
```

### 2. Public Content Security Rules (`.cursor/rules/public-content-security.mdc`)

Protects against accidentally sharing secrets when creating open-source repos, documentation, or public content. Full rules prevent:
- Infrastructure details (Firebase IDs, storage buckets, Cloud Function URLs)
- Application internals (directory structures, collection names)
- Credentials & auth details (API keys, OAuth clients, service accounts)
- Business & personal info (partner names, revenue numbers, roadmap details)

Key enforcement: When an agent runs `git init` or `git add`, it MUST check `.gitignore` first and ensure protected folders are excluded.

---

## Why This Should Be Built-In

**Current situation:**
- Users have to discover this vulnerability the hard way (by exposing secrets)
- Each user must write their own protection rules
- New users are unprotected by default

**With built-in rules:**
- Zero-day protection for new users
- Consistent security baseline across all projects
- Users can still override if they understand the risks

**Benefit to Cursor:**
- Prevents embarrassing security incidents from being associated with the product
- Establishes Cursor as security-conscious by default
- Reduces support burden from users who've exposed credentials

---

## Proposed Implementation

Ship Cursor with default safety rules that:

1. **Block dangerous commands by default:**
   - `cat .env`, `echo $API_KEY`, secret-viewing commands
   - Give users a clear error: "This command may expose secrets to AI context. Run manually if needed."

2. **Warn on risky patterns:**
   - Hardcoded secrets in code (regex patterns for API key formats)
   - Fallback values: `process.env.KEY || 'actual-secret'`
   - Git operations without `.gitignore` verification

3. **Provide an escape hatch:**
   - Users can disable with `cursor.secretsProtection: false` in settings
   - But make the secure path the default path

---

## How I'm Using This

These rules are in my global `.cursorrules` and apply to all my projects. They've caught several potential exposures:
- Agent tried to `cat .env` to check a variable name → blocked
- Agent tried to log Firebase secret to verify it loaded → blocked
- Agent created a repo and tried `git add .` before `.gitignore` was complete → blocked

**The rules work.** They should be everyone's default, not just mine.

---

## Rules Available

I've open-sourced these rules. Cursor team: feel free to incorporate them directly into the default agent system prompt or ship them as default `.cursorrules` templates.

- Secrets Safety rules: (in my `.cursorrules`)
- Public Content Security: (in `.cursor/rules/public-content-security.mdc`)

Would love to see this protection built into Cursor by default. Happy to help refine the rules or collaborate on implementation.
