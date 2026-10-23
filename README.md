# Stickshift

> Vibe coding is autopilot. Stickshift puts you back in the driver's seat.

A plugin for Claude Code and Codex for learning while you build. **You write the code.** The AI
researches options, asks questions, gives hints one step at a time, reviews your work, quizzes you,
and keeps your decisions and lessons in local notes that carry over between sessions.

See [DESIGN.md](DESIGN.md) for the reasoning behind each decision.

## Install

Stickshift works with [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) and
[Codex](https://developers.openai.com/codex). Follow the steps for the one you use. It takes about
two minutes.

### Before you start

You need:

- **Claude Code or Codex**, installed and signed in. For Codex you need the `codex` command in your
  terminal (the Codex CLI), not only the app or editor extension.
- **macOS or Linux.** On Windows, use WSL.
- **`git` and `jq`


### Claude Code

1. **Add the Stickshift marketplace.** A marketplace is a list of plugins Claude Code can install
   from; this repo is one. In a terminal, run:

   ```
   claude plugin marketplace add https://github.com/zachjose097/stickshift.git
   ```

2. **Install the plugin:**

   ```
   claude plugin install stickshift@stickshift
   ```

   (`stickshift@stickshift` means "the stickshift plugin from the stickshift marketplace".)

   You can also do steps 1 and 2 inside Claude Code by typing
   `/plugin marketplace add https://github.com/zachjose097/stickshift.git` and then
   `/plugin install stickshift@stickshift`.

3. **Restart Claude Code** if it was open, so it loads the plugin.

4. **Start Stickshift in a project.** Open Claude Code in your project folder and type:

   ```
   /stickshift:start
   ```

   It should reply that Stickshift was created in manual mode and ask a few onboarding
   questions. If `/stickshift:start` isn't recognised, check that the install worked with
   `claude plugin list`.

### Codex

1. **Add the Stickshift marketplace.** A marketplace is a list of plugins Codex can install from;
   this repo is one. In a terminal, run:

   ```
   codex plugin marketplace add https://github.com/zachjose097/stickshift.git
   ```

2. **Install the plugin:**

   ```
   codex plugin add stickshift@stickshift
   ```

   (`stickshift@stickshift` means "the stickshift plugin from the stickshift marketplace".) In the
   Codex app you can install it from the Plugins Directory instead, once step 1 is done.

3. **Trust Stickshift's hooks.** Hooks are small scripts the plugin runs automatically, and they
   are what stop the AI editing your files. Codex doesn't run a plugin's hooks until you approve
   them. Start Codex, type `/hooks`, and trust the Stickshift hooks it lists.

4. **Start Stickshift in a project.** Open Codex in your project folder and type:

   ```
   stickshift start
   ```

   Codex has no plugin slash commands, so you ask for each command by name: `stickshift quiz`,
   `stickshift audit security`. If Codex asks to approve a command that writes outside your
   project, approve it: the start script adds `.stickshift/` to `.git/info/exclude` and creates
   your profile folder in `~/.claude/stickshift/`.

### Updating and removing

| | Claude Code | Codex |
|---|---|---|
| Update | `claude plugin marketplace update stickshift`, then `claude plugin update stickshift@stickshift` | `codex plugin marketplace upgrade stickshift`, then `codex plugin add stickshift@stickshift` |
| Remove | `claude plugin uninstall stickshift@stickshift` | `codex plugin remove stickshift@stickshift` |

Removing the plugin leaves your notes (`.stickshift/` in each project) and your profile
(`~/.claude/stickshift/`). Delete those yourself if you don't want them.

### From a local copy

To try your own changes, use the path to your clone in place of the GitHub URL in step 1.
Codex installs a copy of the plugin, so run `codex plugin add stickshift@stickshift` again after
each change.

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

**Delegating.** When you plan a feature, the AI suggests a split: the logic is yours, and
boilerplate you already know (CLI wiring, config, fixtures) it can write. If you agree, hand those
files over for the whole feature:

```
delegate cli.py tests/fixtures/
```

They stay delegated until you send another `delegate` line or `delegate none`.

**Learning that adapts.** Hints get stricter on concepts you've shown you know, and lighter on new
ones. Code the AI wrote for you comes back in quizzes, so you still learn what it does. Recaps end
with a line of progress, such as concepts you now know or needing fewer hints.

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

## Development

`bash tests/run.sh` tests the hooks and scripts (needs `git` and `jq`). CI runs it on Linux and
macOS, and validates the plugin with `claude plugin validate`.

## License

MIT
