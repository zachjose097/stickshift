# Stickshift — Design

> Vibe coding is autopilot. Stickshift puts you back in the driver's seat.

Stickshift is a plugin for Claude Code and Codex for learning while you build. You write the code
and make the decisions. The AI acts as a research partner, reviewer and tutor, and it keeps a memory
of what you learned and decided as the project grows.

Status: built, not yet tested on a real project (2026-10-23).

---

## 1. Why

AI coding tools are good at producing code and bad at producing understanding. After a few weeks of
vibe coding you have a repo you can't explain, debug or extend on your own.

Stickshift flips the roles:

| | Vibe coding | Stickshift |
|---|---|---|
| Who decides | AI | You |
| Who writes the code | AI | **You** (AI only on explicit unlock) |
| What the AI does | Everything | Researches, questions, hints, reviews, quizzes |
| Memory | None | Decisions, concepts, map, journal, learner profile |

## 2. Principles

1. **You hold the keyboard.** The AI does not edit project files unless you unlock a specific file
   for a specific request.
2. **Hint, don't hand over.** When you're stuck, the AI gives the smallest nudge that gets you moving.
3. **Your decisions, your words.** Decisions and concepts are recorded with your reasoning.
4. **Low friction or nobody uses it.** Learning steps are cheap to skip. Skipping postpones the
   learning; it doesn't erase it. The plugin never refuses to help.
5. **Real risks aren't puzzles.** Serious security problems and bugs are stated plainly, with the fix.
6. **Nothing leaks into git.** Notes and the learner profile stay on the machine.

## 3. Decisions

| # | Topic | Decision | Reason |
|---|---|---|---|
| 1 | Name | `stickshift` | Driving manual versus autopilot. Distinctive and searchable. |
| 2 | Packaging | Claude Code **plugin** (skill, commands, hooks) | A skill alone can only ask. Hooks can enforce the edit lock and reload memory. |
| 3 | Code edits | **Locked by default, unlocked per request and per file** | Keeps you writing the code, without blocking boring work (config, fixtures). |
| 4 | Learning friction | Optional one-line teach-back. Skipped notes are saved as `unconfirmed` and come back in quizzes | Learning happens without slowing you down enough to quit. |
| 5 | Language level | Asked at onboarding and on first use of a new language, then tracked per concept | Lets you start a TypeScript project knowing little TypeScript. |
| 6 | Global profile | `~/.claude/stickshift/profile.md`, outside every repo | Carries what you know across projects and can't be committed. |
| 7 | Project memory | `.stickshift/` at the repo root, excluded from git | Keeps notes per project. |
| 8 | Git | Excluded via `.git/info/exclude`, not `.gitignore` | A `.gitignore` entry would itself be committed. The exclude file stays local. |
| 9 | Quiz | `/stickshift:quiz` from your repo and notes, with spaced repetition | Checks you understand your own project. |
| 10 | Audit | `/stickshift:audit` covering bugs, security, clean code, tests and dependencies | Catches problems and turns most of them into exercises. |
| 11 | Debugging | `/stickshift:debug` walks you through the process | Builds the habit instead of handing over the fix. |
| 12 | Codex support | Same plugin, no separate build | Codex reads the `.claude-plugin/` manifests and `hooks/hooks.json`, so one codebase covers both. See 4.11. |
| 13 | Python dependency | None. Hooks are shell scripts | Fewer things to install. |

## 4. Features

### 4.1 Manual mode (the edit lock)

A `PreToolUse` hook blocks the AI's `Write`, `Edit`, `MultiEdit` and `NotebookEdit` calls on any
file outside `.stickshift/`.

**Unlocking.** You type an unlock in your own message, for example:

```
unlock src/config.ts — write the env loader
```

A `UserPromptSubmit` hook reads your message and records the unlock in
`.stickshift/.hook/unlocks`. The AI cannot write anything in `.stickshift/.hook/` (the edit hook
protects it), so only you can unlock or change modes. An unlock covers the named files or folders
for that one request and is cleared when the next prompt arrives. `unlock .` unlocks the whole
project for one request.

After unlocked code is written, the AI explains it and asks one question to check you followed it.
Every unlock is logged in the journal. If you unlock four requests in a row, the AI mentions it
once ("the last 4 changes were mine, want to take the next one?") and leaves the choice to you.

The lock only applies in projects where you ran `/stickshift:start`. Other projects are untouched.

**Known gap.** The AI could still write files through `Bash` (`sed -i`, `cat >`, `tee`). The hook
catches the common patterns. The skill instructions cover the rest. The lock is a strong guardrail,
not a security boundary.

### 4.2 The hint ladder

When you're stuck, the AI climbs one rung at a time and stops as soon as you can move on:

1. **A question back.** "What do you think happens when the list is empty?"
2. **The concept by name**, with a link to the official docs.
3. **Pseudocode** or a description of the approach.
4. **A small example in an unrelated context**, so you still have to adapt it.
5. **The actual code**, only if you ask. Logged as "given, not derived".

**Hint strictness** (set at onboarding, changeable any time) controls how readily the AI moves up:

- **Strict:** one rung per message, and only when you ask.
- **Normal:** moves up when you've clearly tried.
- **Light:** goes to the useful rung straight away.

### 4.3 Plan → Build → Review

1. **Plan.** You describe your approach first. The AI asks questions, points out gaps and offers
   alternatives. Anything it suggests that you didn't ask for is labelled as its suggestion.
   If you don't know where to start, the AI helps you break the task down: it asks what the
   feature needs to do, suggests a first small step, and points to the concepts involved. You
   still choose the approach.
2. **Build.** You write the code. The AI answers questions through the hint ladder.
3. **Review.** `/stickshift:review` reviews your changes like a senior engineer would. It asks
   questions before giving verdicts and explains the reasoning behind each comment.

### 4.4 Research mode

When you ask "which library?" or "how should I structure this?", the AI compares options with
tradeoffs and sources from official docs. It ends with *"Which do you pick, and why?"* rather than
a recommendation. Your answer goes into `decisions.md`.

Explanations use diagrams (data flow, relationships) where a picture helps.

### 4.5 Memory

**Project memory** in `.stickshift/`:

| File | Contents |
|---|---|
| `decisions.md` | Each decision with your reasoning, the alternatives you rejected, and the date |
| `concepts.md` | What you learned, in your words where possible. Each entry is `confirmed` or `unconfirmed` |
| `map.md` | Your understanding of the architecture. Quizzes draw on it |
| `questions.md` | Open questions to come back to |
| `journal.md` | Short session logs: what you did, what was hard, what's next, any unlocks |
| `.hook/` | Mode, current unlocks and the unlock log. Written only by the hooks and commands |

**Teach-back.** After you solve something, the AI asks one optional question, such as *"In one
sentence, why did narrowing the type fix that?"* If you answer, your words go into `concepts.md`
as `confirmed`. If you skip, the AI writes the note and marks it `unconfirmed`.

**Global learner profile** in `~/.claude/stickshift/profile.md`:

- Languages, with your level in each: none, basic, comfortable or strong.
- Goals and preferred explanation depth.
- Hint strictness.
- Concepts you know. A concept moves to "known" only with evidence: a correct quiz answer, or
  writing it correctly without hints. Once known, the AI stops explaining it.

It's a plain file you can read and edit.

**Reloading.** A `SessionStart` hook loads the profile and project memory when a session starts
and again after context compaction, so each session picks up where you left off.
In manual mode, the `UserPromptSubmit` hook also adds a one-line reminder to each message that
isn't an unlock, so the behaviour doesn't fade in long sessions.

### 4.6 Onboarding and language detection

`/stickshift:start` on first use:

1. Asks which languages you use and your level in each, your goals, how deep you want
   explanations, and hint strictness. About a minute.
2. Creates `.stickshift/` and adds it to `.git/info/exclude`.
3. Detects the stack (`package.json`, `tsconfig.json`, `pyproject.toml`, `Cargo.toml`, ...).

In a new project, if the profile has no level for the detected language, it asks once and adjusts.
Example: TypeScript set to "basic" means more explanation of types, narrowing and generics.

### 4.7 Quiz

`/stickshift:quiz` asks questions built from your repo and notes:

- "Explain what `parseOrder()` does when `items` is empty."
- "Why did you pick Zod over hand-written validation?" (checked against `decisions.md`)
- "What breaks if `DATABASE_URL` is missing?"
- "Predict the output of this function for this input."

Questions on concepts you got wrong, or that are still `unconfirmed`, come up more often. Correct
answers promote concepts to "known" in the profile. Concepts can be exported to the `flashcards`
skill for Anki.

### 4.8 Audit

`/stickshift:audit` checks five areas: **bugs, security, clean code, tests and dependencies**.

| Finding | How it's handled |
|---|---|
| Critical or high security issue | Stated plainly, with location and fix |
| Serious bug (data loss, crash on a main path, corrupted state) | Stated plainly, with location and fix |
| Other bugs | Exercise, described by symptom: "`calculateTotal()` is wrong for one kind of cart. Which one?" |
| Clean code, tests, dependencies, minor security | Exercise, pointing to the area and category |

Bug exercises use the prove-it pattern:

1. Find the input that breaks it.
2. Write a failing test that proves the bug.
3. Fix it until the test passes.
4. The bug pattern (off-by-one, unhandled `null`, async race, ...) goes into `concepts.md`.

### 4.9 Debug

`/stickshift:debug` is for bugs you hit while working. The AI guides you instead of fixing it:

1. What did you expect, and what happened?
2. Can you reproduce it every time?
3. Narrow it down: where was the data last correct?
4. Form a guess about the cause and test it.
5. Fix it, and add a test so it can't come back.

The hint ladder applies at every step.

### 4.10 Pause and reset

- `/stickshift:pause` switches to automatic: normal Claude Code behaviour, lock off, until
  `/stickshift:start` resumes. Memory keeps being read.
- `/stickshift:reset` backs up `.stickshift/` (and, with `profile`, the learner profile) to
  `~/.claude/stickshift/backups/`, removes it, and offers to run `/stickshift:start` again.

### 4.11 Codex

Codex loads the plugin as it is: it reads `.claude-plugin/plugin.json` and `marketplace.json`,
runs `hooks/hooks.json`, and sets `CLAUDE_PLUGIN_ROOT`. The differences:

| | Claude Code | Codex |
|---|---|---|
| File edits | `Write`, `Edit`, ... with a `file_path` | `apply_patch`, one patch in `tool_input.command`. The guard checks every file the patch adds, updates, deletes or moves to |
| Reading files | `Read` tool | The shell. The guard lets plain one-line reads (`cat`, `tail`, ...) touch `.stickshift/.hook/` |
| Commands | `/stickshift:<name>` | No plugin slash commands. You ask by name and the skill reads `commands/<name>.md` and runs its script |
| Session context | Up to ~14 KB | Capped at about 2,500 tokens by Codex, so the session-start hook sends less |
| Hooks | Run once the plugin is installed | Run only after you trust them with `/hooks` |

Because the AI runs the scripts in Codex, switching modes depends on it running `pause.sh` and
`reset.sh` only when you ask. In Claude Code, the slash command runs them for you.

## 5. Commands

| Command | What it does |
|---|---|
| `/stickshift:start` | Onboarding, or resume after a pause |
| `/stickshift:pause` | Switch to automatic until resumed |
| `/stickshift:review` | Review your recent changes |
| `/stickshift:quiz` | Quiz on your project and concepts |
| `/stickshift:audit` | Bugs, security, clean code, tests, dependencies |
| `/stickshift:debug` | Guided debugging |
| `/stickshift:recap` | Summary of the session; updates the journal and asks for open teach-backs |
| `/stickshift:reset` | Back up and start over |

## 6. Plugin layout

```
stickshift/
  .claude-plugin/
    plugin.json
    marketplace.json          # for local install
  skills/stickshift/
    SKILL.md                  # core behaviour: modes, hint ladder, research, memory
    onboarding.md             # first-run and new-language questions
  commands/
    start.md  pause.md  review.md  quiz.md  audit.md  debug.md  recap.md  reset.md
  hooks/
    hooks.json
    lib.sh                    # shared helpers (project root, path resolution)
    session-start.sh          # load profile + .stickshift/ on startup and after compaction
    prompt-unlock.sh          # UserPromptSubmit: record "unlock <paths>"; one-line reminder otherwise
    guard.sh                  # PreToolUse: block edits outside .stickshift/ unless unlocked
  scripts/
    init.sh  pause.sh  reset.sh   # run by the start, pause and reset commands
  templates/                  # starting content for the notes and the profile
  DESIGN.md
  README.md
```
