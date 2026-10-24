# Shared helpers for the Stickshift hooks and scripts. Written for macOS bash 3.2.

# Print the project root for directory $1: the git top level, or the directory itself.
ss_root() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || (cd "$1" && pwd -P)
}

# Print $1 as an absolute, symlink-resolved path, resolving relative paths against $2.
# Works for files that don't exist yet by resolving the deepest existing parent.
# A symlink is followed to its target, so a link in .stickshift/ can't lead an edit out.
ss_abs() {
  local p=$1 d rest r depth=${3:-0}
  case "$p" in
    /*) ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
    *) p="$2/$p" ;;
  esac
  d=$(dirname "$p")
  rest=$(basename "$p")
  while [ ! -d "$d" ]; do
    rest="$(basename "$d")/$rest"
    d=$(dirname "$d")
  done
  r=$(cd "$d" && pwd -P)
  p="${r%/}/$rest"
  if [ -L "$p" ] && [ "$depth" -lt 8 ]; then
    ss_abs "$(readlink "$p")" "${r%/}" $((depth + 1))
    return
  fi
  printf '%s\n' "$p"
}

# The hooks read their input with jq. Print why Stickshift can't work without it.
ss_no_jq() {
  command -v jq >/dev/null 2>&1 && return 1
  echo "Stickshift: jq isn't installed, so the hooks can't read what the AI is doing and the edit lock can't work. Ask the user to install jq (macOS: brew install jq; Debian/Ubuntu: sudo apt install jq) and restart."
}
