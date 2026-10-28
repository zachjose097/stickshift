# Shared helpers for the Stickshift hooks and scripts. Written for macOS bash 3.2.

# On Windows (Git Bash), print $1 in the /c/... form, since paths arrive as C:\...,
# C:/... and /c/... and must compare equal. Elsewhere print it unchanged.
ss_unix() {
  case "$1" in
    [A-Za-z]:* | *\\*)
      if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; return; fi ;;
  esac
  printf '%s\n' "$1"
}

# Print the project root for directory $1: the git top level, or the directory itself.
ss_root() {
  local d r
  d=$(ss_unix "$1")
  r=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || r=$d
  (cd "$(ss_unix "$r")" && pwd -P)
}

# Print $1 as an absolute, symlink-resolved path, resolving relative paths against $2.
# Works for files that don't exist yet by resolving the deepest existing parent.
# A symlink is followed to its target, so a link in .stickshift/ can't lead an edit out.
ss_abs() {
  local p d rest r depth=${3:-0}
  p=$(ss_unix "$1")
  case "$p" in
    /*) ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
    *) p="$(ss_unix "$2")/$p" ;;
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

# jq from winget ends its output with a Windows line ending, which would stick to
# values like cwd and make the guard allow everything. Strip it from all output.
jq() { command jq "$@" | tr -d '\r'; }

# The hooks read their input with jq. Print why Stickshift can't work without it.
ss_no_jq() {
  type -P jq >/dev/null 2>&1 && return 1
  echo "Stickshift: jq isn't installed, so the hooks can't read what the AI is doing and the edit lock can't work. Ask the user to install jq (macOS: brew install jq; Debian/Ubuntu: sudo apt install jq) and restart."
}
