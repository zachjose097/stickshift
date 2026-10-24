#!/bin/bash
# SessionStart hook. On startup and after compaction, reloads the learner profile
# and the project's notes so each session picks up where the last one stopped.

. "$(dirname "$0")/lib.sh"

# Without jq, say so in plain text (it becomes context too) if this is a Stickshift project.
if msg=$(ss_no_jq); then
  [ -d "$(ss_root "$PWD")/.stickshift" ] && echo "$msg"
  exit 0
fi

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
source=$(jq -r '.source // empty' <<<"$input")
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
root=$(ss_root "$cwd")
state="$root/.stickshift"
[ -d "$state" ] || exit 0

mode=$(cat "$state/.hook/mode" 2>/dev/null || echo manual)
profile="$HOME/.claude/stickshift/profile.md"

# Print notes file $1 without the templates' commented-out examples.
notes() { sed '/<!--/,/-->/d' "$state/$1.md" 2>/dev/null; }

# Codex (which sets PLUGIN_ROOT) cuts hook context at about 2,500 tokens, so send less there.
if [ -n "$PLUGIN_ROOT" ]; then
  profile_max=3000 map_max=2500 journal_lines=15
else
  profile_max=8000 map_max=6000 journal_lines=40
fi

ctx=$(
  echo "Stickshift is on in this project (mode: $mode). Use the stickshift skill and follow it for the whole session."
  if [ "$mode" = manual ]; then
    echo "Manual mode: the user writes the code. Your edits to project files outside .stickshift/ are blocked unless the user unlocks them."
    if [ -s "$state/.hook/delegated" ]; then
      echo "Delegated to you for the current feature: $(paste -sd, "$state/.hook/delegated" | sed 's/,/, /g'). They stay yours until the user sends a new delegate line or \"delegate none\"."
    fi
  else
    echo "Automatic mode (paused): work normally, but keep the notes in .stickshift/ up to date. /stickshift:start resumes manual mode."
  fi
  if [ -n "$PLUGIN_ROOT" ]; then
    echo "Codex has no plugin slash commands: when the user asks for a Stickshift command, follow the skill's \"Commands in Codex\" section. Plugin root: $PLUGIN_ROOT"
  fi
  echo
  echo "## Learner profile ($profile)"
  if [ -f "$profile" ]; then head -c "$profile_max" "$profile"; else echo "No profile yet. Suggest /stickshift:start."; fi
  echo
  echo "## Project map (.stickshift/map.md)"
  head -c "$map_max" "$state/map.md" 2>/dev/null
  echo
  echo "## Recent journal (.stickshift/journal.md)"
  tail -n "$journal_lines" "$state/journal.md" 2>/dev/null
  echo
  unconfirmed=$(notes concepts | grep -c 'Status: unconfirmed')
  open=$(notes questions | grep -c '^- \[ \]')
  echo "Unconfirmed concepts: ${unconfirmed:-0}. Open questions: ${open:-0}."
  echo "Read .stickshift/decisions.md, concepts.md and questions.md when they're relevant."

  # Offer a quiz when one is due. Not after compaction: that's the same session.
  if [ "$source" != compact ]; then
    total=$(notes concepts | grep -c '^- Status: [a-z]*$')
    last=$(notes concepts | grep 'Quiz record:' | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | tail -n 1)
    cutoff=$(date -v-3d +%F 2>/dev/null || date -d '3 days ago' +%F)
    due=""
    if [ "${unconfirmed:-0}" -ge 3 ]; then
      due="${unconfirmed} concepts are unconfirmed"
    elif [ -n "$last" ] && [ "${total:-0}" -ge 1 ] && [[ "$last" < "$cutoff" ]]; then
      due="the last quiz was on $last"
    elif [ -z "$last" ] && [ "${total:-0}" -ge 3 ]; then
      due="there are ${total} concepts and no quiz yet"
    fi
    if [ -n "$due" ]; then
      echo
      echo "A quiz is due ($due). In your first reply, after answering what they asked, offer once in one line: a quick 3-question quiz (/stickshift:quiz 3). If they decline or ignore it, don't offer again this session."
    fi
  fi
)

jq -n --arg c "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
