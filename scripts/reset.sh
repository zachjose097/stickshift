#!/bin/bash
# Run by /stickshift:reset. Backs up the project notes (and, with "profile", the
# learner profile) to ~/.claude/stickshift/backups/, then removes them.

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../hooks/lib.sh"

case "$1" in
  "" | profile) ;;
  *) echo "Usage: /stickshift:reset [profile]"; exit 0 ;;
esac

root=$(ss_root "$PWD")
state="$root/.stickshift"
global="$HOME/.claude/stickshift"
backup="$global/backups/$(basename "$root")-$(date '+%Y%m%d-%H%M%S')"

if [ ! -d "$state" ] && [ "$1" != profile ]; then
  echo "Stickshift isn't started in this project. Nothing to reset."
  exit 0
fi

mkdir -p "$backup"
if [ -d "$state" ]; then
  cp -R "$state" "$backup/"
  rm -rf "$state"
  echo "Project notes backed up to $backup/.stickshift and removed."
fi
if [ "$1" = profile ] && [ -f "$global/profile.md" ]; then
  cp "$global/profile.md" "$backup/"
  rm "$global/profile.md"
  echo "Profile backed up to $backup/profile.md and removed."
fi
echo "Run /stickshift:start to begin again."
