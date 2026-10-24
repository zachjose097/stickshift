#!/bin/bash
# Run by /stickshift:start. Creates or resumes Stickshift in the current project,
# switches to manual mode, and reports what the model needs for onboarding.

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../hooks/lib.sh"
templates="$here/../templates"

root=$(ss_root "$PWD")
state="$root/.stickshift"
global="$HOME/.claude/stickshift"

ss_no_jq

# In Codex, hooks run only while the user trusts them, and an update drops that trust.
# The prompt hook notes each message about Stickshift; if it didn't see the one that
# started this, in this project in the last few minutes, the hooks aren't running.
# Claude Code (CLAUDECODE=1) needs no trust, and runs this before the prompt hook.
if [ "$CLAUDECODE" != 1 ]; then
  seen=$(cat "$global/.hooks-seen" 2>/dev/null)
  seen_at=${seen%%$'\t'*}
  case "$seen_at" in '' | *[!0-9]*) seen_at=0 ;; esac
  if [ "${seen#*$'\t'}" != "$root" ] || [ $(($(date +%s) - seen_at)) -gt 300 ]; then
    echo "WARNING: Stickshift's hooks didn't run for this message, so the edit lock is off. Tell the user plainly: in Codex, type /hooks and trust the Stickshift hooks (needed again after every plugin update), then start a new session."
  fi
fi

if [ -d "$state" ]; then status=resumed; else status=created; fi
mkdir -p "$state/.hook"
mkdir -p "$global" 2>/dev/null || echo "WARNING: couldn't create $global (a sandbox may block writes outside the project). Ask the user to approve running this script again outside the sandbox."
for f in decisions concepts map questions journal; do
  [ -f "$state/$f.md" ] || cp "$templates/$f.md" "$state/$f.md"
done
: > "$state/.hook/unlocks"
: > "$state/.hook/delegated"
echo manual > "$state/.hook/mode"

# Keep the notes out of git without touching the committed .gitignore.
# --git-path, because a worktree's own git dir has an info/exclude that git ignores.
exclude=$(git -C "$root" rev-parse --git-path info/exclude 2>/dev/null)
if [ -n "$exclude" ]; then
  case "$exclude" in /*) ;; *) exclude="$root/$exclude" ;; esac
  if grep -qxF '.stickshift/' "$exclude" 2>/dev/null; then
    git_note="already excluded via .git/info/exclude"
  elif mkdir -p "$(dirname "$exclude")" 2>/dev/null &&
    printf '\n# Stickshift learning notes (local only)\n.stickshift/\n' 2>/dev/null >> "$exclude"; then
    git_note="added to .git/info/exclude"
  else
    # Codex's sandbox makes .git read-only.
    git_note="WARNING: NOT excluded from git, couldn't write $exclude. Tell the user plainly: their notes could be committed. Ask them to approve running this script again outside the sandbox, or to add .stickshift/ to that file themselves."
  fi
else
  git_note="not a git repository, nothing to exclude"
fi

echo "Stickshift: $status in $root (mode: manual)"
echo "Notes: $state ($git_note)"
if [ -f "$global/profile.md" ]; then
  echo "Profile: $global/profile.md"
  sed -n '/^## Languages/,/^## /p' "$global/profile.md" | sed '$d'
else
  echo "Profile: none yet. Create $global/profile.md from $templates/profile.md during onboarding."
fi

echo "Stack files found:"
found=0
for f in package.json tsconfig.json deno.json pyproject.toml requirements.txt Cargo.toml go.mod Gemfile pom.xml build.gradle composer.json Package.swift pubspec.yaml mix.exs; do
  if [ -f "$root/$f" ]; then echo "  $f"; found=1; fi
done
[ "$found" = 1 ] || echo "  none (new or unusual project; ask what it will be written in)"

if [ "$status" = resumed ]; then
  echo "Last journal lines:"
  tail -n 12 "$state/journal.md"
fi
