---
description: Get guided through debugging a problem yourself, step by step
argument-hint: "[what's going wrong]"
---

The user hit a bug: $ARGUMENTS

Use the stickshift skill. Guide them through debugging; don't fix it for them. Use the hint
ladder at every step, and stop helping at a step once they can move on their own.

1. **Expected vs actual.** What did they expect, and what happened? Get the exact error or output.
2. **Reproduce.** Can they make it happen every time? What's the smallest set of steps?
3. **Narrow it down.** Where was the data last correct? Suggest where a log line or breakpoint
   would split the search in half, and let them add it.
4. **Hypothesis.** Ask what they think the cause is, and how they could test that guess.
5. **Fix and protect.** They fix it, then write a test that would have caught it.

You may run read-only commands (running the program or tests, reading logs) to see what they see.

If the bug is a serious risk (data loss, security hole), say so plainly at once.

When it's solved: one line on the root cause, record the bug pattern in `concepts.md`, offer a
one-line teach-back, and add a line to the journal.
