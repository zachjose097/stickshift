#!/bin/bash
# PreToolUse hook. In manual mode the model may not edit project files, except
# notes in .stickshift/ and paths the user unlocked in their latest message.
# Shell writes are caught by pattern, so this is a guardrail, not a sandbox.

. "$(dirname "$0")/lib.sh"

# Without jq the input can't be read. Fail closed in a Stickshift project.
if msg=$(ss_no_jq); then
  [ -d "$(ss_root "$PWD")/.stickshift" ] || exit 0
  echo "$msg" >&2
  exit 2
fi

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
SHELL_MSG="Stickshift manual mode: editing files from the shell still counts as writing the user's code. Help them make the change instead, or they can unlock the file."
GIT_MSG="Stickshift manual mode: this git command can overwrite or discard the user's uncommitted code. Tell them the command and let them run it."

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
    "$root") rel=. ;;
    "$root/"*) rel=${p#"$root/"} ;;
    *) return 0 ;;   # Outside the project, e.g. the global profile.
  esac
  for f in unlocks delegated; do
    [ -f "$state/.hook/$f" ] || continue
    while IFS= read -r u; do
      [ -n "$u" ] || continue
      [ "$u" = . ] || [ "$u" = "$rel" ] && return 0
      case "$rel" in "${u%/}/"*) return 0 ;; esac
    done < "$state/.hook/$f"
  done
  deny "Stickshift manual mode: the user writes the project code, so you can't edit $rel. Help through the hint ladder instead (question, concept, pseudocode, unrelated example). If the user wants you to write it, they can start their next message with: unlock $rel (for one request) or delegate $rel (for the whole feature, replacing any current delegation)"
}

# Check every file a Codex patch ($1) adds, updates, deletes or moves to.
check_patch() {
  local paths p
  paths=$(sed -nE 's/^\*\*\* (Add File|Update File|Delete File|Move to): *(.*[^[:space:]])[[:space:]]*$/\2/p' <<<"$1")
  while IFS= read -r p; do
    [ -n "$p" ] && check_path "$p"
  done <<<"$paths"
}

# Deny removing or moving path $1 if it is the notes folder or contains it:
# without .stickshift/ the lock is off.
check_removal() {
  local p
  p=$(ss_abs "$1" "$cwd")
  case "$state/" in
    "${p%/}/"*) deny "Stickshift: that would delete or move .stickshift/, which turns Stickshift off. The user can run /stickshift:reset for that." ;;
  esac
}

# Check the file operands of the commands in shell command $1 that copy, move,
# delete or edit files in place.
check_shell_files() {
  local seg words i n name w sub inplace last
  set -f
  while IFS= read -r seg; do
    read -ra words <<<"$seg"
    n=${#words[@]} i=0
    while [ $i -lt $n ]; do   # Skip VAR=value and wrappers like sudo.
      case "${words[$i]}" in *=* | sudo | command | env | exec | nohup | time) i=$((i + 1)) ;; *) break ;; esac
    done
    [ $i -lt $n ] || continue
    name=${words[$i]##*/}
    case "$name" in
      rm | rmdir | mv | unlink | touch | truncate)
        for w in "${words[@]:$((i + 1))}"; do
          case "$w" in -* | *'>'* | *'<'*) continue ;; esac
          case "$name" in rm | rmdir | mv | unlink) check_removal "$w" ;; esac
          check_path "$w"
        done
        ;;
      cp | ln | install)
        last=""   # Only the destination, the last operand, is written.
        for w in "${words[@]:$((i + 1))}"; do
          case "$w" in -* | *'>'* | *'<'*) ;; *) last=$w ;; esac
        done
        [ -n "$last" ] && check_path "$last"
        ;;
      dd)
        for w in "${words[@]:$((i + 1))}"; do
          case "$w" in of=*) check_path "${w#of=}" ;; esac
        done
        ;;
      sed | perl)
        inplace=""
        for w in "${words[@]:$((i + 1))}"; do
          case "$w" in --in-place* | -i* | -[a-zA-Z]*i*) inplace=1 ;; esac
        done
        [ -n "$inplace" ] || continue
        # The script argument isn't a file, so check only operands that exist.
        for w in "${words[@]:$((i + 1))}"; do
          case "$w" in -*) continue ;; esac
          [ -e "$(ss_abs "$w" "$cwd")" ] && check_path "$w"
        done
        ;;
      patch) [ "$mode" = manual ] && deny "$SHELL_MSG" ;;
      git)
        [ "$mode" = manual ] || continue
        sub="" i=$((i + 1))
        while [ $i -lt $n ]; do
          case "${words[$i]}" in -C | -c) i=$((i + 2)) ;; -*) i=$((i + 1)) ;; *) sub=${words[$i]}; break ;; esac
        done
        case "$sub" in
          apply) deny "$SHELL_MSG" ;;
          checkout | restore | clean) deny "$GIT_MSG" ;;
          reset) case " ${words[*]} " in *' --hard '* | *' --merge '* | *' --keep '*) deny "$GIT_MSG" ;; esac ;;
          stash) case "${words[$((i + 1))]}" in list | show) ;; *) deny "$GIT_MSG" ;; esac ;;
        esac
        ;;
    esac
  done <<<"$(tr ';&|()`' '\n' <<<"$1" | tr -d "\"'")"
  set +f
}

case "$tool" in
  Write | Edit | MultiEdit | NotebookEdit)
    path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
    [ -n "$path" ] && check_path "$path"
    ;;
  apply_patch)
    # Codex sends file edits as one patch in tool_input.command.
    check_patch "$(jq -r '.tool_input.command // empty' <<<"$input")"
    ;;
  Bash)
    cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
    case "$cmd" in
      *.stickshift/.hook*)
        # Plain one-line reads are fine (Codex reads files through the shell); anything else could write there.
        case "$cmd" in *$'\n'*) deny "$HOOK_MSG" ;; esac
        grep -Eq '^[[:space:]]*(cat|head|tail|grep|wc|ls)[[:space:]][^;&|<>`$()]*$' <<<"$cmd" || deny "$HOOK_MSG"
        ;;
    esac

    # Pausing and resetting turn the lock off, so only the user starts them. In Codex
    # the model runs the scripts, allowed for the message in which the user asked.
    for s in pause reset; do
      case "$cmd" in
        *"$s.sh"*)
          [ "$(cat "$state/.hook/command" 2>/dev/null)" = "$s" ] ||
            deny "Stickshift: only the user can run $s. Run $s.sh only when their own message asks for it, e.g. \"stickshift $s\"."
          ;;
      esac
    done

    # Codex can also run apply_patch from the shell with the patch in a heredoc.
    # Check its files, then drop the patch body so its lines don't look like commands.
    case "$cmd" in
      *'*** Begin Patch'*)
        check_patch "$cmd"
        cmd=$(sed '/^\*\*\* Begin Patch/,/^\*\*\* End Patch/d' <<<"$cmd")
        ;;
    esac

    check_shell_files "$cmd"
    [ "$mode" = manual ] || exit 0

    # Redirect and tee targets.
    targets=$(grep -oE '(>[>|]?|tee([[:space:]]+-a)?)[[:space:]]*[^[:space:];&|<>()]+' <<<"$cmd" \
      | sed -E 's/^(>[>|]?|tee([[:space:]]+-a)?)[[:space:]]*//' | tr -d "\"'")
    while IFS= read -r t; do
      case "$t" in '' | /dev/* | '&'* | '='* | [0-9]) continue ;; esac
      check_path "$t"
    done <<<"$targets"
    ;;
esac
exit 0
