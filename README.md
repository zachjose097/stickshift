# Stickshift

> Vibe coding is autopilot. Stickshift puts you back in the driver's seat.

A plugin for Claude Code and Codex for learning while you build. **You write the code.** The AI
researches options, asks questions, gives hints one step at a time, reviews your work, quizzes you,
and keeps your decisions and lessons in local notes that carry over between sessions.

See [DESIGN.md](DESIGN.md) for the reasoning behind each decision.

## Install

Requirements: Claude Code or Codex, `bash`, `git` and `jq` (built into macOS 15+; elsewhere
install with your package manager).

### Claude Code

```
/plugin marketplace add /path/to/stickshift
/plugin install stickshift@stickshift
```

Restart Claude Code, then in a project:

```
/stickshift:start
```

### Codex

```
codex plugin marketplace add /path/to/stickshift
codex plugin add stickshift@stickshift
```

Start Codex and run `/hooks` to review and trust Stickshift's hooks. Codex doesn't run a plugin's
hooks until you do, and without them there's no edit lock. Then, in a project, ask:

```
stickshift start
```

Codex has no plugin slash commands, so ask for the commands below by name instead: `stickshift
quiz`, `stickshift audit security`. Unlocking works the same in both.

## How it works

**Manual mode.** In a project where you've run `/stickshift:start`, the AI can't edit your files.
It can only write its notes in `.stickshift/`. When you're stuck it climbs a hint ladder: a
question, the concept by name, pseudocode, an unrelated example, and only then the code (in chat,
when you ask).

**Unlocking.** Start a message with `unlock` to let the AI write specific files for that one
request:

```
unlock src/config.ts — write the env loader
unlock src/fixtures/ tests/setup.ts — generate test data
unlock . — scaffold the project
```

The unlock ends when you send your next message. Only you can unlock: the AI can't write the files
the hooks use.

**Memory.** Notes live in `.stickshift/` in each project:

| File | Contents |
|---|---|
| `decisions.md` | Your design decisions, reasoning and rejected options |
| `concepts.md` | What you learned, in your words where possible |
| `map.md` | How the project fits together |
| `questions.md` | Open questions |
| `journal.md` | Short session logs |

Your learner profile (languages and levels, preferences, concepts you've shown you know) lives in
`~/.claude/stickshift/profile.md` and is shared across projects. Both are plain Markdown you can
edit.

Nothing is committed: `/stickshift:start` adds `.stickshift/` to `.git/info/exclude`, which works
like `.gitignore` but stays on your machine.

## Commands

| Command | What it does |
|---|---|
| `/stickshift:start` | Onboarding, or resume manual mode after a pause |
| `/stickshift:pause` | Automatic mode: edit lock off until you start again |
| `/stickshift:review [target]` | Review your code; asks before judging |
| `/stickshift:quiz [topic] [n]` | Quiz on your project, decisions and concepts |
| `/stickshift:audit [area]` | Bugs, security, clean code, tests, dependencies |
| `/stickshift:debug [problem]` | Guided debugging, step by step |
| `/stickshift:recap` | Wrap up the session and update notes |
| `/stickshift:reset [profile]` | Back up and clear notes (and the profile) |

## Limits

- The edit lock blocks the AI's file-editing tools completely. Shell writes (`>`, `tee`, `sed -i`,
  `patch`, `git apply`) are caught by pattern; a determined workaround such as a script that writes
  files could slip past. It's a guardrail, not a sandbox.
- Notes are read into the AI's context, so your Claude Code or Codex data settings apply to them.
- In Codex, the AI runs the start, pause and reset scripts itself, because there are no slash
  commands to run them for you. Switching modes relies on it doing that only when you ask.
- Codex support hasn't been tried on a real Codex install yet.

## License

MIT
