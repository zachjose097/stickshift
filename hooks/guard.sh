#!/bin/bash
# PreToolUse hook. In manual mode the model may not edit project files, except
# notes in .stickshift/ and paths the user unlocked in their latest message.
# Shell writes are caught by pattern, so this is a guardrail, not a sandbox.

. "$(dirname "$0")/lib.sh"

input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
root=$(ss_root "$cwd")
state="$root/.stickshift"
[ -d "$state" ] || exit 0   # Stickshift isn't started in this project.

mode=$(cat "$state/.hook/mode" 2>/dev/null || echo manual)

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

HOOK_MSG="Stickshift: .stickshift/.hook/ is written only by the plugin's hooks, so that only the user can unlock files or change modes. Leave it alone."

# Deny the call unless the model may write to path $1.
check_path() {
  local p rel u
  p=$(ss_abs "$1" "$cwd")
  case "$p" in
    "$state/.hook" | "$state/.hook/"*) deny "$HOOK_MSG" ;;
  esac
  [ "$mode" = manual ] || return 0
  case "$p" in
    "$state/"*) return 0 ;;
    "$root/"*) ;;
    *) return 0 ;;   # Outside the project, e.g. the global profile.
  esac
  rel=${p#"$root/"}
  if [ -f "$state/.hook/unlocks" ]; then
    while IFS= read -r u; do
      [ -n "$u" ] || continue
      [ "$u" = . ] || [ "$u" = "$rel" ] && return 0
      case "$rel" in "${u%/}/"*) return 0 ;; esac
    done < "$state/.hook/unlocks"
  fi
  deny "Stickshift manual mode: the user writes the project code, so you can't edit $rel. Help through the hint ladder instead (question, concept, pseudocode, unrelated example). If the user wants you to write it, they can start their next message with: unlock $rel"
}

case "$tool" in
  Write | Edit | MultiEdit | NotebookEdit)
    path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
    [ -n "$path" ] && check_path "$path"
    ;;
  Bash)
    cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
    case "$cmd" in *.stickshift/.hook*) deny "$HOOK_MSG" ;; esac
    [ "$mode" = manual ] || exit 0

    # In-place editors are allowed only on notes.
    if grep -Eq '(^|[;&|(][[:space:]]*|[[:space:]])(sed[[:space:]]+(-[a-zA-Z]*i|--in-place)|perl[[:space:]]+-[a-zA-Z]*i|patch|git[[:space:]]+apply)([[:space:]]|$)' <<<"$cmd"; then
      case "$cmd" in
        *.stickshift/*) ;;
        *) deny "Stickshift manual mode: editing files from the shell still counts as writing the user's code. Help them make the change instead, or they can unlock the file." ;;
      esac
    fi

    # Redirect and tee targets.
    targets=$(grep -oE '(>>?|tee([[:space:]]+-a)?)[[:space:]]*[^[:space:];&|<>()]+' <<<"$cmd" \
      | sed -E 's/^(>>?|tee([[:space:]]+-a)?)[[:space:]]*//' | tr -d "\"'")
    while IFS= read -r t; do
      case "$t" in '' | /dev/* | '&'* | '='* | [0-9]) continue ;; esac
      check_path "$t"
    done <<<"$targets"
    ;;
esac
exit 0
