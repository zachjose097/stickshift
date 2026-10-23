# Shared helpers for the Stickshift hooks and scripts. Written for macOS bash 3.2.

# Print the project root for directory $1: the git top level, or the directory itself.
ss_root() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || (cd "$1" && pwd -P)
}

# Print $1 as an absolute, symlink-resolved path, resolving relative paths against $2.
# Works for files that don't exist yet by resolving the deepest existing parent.
ss_abs() {
  local p=$1 d rest r
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
  printf '%s/%s\n' "${r%/}" "$rest"
}
