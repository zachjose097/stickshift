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
prompt "please unlock src/a.py"
expect deny  "unlock only counts at the start of the message" Write "$(w "$proj/src/a.py")"

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

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
