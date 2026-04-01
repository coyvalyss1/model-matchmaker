# Monthly Cursor Cost Review

Run this checklist at the start of each month. Takes ~5 minutes.

---

## Step 1: Check Last Month's Bill

- [ ] Open Cursor billing page
- [ ] What was actual spend?
- [ ] How close to $310 limit?
- [ ] Any overage charges?

**Target:** <$200/month

---

## Step 2: Run Analytics

```bash
cd ~/.cursor/hooks && bash analytics.sh --days 30
```

Record the key metrics:

| Metric | Last Month | Target |
|--------|-----------|--------|
| Uncertain rate | ___% | <50% |
| Haiku compliance | ___% | >80% |
| Sonnet 4.5 compliance | ___% | >85% |
| Opus blocks | ___ | N/A (each = $3–5 saved) |
| Sonnet 4.6→4.5 step-downs | ___ | N/A (each = $0.15 saved) |

---

## Step 3: Review Parallel Agent Usage

- [ ] How many times did you spawn 3+ agents last month?
- [ ] Were they justified? (Check past prompts in agent transcripts)
- [ ] Any recurring patterns you can switch to sequential?

---

## Step 4: Tune Classifier (if needed)

Run if uncertain rate >50% or override rate >10%:

```bash
# Analyze override patterns and propose keyword updates
# (Run optimize-classifier skill)
```

---

## Step 5: Update Budget Forecast

- Based on trends, what's next month's projection?
- Any upcoming R&D work that will spike usage? (Plan for it)
- Adjust hard limit in Cursor settings if needed

---

## Historical Log

| Month | Actual Spend | Opus Blocks | Uncertain Rate | Notes |
|-------|-------------|-------------|----------------|-------|
| March 2026 | $298 | — | 62% | Baseline before optimization |
| April 2026 | | | | |
| May 2026 | | | | |
