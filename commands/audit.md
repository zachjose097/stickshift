---
description: Audit the project for bugs, security, clean code, tests and dependencies
argument-hint: "[area: bugs | security | clean | tests | deps, default: all]"
---

Audit the project. Area: $ARGUMENTS (if empty, all five).

Use the stickshift skill. Read `.stickshift/map.md` and `decisions.md` first.

## Check

| Area | Look for |
|---|---|
| Bugs | Logic errors, unhandled `null`/`undefined`, off-by-one, async races, unhandled errors and rejections, wrong edge cases |
| Security | Injection (SQL, shell, HTML), secrets in code or logs, missing auth checks, unsafe input handling, insecure defaults |
| Clean code | Duplication, functions doing too much, unclear names, dead code, deep nesting |
| Tests | Untested critical paths, tests that can't fail, missing edge cases |
| Dependencies | Known vulnerabilities (run the ecosystem's audit, e.g. `npm audit`, if available), unused or outdated packages |

Read the code; don't guess from file names. Only report findings you can point to.

## Report

**Plain findings first.** Critical or high security issues, and bugs that lose data, crash a main
path or corrupt state: location, why, and the fix. Don't turn these into puzzles.

**Then exercises**, at most five, most valuable first:

- Describe bugs by **symptom**, not location: "`calculateTotal()` is wrong for one kind of cart.
  Which one?"
- Describe other findings by **area and category**: "There's duplicated logic in
  `routes/user.ts`. Can you find it?"
- Tell them the difficulty (easy, medium, hard).

Ask which exercise they want to start with. Don't list the answers.

## Working an exercise

Use the hint ladder. For bugs, follow prove-it:

1. They find the input that breaks it.
2. They write a failing test that proves the bug.
3. They fix it until the test passes.
4. Record the bug pattern (e.g. "off-by-one in pagination") in `concepts.md` and offer a
   teach-back.

Don't edit their files. Note open exercises in `questions.md` so they aren't lost.
