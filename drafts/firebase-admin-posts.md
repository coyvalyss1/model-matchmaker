# Firebase Admin Scripts - All Platform Posts

## GitHub README (Key Sections)

### Tagline
"Firebase admin scripts we use to keep Firestore clean and users synced. Free, open source, battle-tested on DoMoreWorld and Valyss."

### What's Included
- **Sync Apple Auth to Firestore**: Backfill `users` collection from Firebase Auth when Apple Sign-In users don't trigger onCreate
- **Cleanup orphaned data**: Remove chat messages / user data for deleted accounts
- **Export Firestore to JSON**: Backup entire collections with filtering
- **Bulk update fields**: Add/remove fields across collection (e.g., add `persona` field to all users)
- **Usage analytics**: Query patterns, count users by field, find empty collections
- **Test data seeding**: Generate realistic test users / data for staging

### When to Use
You're on Firebase and you need to:
- Fix data inconsistencies that the client can't handle
- Do bulk operations across thousands of docs
- Debug production issues without touching client code
- Seed staging/test environments

---

## Reddit Post (Universal)

**Title:**
Firebase admin scripts I wish I had when I started

**Body:**
I have been building on Firebase for 18 months (two products: DoMoreWorld and Valyss). Over time I hit the same admin/maintenance tasks over and over:

Sync Apple Sign-In users to Firestore when they don't trigger onCreate (Apple auth quirk)

Cleanup orphaned chat messages when a user deletes their account (Firestore doesn't cascade)

Backfill new fields across thousands of existing docs (e.g., add `persona` field to all users)

Export collections to JSON for backup or migration

Debug why certain users are missing data (usage analytics on Firestore)

Every time I would rewrite the script slightly differently, introduce bugs, waste time.

So I made a collection of the scripts we actually use in production. Drop-in Node.js, runs with Firebase Admin SDK. No framework, no extra dependencies.

**What's included:**

- Sync Apple Auth to Firestore (backfill users collection)
- Cleanup orphaned data (remove messages for deleted accounts)
- Export Firestore to JSON (backup with filtering)
- Bulk update fields (add/remove fields across collection)
- Usage analytics (query patterns, count users by field)
- Test data seeding (generate realistic test users)

I open-sourced it here:
[GitHub link]

What Firebase admin tasks do you find yourself rewriting over and over? Curious what other people need.

---

## LinkedIn Post

Firebase is great until you need to do bulk operations across thousands of docs.

Then you're writing Node.js scripts with the Admin SDK, hoping you don't accidentally delete production data.

I have been building on Firebase for 18 months. Two products, hundreds of thousands of Firestore operations. I kept rewriting the same admin scripts:

Sync Apple Sign-In users to Firestore when they skip onCreate

Cleanup orphaned data when users delete accounts

Backfill new fields across existing docs

Export collections for backup

Debug missing data with usage analytics

So I collected the scripts we actually use in production and open-sourced them.

Drop-in Node.js. Runs with Firebase Admin SDK. Battle-tested on DoMoreWorld and Valyss.

If you're on Firebase and you need admin/maintenance scripts:
[GitHub link]

What Firebase tasks do you find yourself rewriting? I'm curious what people need.

#Firebase #Firestore #DeveloperTools #BuildInPublic

---

## X Thread

**Tweet 1:**
Firebase is great until you need to bulk-update 10,000 docs.

Then you're writing Node.js scripts with the Admin SDK, praying you don't nuke prod.

Here are the admin scripts we use on DoMoreWorld and Valyss. Open source. 🧵

**Tweet 2:**
Sync Apple Auth to Firestore.

Apple Sign-In sometimes skips onCreate. Users authenticate but don't appear in your `users` collection. This script backfills them.

**Tweet 3:**
Cleanup orphaned data.

User deletes their account. Their chat messages stay in Firestore. (Firestore doesn't cascade.) This script removes them.

**Tweet 4:**
Bulk update fields.

You add a new `persona` field. Now you need to backfill 10k existing users. This script does it safely with batching.

**Tweet 5:**
Export Firestore to JSON.

Backup entire collections. Filter by field. Run locally. No external tools.

**Tweet 6:**
Usage analytics.

Count users by field. Find empty collections. Debug missing data. Query patterns you can't see in the Firebase console.

**Tweet 7:**
Test data seeding.

Generate realistic test users for staging. Bulk-create chats, messages, sessions.

**Tweet 8:**
All scripts are:
• Drop-in Node.js
• Firebase Admin SDK (no extra dependencies)
• Battle-tested on production

Open source:
[GitHub link]

What Firebase admin tasks do you rewrite over and over?

#Firebase #Firestore #BuildInPublic
