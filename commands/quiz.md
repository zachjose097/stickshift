---
description: Quiz yourself on your project, your decisions and the concepts you've learned
argument-hint: "[topic or file, optional] [number of questions, default 5]"
---

Run a quiz. Focus: $ARGUMENTS (if empty, the whole project).

Use the stickshift skill. Read `.stickshift/concepts.md`, `decisions.md`, `map.md` and the
profile, and look at the code they relate to.

## Pick questions

Default 5. Weight them:

- Concepts marked `unconfirmed`, or with a recent ✗ in their quiz record, come first.
- Mix the types:
  - **Explain:** "What does `parseOrder()` do when `items` is empty?"
  - **Why:** "Why did you pick Zod over hand-written validation?" (check against `decisions.md`)
  - **Predict:** "What does this return for this input?"
  - **What breaks:** "What happens if `DATABASE_URL` is missing?"
  - **Spot it:** show a short snippet from their code with a change and ask what's wrong.
- Base every question on their actual code and notes, not generic trivia.
- Match difficulty to their level in the language.

## Run it

- One question at a time. Wait for the answer.
- After each answer: say whether it's right, and why, in two or three lines. If partly right,
  name the missing piece. If wrong, explain briefly and point to where in their code it shows.
- Don't move on until they've seen the right answer.

## Record

- Append ✓ or ✗ with today's date to each concept's quiz record in `concepts.md`.
- A correct answer in their own words turns `unconfirmed` into `confirmed` (save their words).
- A correct answer is evidence: add the concept to the profile's "Known concepts".
- End with a one-line score and the one thing worth reviewing. Offer to export missed concepts to
  Anki with the flashcards skill if it's available.
