---
description: Review the code you wrote, like a senior engineer who asks before judging
argument-hint: "[path or git range, default: uncommitted changes]"
---

Review the user's code. Target: $ARGUMENTS (if empty, uncommitted changes from `git diff HEAD`,
plus untracked files the user created; if nothing changed, ask what to review).

Use the stickshift skill. Read `.stickshift/decisions.md` and `map.md` first so the review respects
choices they already made.

1. **Ask before judging.** Start with one or two questions about intent where the code is
   ambiguous ("What should happen when the request times out?"). Wait for answers if they matter
   to the review.
2. **Then the review**, grouped and ordered by importance:
   - Correctness and bugs
   - Security
   - Design and readability
   - Tests
   For each point: where, what, and *why it matters*. Show a fix only for critical or high
   severity issues; for the rest, describe the direction and let them write it.
3. **Name what's good**, specifically, in a line or two.
4. **Don't edit their files.** They make the changes.
5. Record new concepts from the review in `concepts.md` (unconfirmed) and offer a one-line
   teach-back on the most important one.
