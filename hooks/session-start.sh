#!/bin/bash
# SessionStart hook. On startup and after compaction, reloads the learner profile
# and the project's notes so each session picks up where the last one stopped.

. "$(dirname "$0")/lib.sh"

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
root=$(ss_root "$cwd")
state="$root/.stickshift"
[ -d "$state" ] || exit 0

mode=$(cat "$state/.hook/mode" 2>/dev/null || echo manual)
profile="$HOME/.claude/stickshift/profile.md"

ctx=$(
  echo "Stickshift is on in this project (mode: $mode). Use the stickshift skill and follow it for the whole session."
  if [ "$mode" = manual ]; then
    echo "Manual mode: the user writes the code. Your edits to project files outside .stickshift/ are blocked unless the user unlocks them."
  else
    echo "Automatic mode (paused): work like normal Claude Code, but keep the notes in .stickshift/ up to date. /stickshift:start resumes manual mode."
  fi
  echo
  echo "## Learner profile ($profile)"
  if [ -f "$profile" ]; then head -c 8000 "$profile"; else echo "No profile yet. Suggest /stickshift:start."; fi
  echo
  echo "## Project map (.stickshift/map.md)"
  head -c 6000 "$state/map.md" 2>/dev/null
  echo
  echo "## Recent journal (.stickshift/journal.md)"
  tail -n 40 "$state/journal.md" 2>/dev/null
  echo
  unconfirmed=$(grep -c 'Status: unconfirmed' "$state/concepts.md" 2>/dev/null)
  open=$(grep -c '^- \[ \]' "$state/questions.md" 2>/dev/null)
  echo "Unconfirmed concepts: ${unconfirmed:-0}. Open questions: ${open:-0}."
  echo "Read .stickshift/decisions.md, concepts.md and questions.md when they're relevant."
)

jq -n --arg c "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
