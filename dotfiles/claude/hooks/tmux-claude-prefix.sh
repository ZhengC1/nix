#!/usr/bin/env bash
# PreToolUse(Bash) guard: tmux sessions and windows Claude creates must be named
# with a "claude-" prefix, so unprefixed ones are always the user's own.
set -uo pipefail

PREFIX="claude-"

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[[ $cmd == *tmux* ]] || exit 0

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# Inspect each shell segment separately so `cd foo && tmux new-session ...` is caught.
while IFS= read -r seg; do
  [[ $seg == *tmux* ]] || continue

  read -ra toks <<<"$seg"

  # Text-handling commands only mention tmux, they don't run it (docs, greps, echoes).
  case ${toks[0]##*/} in
    echo|printf|cat|grep|egrep|rg|sed|awk|head|tail|less|man|jq|comment) continue ;;
  esac

  kind=""
  for t in "${toks[@]}"; do
    case $t in
      new-session|new) kind=session ;;
      new-window|neww) kind=window ;;
    esac
  done
  [[ -n $kind ]] || continue

  # Session names come from -s, window names from -n (both also in bundled/attached
  # forms like `-As name` and `-sname`).
  if [[ $kind == session ]]; then letter=s; else letter=n; fi

  name=""
  for i in "${!toks[@]}"; do
    t=${toks[$i]}
    [[ $t == -* ]] || continue
    if [[ $t =~ ^-[A-Za-z]*${letter}$ ]]; then
      name=${toks[$((i + 1))]:-}
      break
    elif [[ $t =~ ^-[A-Za-z]*${letter}(.+)$ ]]; then
      name=${BASH_REMATCH[1]}
      break
    fi
  done

  name=${name%\"}; name=${name#\"}
  name=${name%\'}; name=${name#\'}

  if [[ -z $name ]]; then
    deny "Blocked: \`tmux $kind\` with no name. Claude's tmux $kind names must start with '$PREFIX' so they are distinguishable from the user's own — pass -$letter ${PREFIX}<task-slug>."
  elif [[ $name != "$PREFIX"* ]]; then
    deny "Blocked: tmux $kind name '$name' does not start with '$PREFIX'. Rename it to '${PREFIX}${name}' (or another ${PREFIX}<task-slug>) — unprefixed tmux $kind names belong to the user."
  fi
done < <(printf '%s\n' "$cmd" | tr ';|&' '\n')

exit 0
