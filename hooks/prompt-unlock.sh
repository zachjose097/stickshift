#!/bin/bash
# UserPromptSubmit hook. Records the paths the user unlocked for this one request,
# from a first line like "unlock src/config.ts src/env.ts — write the env loader".
# Only hooks write .stickshift/.hook/, so only the user can unlock. In manual mode,
# other messages get a one-line reminder of how Stickshift works.

. "$(dirname "$0")/lib.sh"

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
root=$(ss_root "$cwd")
hook="$root/.stickshift/.hook"
[ -d "$hook" ] || exit 0

# Unlocks last for one request.
: > "$hook/unlocks"

first=$(jq -r '.prompt // empty' <<<"$input" | head -n 1)
spec=$(printf '%s\n' "$first" | sed -nE 's/^[[:space:]]*[Uu][Nn][Ll][Oo][Cc][Kk][[:space:]]+//p')
spec=${spec%%—*}
spec=${spec%% - *}
spec=${spec%%:*}

list=""
set -f
for w in $spec; do
  w=$(printf '%s' "$w" | tr -d "\"'\`,")
  [ -n "$w" ] || continue
  p=$(ss_abs "$w" "$cwd")
  if [ "$p" = "$root" ]; then
    rel=.
  else
    case "$p" in
      "$root/"*) rel=${p#"$root/"} ;;
      *) continue ;;   # Outside the project: never locked.
    esac
  fi
  printf '%s\n' "$rel" >> "$hook/unlocks"
  list="$list${list:+, }$rel"
done
set +f

# Remember the last five messages (U = unlock, - = other) to notice a run of unlocks.
recent=$(cat "$hook/recent" 2>/dev/null)
if [ -n "$list" ]; then recent="${recent}U"; else recent="${recent}-"; fi
[ ${#recent} -gt 5 ] && recent=${recent:${#recent}-5}
printf '%s' "$recent" > "$hook/recent"

if [ -z "$list" ]; then
  # A one-line reminder each message, so the skill doesn't fade in long sessions.
  if [ "$(cat "$hook/mode" 2>/dev/null || echo manual)" = manual ]; then
    echo "[stickshift] Manual mode: the user plans and writes the code. Use the hint ladder for their project's logic; answer syntax and quick factual questions directly."
  fi
  exit 0
fi

printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M')" "$list" >> "$hook/unlocks.log"
echo "[stickshift] The user unlocked these paths for this request only: $list. You may edit them now. Afterwards, briefly explain the code you wrote and ask one question to check they followed it. Add the unlock to today's entry in .stickshift/journal.md."

# Nudge once, when a run of unlocks reaches four.
streak=${recent##*-}
if [ ${#streak} -eq 4 ]; then
  echo "[stickshift] The user's last 4 messages were all unlocks. Mention this once, lightly, and offer to let them write the next piece. Don't refuse or lecture."
fi
exit 0
