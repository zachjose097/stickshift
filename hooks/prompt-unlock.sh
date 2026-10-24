#!/bin/bash
# UserPromptSubmit hook. Records the paths the user unlocked for this one request,
# from a first line like "unlock src/config.ts src/env.ts — write the env loader",
# and the paths they delegated for the current feature, from "delegate cli.py table.py"
# (until the next delegate line, or "delegate none"). Only hooks write .stickshift/.hook/,
# so only the user can unlock. In manual mode, other messages get a one-line reminder
# of how Stickshift works.

. "$(dirname "$0")/lib.sh"
ss_no_jq >/dev/null && exit 0   # guard.sh blocks edits and session-start.sh explains.

# Send text to the model as context. JSON, because Codex reads plain output that
# starts with "[" as broken JSON and drops it.
context() {
  jq -n --arg c "$1" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}'
}

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
root=$(ss_root "$cwd")
hook="$root/.stickshift/.hook"
first=$(jq -r '.prompt // empty' <<<"$input" | head -n 1)

# Note when a message about Stickshift arrives, so init.sh can tell whether the hooks
# run (Codex runs them only while the user trusts them, and an update drops that trust).
case "$(printf '%s' "$first" | tr '[:upper:]' '[:lower:]')" in
  *stickshift*)
    mkdir -p "$HOME/.claude/stickshift" 2>/dev/null &&
      printf '%s\t%s\n' "$(date +%s)" "$root" > "$HOME/.claude/stickshift/.hooks-seen" 2>/dev/null
    ;;
esac

[ -d "$hook" ] || exit 0

# Unlocks, and permission to run pause.sh or reset.sh, last for one request.
: > "$hook/unlocks"
: > "$hook/command"

# The user's own pause or reset ("/stickshift:pause", "stickshift reset profile").
# guard.sh lets the model run that script only now: in Codex it has to run it itself.
asked=$(printf '%s\n' "$first" |
  sed -nE 's#^[[:space:]]*/?stickshift[:[:space:]]+(pause|reset)([[:space:]].*)?$#\1#Ip' | tr '[:upper:]' '[:lower:]')
[ -n "$asked" ] && printf '%s\n' "$asked" > "$hook/command"

# The rest of the first line after keyword $1, up to a dash or colon, or nothing.
spec_after() {
  local s
  s=$(printf '%s\n' "$first" | sed -nE "s/^[[:space:]]*$1:?[[:space:]]+//Ip")
  s=${s%%—*}
  s=${s%%–*}
  s=${s%% - *}
  printf '%s' "${s%%:*}"
}

# Print each path in $1 that is inside the project, relative to the root (. for the root).
# Stops at the first word that doesn't look like a path, so "unlock app.py to add tests"
# unlocks only app.py: a path has a slash or a dot in it, or already exists.
project_paths() {
  local w p
  set -f
  for w in $1; do
    w=$(printf '%s' "$w" | tr -d "\"'\`,")
    [ -n "$w" ] || continue
    p=$(ss_abs "$w" "$cwd")
    case "$w" in */* | *.*) ;; *) [ -e "$p" ] || break ;; esac
    if [ "$p" = "$root" ]; then
      echo .
    else
      case "$p" in
        "$root/"*) echo "${p#"$root/"}" ;;
      esac   # Outside the project: never locked.
    fi
  done
  set +f
}

# Comma-separated list of the paths in file $1.
joined() { paste -sd, "$1" | sed 's/,/, /g'; }

unlocks=$(project_paths "$(spec_after unlock)")
[ -n "$unlocks" ] && printf '%s\n' "$unlocks" > "$hook/unlocks"
list=$([ -n "$unlocks" ] && joined "$hook/unlocks")

delegate_spec=$(spec_after delegate)
delegate_msg=""
if [ "$(printf '%s' "$delegate_spec" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')" = none ]; then
  : > "$hook/delegated"
  delegate_msg="[stickshift] The user took back all delegated paths. Every project file is theirs again."
elif [ -n "$delegate_spec" ]; then
  delegated=$(project_paths "$delegate_spec")
  if [ -n "$delegated" ]; then
    printf '%s\n' "$delegated" > "$hook/delegated"
    printf '%s\tdelegate\t%s\n' "$(date '+%Y-%m-%d %H:%M')" "$(joined "$hook/delegated")" >> "$hook/unlocks.log"
    delegate_msg="[stickshift] The user delegated these paths to you for the current feature: $(joined "$hook/delegated"). You may write them until they send a new delegate line or \"delegate none\". Everything else stays theirs. Note the delegation in today's entry in .stickshift/journal.md."
  fi
fi

# Remember the last five messages (U = unlock, - = other) to notice a run of unlocks.
recent=$(cat "$hook/recent" 2>/dev/null)
if [ -n "$list" ]; then recent="${recent}U"; else recent="${recent}-"; fi
[ ${#recent} -gt 5 ] && recent=${recent:${#recent}-5}
printf '%s' "$recent" > "$hook/recent"

if [ -n "$delegate_msg" ] && [ -z "$list" ]; then
  context "$delegate_msg"
  exit 0
fi

if [ -z "$list" ]; then
  # A one-line reminder each message, so the skill doesn't fade in long sessions.
  if [ "$(cat "$hook/mode" 2>/dev/null || echo manual)" = manual ]; then
    msg="[stickshift] Manual mode: the user plans and writes the code. Use the hint ladder for their project's logic; answer syntax and quick factual questions directly."
    [ -s "$hook/delegated" ] && msg="$msg Delegated to you for this feature: $(joined "$hook/delegated")."
    context "$msg"
  fi
  exit 0
fi

printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M')" "$list" >> "$hook/unlocks.log"
msg="[stickshift] The user unlocked these paths for this request only: $list. You may edit them now. Afterwards, briefly explain the code you wrote and ask one question to check they followed it. Add the unlock to today's entry in .stickshift/journal.md."

# Nudge once, when a run of unlocks reaches four.
streak=${recent##*-}
if [ ${#streak} -eq 4 ]; then
  msg="$msg
[stickshift] The user's last 4 messages were all unlocks. Mention this once, lightly, and offer to let them write the next piece. Don't refuse or lecture."
fi
context "$msg"
exit 0
