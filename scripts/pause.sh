#!/bin/bash
# Run by /stickshift:pause. Switches the project to automatic mode.

here=$(cd "$(dirname "$0")" && pwd)
. "$here/../hooks/lib.sh"

state="$(ss_root "$PWD")/.stickshift"
if [ ! -d "$state/.hook" ]; then
  echo "Stickshift isn't started in this project. Nothing to pause."
  exit 0
fi
echo auto > "$state/.hook/mode"
echo "Stickshift: paused (mode: auto). The edit lock is off until /stickshift:start."
