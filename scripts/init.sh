#!/bin/bash
# Run by /stickshift:start. Creates or resumes Stickshift in the current project,
# switches to manual mode, and reports what the model needs for onboarding.

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../hooks/lib.sh"
templates="$here/../templates"

root=$(ss_root "$PWD")
state="$root/.stickshift"
global="$HOME/.claude/stickshift"

if [ -d "$state" ]; then status=resumed; else status=created; fi
mkdir -p "$state/.hook" "$global"
for f in decisions concepts map questions journal; do
  [ -f "$state/$f.md" ] || cp "$templates/$f.md" "$state/$f.md"
done
: > "$state/.hook/unlocks"
echo manual > "$state/.hook/mode"

# Keep the notes out of git without touching the committed .gitignore.
gitdir=$(git -C "$root" rev-parse --git-dir 2>/dev/null)
if [ -n "$gitdir" ]; then
  case "$gitdir" in /*) ;; *) gitdir="$root/$gitdir" ;; esac
  exclude="$gitdir/info/exclude"
  mkdir -p "$(dirname "$exclude")"
  if grep -qxF '.stickshift/' "$exclude" 2>/dev/null; then
    git_note="already excluded via .git/info/exclude"
  else
    printf '\n# Stickshift learning notes (local only)\n.stickshift/\n' >> "$exclude"
    git_note="added to .git/info/exclude"
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
