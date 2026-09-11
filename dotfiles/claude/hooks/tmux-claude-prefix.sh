#!/usr/bin/env bash
# PreToolUse(Bash) guard: tmux sessions and windows Claude creates must be named
# with a "claude-" prefix, so unprefixed ones are always the user's own.
set -uo pipefail

PREFIX="claude-"

# Slugs that carry no information about what the session is for. The prefix
# alone is not enough: `claude-1` is as opaque as `1`. Sessions only -- a
# window may be named for the thing it runs (`claude-tests` inside a session
# is informative), but a whole session called `claude-tests` is not.
GENERIC="tmp temp test tests testing debug demo check session sessions sess work working run running job jobs task tasks misc stuff scratch shell term terminal default new foo bar baz qux thing things sandbox claude agent asdf"

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

  # The prefix is only half the rule: the slug after it has to say what the
  # session/window is for, so it is identifiable weeks later in `tmux ls`.
  slug=${name#"$PREFIX"}
  advice="Use a task-derived slug that says what it runs, e.g. ${PREFIX}build-watch or ${PREFIX}terraform-plan."

  if [[ -z $slug ]]; then
    deny "Blocked: tmux $kind name is the bare prefix '$name' with no slug. $advice"
  elif [[ $slug =~ ^[0-9]+$ ]]; then
    deny "Blocked: tmux $kind name '$name' has a numeric slug, which says nothing about the $kind. $advice"
  elif (( ${#slug} < 3 )); then
    deny "Blocked: tmux $kind slug '$slug' is too short to be descriptive. $advice"
  elif [[ $kind == session ]]; then
    # Strip a trailing counter (claude-tmp-2) before matching, so numbering
    # cannot smuggle a generic slug past the blocklist.
    bare=${slug%-[0-9]}; bare=${bare%-[0-9][0-9]}
    for g in $GENERIC; do
      if [[ $bare == "$g" ]]; then
        deny "Blocked: tmux session slug '$slug' is a generic placeholder, not a task name. $advice"
      fi
    done
  fi
done < <(printf '%s\n' "$cmd" | tr ';|&' '\n')

exit 0
