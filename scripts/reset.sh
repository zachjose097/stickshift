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

# Remove nothing that wasn't backed up.
failed() {
  echo "Couldn't back up to $backup, so $1 was left as it was. A sandbox may block writes outside the project: ask the user to approve running this again outside it."
  exit 1
}
mkdir -p "$backup" 2>/dev/null || failed "everything"
if [ -d "$state" ]; then
  cp -R "$state" "$backup/" 2>/dev/null || failed "$state"
  rm -rf "$state"
  echo "Project notes backed up to $backup/.stickshift and removed."
fi
if [ "$1" = profile ] && [ -f "$global/profile.md" ]; then
  cp "$global/profile.md" "$backup/" 2>/dev/null || failed "the profile"
  rm "$global/profile.md"
  echo "Profile backed up to $backup/profile.md and removed."
fi
echo "Run /stickshift:start to begin again."
