#!/bin/bash
# Tests for the hooks and scripts. Run from anywhere: bash tests/run.sh
# Needs bash, git and jq. Works on macOS and Linux.

repo=$(cd "$(dirname "$0")/.." && pwd)
hooks="$repo/hooks"
pass=0 fail=0

ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; }

# A fresh git project with Stickshift started, and a HOME of its own.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
proj=$(cd "$tmp" && mkdir proj && cd proj && pwd -P)
export HOME="$tmp/home"
mkdir -p "$HOME"
git -C "$proj" init -q
mkdir -p "$proj/src" "$proj/tests" && echo a > "$proj/src/a.py"
(cd "$proj" && bash "$repo/scripts/init.sh" >/dev/null)
state="$proj/.stickshift"

# --- Skill files -------------------------------------------------------------

# Claude Code runs an exclamation mark followed by a backticked command as a shell
# command when it loads a skill, so skill files must never contain one.
if grep -rn '!`' "$repo/skills" >/dev/null; then
  bad "skills/ contains an exclamation mark before a backtick:"
  grep -rn '!`' "$repo/skills"
else ok; fi

# --- Setup -------------------------------------------------------------------

for f in decisions concepts map questions journal; do
  [ -f "$state/$f.md" ] && ok || bad "init.sh didn't create $f.md"
done
[ "$(cat "$state/.hook/mode")" = manual ] && ok || bad "init.sh didn't set manual mode"
grep -qxF '.stickshift/' "$proj/.git/info/exclude" && ok || bad "init.sh didn't add the git exclude"

# --- guard.sh ----------------------------------------------------------------

# guard <tool> <json tool_input>: prints "deny" or "allow".
guard() {
  local out
  out=$(jq -n --arg t "$1" --argjson i "$2" --arg c "$proj" '{tool_name: $t, tool_input: $i, cwd: $c}' |
    bash "$hooks/guard.sh")
  if grep -q '"deny"' <<<"$out"; then echo deny; else echo allow; fi
}
expect() { # expect <deny|allow> <description> <tool> <json>
  local got
  got=$(guard "$3" "$4")
  [ "$got" = "$1" ] && ok || bad "guard: $2 (expected $1, got $got)"
}
# prompt <text>: sends a user message through the unlock hook.
prompt() {
  jq -n --arg p "$1" --arg c "$proj" '{prompt: $p, cwd: $c}' | bash "$hooks/prompt-unlock.sh" >/dev/null
}
w() { jq -n --arg p "$1" '{file_path: $p}'; }
sh() { jq -n --arg c "$1" '{command: $c}'; }

prompt "how do I read a csv?"
expect deny  "Write to a project file in manual mode" Write "$(w "$proj/src/a.py")"
expect deny  "Edit with a relative path" Edit "$(w src/a.py)"
expect allow "Write to notes" Write "$(w "$state/journal.md")"
expect deny  "Write to .stickshift/.hook" Write "$(w "$state/.hook/mode")"
expect allow "Write outside the project" Write "$(w "$HOME/.claude/stickshift/profile.md")"
expect deny  "shell redirect into a project file" Bash "$(sh "echo x > src/a.py")"
expect deny  "tee into a project file" Bash "$(sh "echo x | tee -a src/a.py")"
expect allow "redirect to /dev/null" Bash "$(sh "ls 2>/dev/null")"
expect allow "redirect into notes" Bash "$(sh "echo x >> .stickshift/journal.md")"
expect deny  "sed -i on a project file" Bash "$(sh "sed -i '' 's/a/b/' src/a.py")"
expect allow "sed -i on notes" Bash "$(sh "sed -i '' 's/a/b/' .stickshift/journal.md")"
expect deny  "git apply" Bash "$(sh "git apply fix.patch")"
expect allow "reading .hook with cat" Bash "$(sh "cat .stickshift/.hook/mode")"
expect deny  "writing .hook from the shell" Bash "$(sh "echo auto > .stickshift/.hook/mode")"
expect deny  "Codex patch to a project file" apply_patch \
  "$(sh $'*** Begin Patch\n*** Update File: src/a.py\n@@\n-a\n+b\n*** End Patch')"
expect allow "Codex patch to notes" apply_patch \
  "$(sh $'*** Begin Patch\n*** Update File: .stickshift/map.md\n@@\n-a\n+b\n*** End Patch')"

expect deny  "clobber redirect" Bash "$(sh "echo x >| src/a.py")"
expect deny  "cp into a project file" Bash "$(sh "cp /tmp/x src/a.py")"
expect deny  "mv onto a project file" Bash "$(sh "mv /tmp/x src/b.py")"
expect deny  "rm a project file" Bash "$(sh "rm -f src/a.py")"
expect deny  "dd into a project file" Bash "$(sh "dd if=/dev/zero of=src/a.py")"
expect deny  "sed -i through .stickshift/.." Bash "$(sh "sed -i '' s/a/b/ .stickshift/../src/a.py")"
expect deny  "sed -i on a project file next to a note" Bash "$(sh "sed -i '' s/a/b/ src/a.py .stickshift/journal.md")"
expect deny  "perl -pi on a project file" Bash "$(sh "perl -pi -e 's/a/b/' src/a.py")"
expect deny  "git checkout -- a file" Bash "$(sh "git checkout -- src/a.py")"
expect deny  "git reset --hard" Bash "$(sh "git status && git reset --hard")"
expect deny  "git stash" Bash "$(sh "git stash")"
expect allow "git stash list" Bash "$(sh "git stash list")"
expect allow "git log" Bash "$(sh "git log --oneline -5")"
expect allow "cp into notes" Bash "$(sh "cp /tmp/x .stickshift/questions.md")"
expect allow "cp out of the project" Bash "$(sh "cp src/a.py /tmp/a.py")"
expect deny  "rm the notes folder" Bash "$(sh "rm -rf .stickshift")"
expect deny  "rm the project" Bash "$(sh "rm -rf .")"
expect deny  "mv the notes folder" Bash "$(sh "mv .stickshift /tmp/old")"
if command -v cygpath >/dev/null 2>&1; then   # Windows paths, as Claude Code sends them there.
  wproj=$(cygpath -w "$proj")
  expect allow "Write to notes, Windows path" Write "$(w "$wproj\\.stickshift\\map.md")"
  expect allow "Write to notes, forward slashes" Write "$(w "$(cygpath -m "$proj")/.stickshift/map.md")"
  expect deny  "Write to a project file, Windows path" Write "$(w "$wproj\\src\\a.py")"
  expect deny  "Write to .hook, Windows path" Write "$(w "$wproj\\.stickshift\\.hook\\mode")"
  expect deny  "writing .hook from the shell, backslashes" Bash "$(sh "echo auto > .stickshift\\.hook\\mode")"
  out=$(jq -n --arg c "$wproj" --arg p "$wproj\\src\\a.py" '{tool_name: "Write", tool_input: {file_path: $p}, cwd: $c}' |
    bash "$hooks/guard.sh")
  grep -q '"deny"' <<<"$out" && ok || bad "guard: Windows cwd (expected deny)"
fi
expect deny  "running pause.sh without being asked" Bash "$(sh "bash $repo/scripts/pause.sh")"
expect deny  "running reset.sh without being asked" Bash "$(sh "bash $repo/scripts/reset.sh")"
ln -s ../src/a.py "$state/link"
expect deny  "Write through a symlink in notes" Write "$(w "$state/link")"
rm "$state/link"

# The user's own pause and reset allow the model to run that script, for that message.
prompt "stickshift pause"
expect allow "pause.sh after the user asked" Bash "$(sh "bash $repo/scripts/pause.sh")"
expect deny  "reset.sh after the user asked for pause" Bash "$(sh "bash $repo/scripts/reset.sh")"
prompt "/stickshift:reset profile"
expect allow "reset.sh after the user asked" Bash "$(sh "bash $repo/scripts/reset.sh profile")"
prompt "ok"
expect deny  "permission ends after the message" Bash "$(sh "bash $repo/scripts/pause.sh")"

# Unlocks cover the named paths, for one message only.
prompt "unlock src/a.py lib/ — write the reader"
expect allow "unlocked file" Write "$(w "$proj/src/a.py")"
expect allow "file inside an unlocked folder" Write "$(w "$proj/lib/x/y.py")"
expect deny  "file that wasn't unlocked" Write "$(w "$proj/src/b.py")"
expect allow "shell redirect into an unlocked file" Bash "$(sh "echo x > src/a.py")"
expect deny  "unlock doesn't cover .hook" Write "$(w "$state/.hook/unlocks")"
grep -q 'src/a.py, lib' "$state/.hook/unlocks.log" && ok || bad "unlock wasn't logged"
prompt "thanks"
expect deny  "unlock expired after the next message" Write "$(w "$proj/src/a.py")"
prompt "Unlock . - do it all"
expect allow "unlock . covers the whole project" Write "$(w "$proj/anything.py")"
prompt "unlock src/a.py to add tests"
expect allow "unlock stops at the first word that isn't a path" Write "$(w "$proj/src/a.py")"
expect deny  "words after the paths aren't unlocked" Write "$(w "$proj/tests/test_a.py")"
prompt "unlock: src/a.py – en dash"
expect allow "unlock with a colon and an en dash" Write "$(w "$proj/src/a.py")"
prompt "Unlock screens need a timeout, how?"
[ ! -s "$state/.hook/unlocks" ] && ok || bad "a sentence starting with Unlock unlocked: $(cat "$state/.hook/unlocks")"
prompt "please unlock src/a.py"
expect deny  "unlock only counts at the start of the message" Write "$(w "$proj/src/a.py")"

# Delegations cover the named paths until replaced, cleared, or Stickshift restarts.
prompt "delegate cli.py src/table/ — for monthly totals"
expect allow "delegated file" Write "$(w "$proj/cli.py")"
expect allow "file inside a delegated folder" Write "$(w "$proj/src/table/fmt.py")"
expect deny  "file that wasn't delegated" Write "$(w "$proj/src/a.py")"
prompt "how's it going?"
prompt "and now?"
expect allow "delegation lasts across messages" Write "$(w "$proj/cli.py")"
prompt "unlock src/a.py — one change"
expect allow "unlock works alongside a delegation" Write "$(w "$proj/src/a.py")"
expect allow "delegation survives an unlock" Write "$(w "$proj/cli.py")"
expect deny  "delegation doesn't cover .hook" Write "$(w "$state/.hook/delegated")"
grep -q 'delegate	cli.py, src/table' "$state/.hook/unlocks.log" && ok || bad "delegation wasn't logged"
out=$(jq -n --arg c "$proj" '{cwd: $c, source: "startup"}' | bash "$hooks/session-start.sh")
grep -q 'Delegated to you for the current feature: cli.py, src/table\.' <<<"$out" && ok ||
  bad "session start doesn't mention the delegation"
prompt "delegate report.py"
expect allow "new delegation" Write "$(w "$proj/report.py")"
expect deny  "new delegation replaces the old one" Write "$(w "$proj/cli.py")"
prompt "please delegate cli.py"
expect deny  "delegate only counts at the start of the message" Write "$(w "$proj/cli.py")"
prompt "Delegate None"
expect deny  "delegate none clears it" Write "$(w "$proj/report.py")"
prompt "delegate cli.py"
(cd "$proj" && bash "$repo/scripts/init.sh" >/dev/null)
expect deny  "start clears delegations" Write "$(w "$proj/cli.py")"

# Automatic mode lifts the lock, except on .hook.
(cd "$proj" && bash "$repo/scripts/pause.sh" >/dev/null)
expect allow "automatic mode allows project files" Write "$(w "$proj/src/a.py")"
expect deny  "automatic mode still protects .hook" Write "$(w "$state/.hook/mode")"
(cd "$proj" && bash "$repo/scripts/init.sh" >/dev/null)
expect deny  "start returns to manual mode" Write "$(w "$proj/src/a.py")"

# --- session-start.sh: quiz offer --------------------------------------------

# quiz_offer <source>: prints "offer" or "none".
quiz_offer() {
  local out
  out=$(jq -n --arg c "$proj" --arg s "$1" '{cwd: $c, source: $s}' | bash "$hooks/session-start.sh")
  jq -e . >/dev/null <<<"$out" || { echo invalid-json; return; }
  if grep -q 'A quiz is due' <<<"$out"; then echo offer; else echo none; fi
}
concepts() { cp "$repo/templates/concepts.md" "$state/concepts.md"; }
concept() { printf '\n## %s\n- Status: %s\n- Quiz record: %s\n' "$1" "$2" "$3" >> "$state/concepts.md"; }
expect_quiz() { # expect_quiz <offer|none> <description> [source]
  local got
  got=$(quiz_offer "${3:-startup}")
  [ "$got" = "$1" ] && ok || bad "quiz: $2 (expected $1, got $got)"
}

concepts
expect_quiz none "no concepts yet"
concept A unconfirmed ""; concept B unconfirmed ""
expect_quiz none "two unconfirmed concepts"
concept C unconfirmed ""
expect_quiz offer "three unconfirmed concepts"
expect_quiz none "no offer after compaction" compact
concepts; concept A confirmed ""; concept B confirmed ""; concept C confirmed ""
expect_quiz offer "three concepts, never quizzed"
concepts; concept A confirmed "✓ 2020-01-01, ✗ 2020-01-05"
expect_quiz offer "last quiz long ago"
concepts; concept A confirmed "✓ $(date +%F)"
expect_quiz none "quizzed today"
out=$(jq -n --arg c "$proj" '{cwd: $c}' | bash "$hooks/session-start.sh")
jq -e . >/dev/null <<<"$out" && ok || bad "session-start without a source field isn't valid JSON"

# Counts skip the templates' commented-out examples.
cp "$repo/templates/questions.md" "$state/questions.md"
grep -q 'Open questions: 0\.' <<<"$out" && ok || bad "the questions template counts as an open question"
echo "- [ ] Why does the BOM break the header? (2026-10-24)" >> "$state/questions.md"
out=$(jq -n --arg c "$proj" '{cwd: $c}' | bash "$hooks/session-start.sh")
grep -q 'Open questions: 1\.' <<<"$out" && ok || bad "a real open question isn't counted"

# --- Scripts -----------------------------------------------------------------

# Start warns when the prompt hook didn't see the message that started it (outside Claude Code).
hooks_warning() { (cd "$proj" && env -u CLAUDECODE "$@" bash "$repo/scripts/init.sh") | grep -c "hooks didn't run"; }
rm -f "$HOME/.claude/stickshift/.hooks-seen"
[ "$(hooks_warning)" = 1 ] && ok || bad "start doesn't warn when the hooks haven't run"
[ "$(hooks_warning CLAUDECODE=1)" = 0 ] && ok || bad "start warns in Claude Code"
prompt "stickshift start"
[ "$(hooks_warning)" = 0 ] && ok || bad "start warns although the prompt hook ran"
prompt "Stickshift start" && cp "$HOME/.claude/stickshift/.hooks-seen" "$tmp/seen"
sed -E 's/^[0-9]+/1000/' "$tmp/seen" > "$HOME/.claude/stickshift/.hooks-seen"
[ "$(hooks_warning)" = 1 ] && ok || bad "start doesn't warn when the hooks last ran long ago"

# Reset removes nothing it couldn't back up.
r=$(mktemp -d)
(cd "$r" && git init -q && HOME="$r/home" bash "$repo/scripts/init.sh" >/dev/null)
mkdir -p "$r/home/.claude/stickshift" && chmod 500 "$r/home/.claude/stickshift"
(cd "$r" && HOME="$r/home" bash "$repo/scripts/reset.sh" >/dev/null)
[ -d "$r/.stickshift" ] && ok || bad "reset removed the notes when the backup failed"
chmod 700 "$r/home/.claude/stickshift"
(cd "$r" && HOME="$r/home" bash "$repo/scripts/reset.sh" >/dev/null)
[ ! -d "$r/.stickshift" ] && [ -n "$(ls "$r/home/.claude/stickshift/backups")" ] && ok || bad "reset didn't back up and remove the notes"

# In a git worktree the exclude goes where git reads it.
git -C "$proj" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$proj" worktree add -q "$r/wt"
(cd "$r/wt" && bash "$repo/scripts/init.sh" >/dev/null)
[ -z "$(git -C "$r/wt" status --porcelain)" ] && ok || bad "notes aren't excluded in a worktree"
git -C "$proj" worktree remove --force "$r/wt"
rm -rf "$r"

# Without jq, the guard fails closed and session start explains why.
nojq=$(mktemp -d)
for b in bash git cat sed grep dirname basename head tail date paste tr pwd; do
  p=$(command -v "$b") && ln -s "$p" "$nojq/$b"
done
(cd "$proj" && echo '{}' | PATH="$nojq" bash "$hooks/guard.sh" 2>/dev/null)
[ $? = 2 ] && ok || bad "guard without jq doesn't block"
(cd "$proj" && echo '{}' | PATH="$nojq" bash "$hooks/session-start.sh") | grep -q "jq isn't installed" && ok ||
  bad "session start without jq doesn't explain"
rm -rf "$nojq"

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
