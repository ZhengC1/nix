#!/usr/bin/env bash
# Leftover reaper for the /pr-triage, /review-open-prs, /adversarial-review and
# /cleanup-workspaces routines.
#
# The routines create worktrees, scratch dirs and tmux sessions, and they are
# supposed to remove them when they finish. They often don't: a run that errors,
# or that I interrupt halfway, never reaches its cleanup phase, and the leftovers
# sit there for weeks. So a run declares what it creates as it creates it, and
# every later run reaps what earlier runs abandoned.
#
#   claude-sweep.sh begin <routine> [run-id]   open a manifest, print the run id
#   claude-sweep.sh register <kind> <value>    record an artifact in that manifest
#   claude-sweep.sh finish                     clean up THIS run's artifacts
#   claude-sweep.sh stale [--older-than <h>]   what earlier runs abandoned
#   claude-sweep.sh sweep  [--older-than <h>]  clean up what is safely reapable
#   claude-sweep.sh help                       this header
#
# Kinds: worktree | scratch | tmux | session.
#
# `register`/`finish` take --run <id>, or read CLAUDE_SWEEP_RUN from the env
# (what `begin` prints; export it once per run).
#
# Sessions are Claude chats and cannot be archived from a shell -- they are only
# ever REPORTED, for the caller to archive with mcp__ccd_session_mgmt__
# archive_session. Everything else this script removes itself.
#
# Nothing is forced, ever. A worktree that is dirty, that holds commits on no
# remote, or that someone is standing in is KEPT with a reason, and so is a tmux
# session that is attached or not `claude-`prefixed. A half-run cleanup that
# reports success is worse than no cleanup, so every decision is printed:
#
#   REMOVED|KILLED|KEPT|WOULD-REMOVE|SESSION <TAB> kind <TAB> value <TAB> reason
#
# Env: CLAUDE_SWEEP_TTL_HOURS (default 24) -- how old an abandoned artifact must
# be before `stale`/`sweep` will touch it. CLAUDE_SWEEP_STATE_DIR overrides where
# manifests live. --dry-run on finish/sweep prints WOULD-REMOVE and changes
# nothing.

set -euo pipefail

STATE_DIR="${CLAUDE_SWEEP_STATE_DIR:-$HOME/.claude/run-state}"
TTL_HOURS="${CLAUDE_SWEEP_TTL_HOURS:-24}"
DRY_RUN=0

# Worktree names earlier versions of the routines created without ever
# registering them. `stale` pattern-matches these so the back catalogue gets
# reaped too; anything else is left alone unless a manifest claims it.
ORPHAN_GLOBS=('ado-pr-*-review' 'ado-pr-*-triage')

die() { printf '%s\n' "$*" >&2; exit 2; }
now() { date +%s; }
say() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"; }

manifest_for() {
  local run="$1"
  printf '%s/%s.tsv' "$STATE_DIR" "$run"
}

resolve_run() {
  local run="${1:-${CLAUDE_SWEEP_RUN:-}}"
  [ -n "$run" ] || die "no run id: pass --run <id> or export CLAUDE_SWEEP_RUN (see \`begin\`)"
  printf '%s' "$run"
}

# Main checkout of the repo containing $1 (a worktree path), or empty.
main_checkout() {
  local wt="$1" common
  common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  dirname "$common"
}

cmd_begin() {
  local routine="${1:-}" run="${2:-}"
  [ -n "$routine" ] || die "usage: claude-sweep.sh begin <routine> [run-id]"
  [ -n "$run" ] || run="${routine}-$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$STATE_DIR"
  local m
  m=$(manifest_for "$run")
  [ -f "$m" ] || printf '# routine=%s started=%s\n' "$routine" "$(now)" >"$m"
  printf '%s\n' "$run"
}

cmd_register() {
  local kind="" value="" run=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --run) run="$2"; shift 2 ;;
      *) if [ -z "$kind" ]; then kind="$1"; else value="$1"; fi; shift ;;
    esac
  done
  [ -n "$kind" ] && [ -n "$value" ] || die "usage: claude-sweep.sh register <kind> <value> [--run <id>]"
  case "$kind" in
    worktree|scratch|tmux|session) ;;
    *) die "unknown kind '$kind' (worktree|scratch|tmux|session)" ;;
  esac
  run=$(resolve_run "$run")
  local m
  m=$(manifest_for "$run")
  [ -f "$m" ] || die "no manifest for run '$run' -- call \`begin\` first"
  # Idempotent: re-registering the same artifact (a reused worktree, a retried
  # phase) must not queue it for removal twice.
  grep -qF "$(printf '%s\t%s' "$kind" "$value")" "$m" || printf '%s\t%s\t%s\n' "$kind" "$value" "$(now)" >>"$m"
}

# --- removal, one kind per function; each prints exactly one line ------------

reap_worktree() {
  local wt="$1" main branch porcelain remotes
  if [ ! -d "$wt" ]; then say REMOVED worktree "$wt" "already gone"; return; fi
  case "$wt" in
    */.claude/worktrees/*) ;;
    *) say KEPT worktree "$wt" "not under .claude/worktrees -- not mine to remove"; return ;;
  esac
  case "$PWD/" in
    "$wt"/*) say KEPT worktree "$wt" "the current run is standing in it"; return ;;
  esac
  if ! main=$(main_checkout "$wt"); then
    say KEPT worktree "$wt" "not a git worktree -- left for a human"; return
  fi
  if [ "$main" = "$wt" ]; then say KEPT worktree "$wt" "primary checkout"; return; fi
  porcelain=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$porcelain" != "0" ]; then
    say KEPT worktree "$wt" "$porcelain uncommitted change(s)"; return
  fi
  # Commits that exist on no remote branch die with the worktree, so they stop it.
  remotes=$(git -C "$wt" branch -r --contains HEAD 2>/dev/null | wc -l | tr -d ' ')
  if [ "$remotes" = "0" ]; then
    branch=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
    say KEPT worktree "$wt" "commits on no remote (branch $branch) -- would lose work"; return
  fi
  if [ "$DRY_RUN" = "1" ]; then say WOULD-REMOVE worktree "$wt" "clean, pushed"; return; fi
  if git -C "$main" worktree remove "$wt" >/dev/null 2>&1; then
    git -C "$main" worktree prune >/dev/null 2>&1 || true
    say REMOVED worktree "$wt" "clean, pushed"
  else
    say KEPT worktree "$wt" "git refused to remove it"
  fi
}

reap_scratch() {
  local dir="$1"
  # Root guard before the existence check, so a path this script would never
  # delete is never reported as deleted. An `rm -rf` driven by a manifest line
  # is exactly the kind of thing that eats a home directory.
  case "$dir" in
    /private/tmp/claude-*|/tmp/claude-*|"$HOME"/.claude/scratch/*|"${TMPDIR:-/nonexistent}"*) ;;
    *) say KEPT scratch "$dir" "outside every scratch root -- refusing to rm -rf"; return ;;
  esac
  if [ ! -e "$dir" ]; then say REMOVED scratch "$dir" "already gone"; return; fi
  if [ "$DRY_RUN" = "1" ]; then say WOULD-REMOVE scratch "$dir" "scratch dir"; return; fi
  rm -rf -- "$dir" && say REMOVED scratch "$dir" "scratch dir"
}

reap_tmux() {
  local name="$1" attached idle_for
  case "$name" in
    claude-*) ;;
    *) say KEPT tmux "$name" "no claude- prefix -- it is the user's"; return ;;
  esac
  if ! tmux has-session -t "=$name" 2>/dev/null; then
    say KILLED tmux "$name" "already gone"; return
  fi
  attached=$(tmux display-message -p -t "=$name" '#{session_attached}' 2>/dev/null || echo 0)
  if [ "${attached:-0}" != "0" ]; then say KEPT tmux "$name" "attached"; return; fi
  if [ -n "${TTL_SECONDS:-}" ]; then
    local activity
    activity=$(tmux display-message -p -t "=$name" '#{session_activity}' 2>/dev/null || echo 0)
    idle_for=$(( $(now) - activity ))
    if [ "$idle_for" -lt "$TTL_SECONDS" ]; then
      say KEPT tmux "$name" "active $idle_for s ago, under the TTL"; return
    fi
  fi
  if [ "$DRY_RUN" = "1" ]; then say WOULD-REMOVE tmux "$name" "detached"; return; fi
  tmux kill-session -t "=$name" 2>/dev/null && say KILLED tmux "$name" "detached" \
    || say KEPT tmux "$name" "kill-session failed"
}

reap_line() {
  local kind="$1" value="$2"
  case "$kind" in
    worktree) reap_worktree "$value" ;;
    scratch)  reap_scratch  "$value" ;;
    tmux)     reap_tmux     "$value" ;;
    session)  say SESSION session "$value" "archive with mcp__ccd_session_mgmt__archive_session" ;;
  esac
}

# Replays a manifest, newest entries first, and rewrites it with whatever
# survived. An empty manifest is deleted; a manifest with residue stays, so the
# next run's `sweep` picks the residue up again.
reap_manifest() {
  local m="$1" keep_worktrees="${2:-0}" drop_sessions="${3:-0}" kind value residue out
  out=$(mktemp)
  head -1 "$m" >"$out"
  while IFS=$'\t' read -r kind value ts; do
    case "$kind" in ''|'#'*) continue ;; esac
    # Kept entries carry their ORIGINAL timestamp forward, so `stale` keeps
    # reporting a leftover's real age instead of resetting it every sweep.
    if [ "$keep_worktrees" = "1" ] && [ "$kind" = "worktree" ]; then
      say KEPT worktree "$value" "--keep-worktrees"
      printf '%s\t%s\t%s\n' "$kind" "$value" "$ts" >>"$out"
      continue
    fi
    local line
    line=$(reap_line "$kind" "$value")
    printf '%s\n' "$line"
    case "$line" in
      # A session reported by `finish` stays, so that a run which forgot to
      # archive it is caught by the next run's `sweep`; by the time `sweep`
      # reports it the chat is a day idle, and it is dropped either way.
      SESSION*) [ "$drop_sessions" = "1" ] || printf '%s\t%s\t%s\n' "$kind" "$value" "$ts" >>"$out" ;;
      KEPT*|WOULD-REMOVE*) printf '%s\t%s\t%s\n' "$kind" "$value" "$ts" >>"$out" ;;
    esac
  done < <(tail -n +2 "$m")
  residue=$(tail -n +2 "$out" | wc -l | tr -d ' ')
  if [ "$DRY_RUN" = "1" ]; then rm -f "$out"; return; fi
  if [ "$residue" = "0" ]; then rm -f "$m" "$out"; else mv "$out" "$m"; fi
}

cmd_finish() {
  local run="" keep_worktrees=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --run) run="$2"; shift 2 ;;
      --keep-worktrees) keep_worktrees=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      *) die "finish: unknown argument '$1'" ;;
    esac
  done
  run=$(resolve_run "$run")
  local m
  m=$(manifest_for "$run")
  if [ ! -f "$m" ]; then say KEPT run "$run" "no manifest -- nothing was registered"; return; fi
  reap_manifest "$m" "$keep_worktrees"
}

# Worktrees matching ORPHAN_GLOBS that no manifest claims, in the repo containing
# $PWD. mtime stands in for "last touched" -- good enough to tell yesterday's
# abandoned review from the one running right now.
orphan_worktrees() {
  local main wt base age
  main=$(main_checkout "$PWD" 2>/dev/null) || return 0
  [ -d "$main/.claude/worktrees" ] || return 0
  for wt in "$main"/.claude/worktrees/*/; do
    [ -d "$wt" ] || continue
    wt="${wt%/}"
    base=$(basename "$wt")
    local matched=0 g
    for g in "${ORPHAN_GLOBS[@]}"; do
      # shellcheck disable=SC2254
      case "$base" in $g) matched=1 ;; esac
    done
    [ "$matched" = "1" ] || continue
    grep -qF "$wt" "$STATE_DIR"/*.tsv 2>/dev/null && continue
    age=$(( $(now) - $(stat -f %m "$wt" 2>/dev/null || stat -c %Y "$wt") ))
    [ "$age" -ge "$TTL_SECONDS" ] || continue
    printf '%s\n' "$wt"
  done
}

# Manifests not written to for TTL hours. The current run's own manifest is
# never stale -- a routine must not reap itself mid-flight.
stale_manifests() {
  local mine="${CLAUDE_SWEEP_RUN:-}" m age
  mkdir -p "$STATE_DIR"
  for m in "$STATE_DIR"/*.tsv; do
    [ -f "$m" ] || continue
    [ "$(basename "$m" .tsv)" = "$mine" ] && continue
    age=$(( $(now) - $(stat -f %m "$m" 2>/dev/null || stat -c %Y "$m") ))
    [ "$age" -ge "$TTL_SECONDS" ] || continue
    printf '%s\n' "$m"
  done
}

# Report-only: what `sweep` would go after, without touching anything.
cmd_stale() {
  local m run kind value ts age wt
  for m in $(stale_manifests); do
    run=$(basename "$m" .tsv)
    while IFS=$'\t' read -r kind value ts; do
      case "$kind" in ''|'#'*) continue ;; esac
      age=$(( ( $(now) - ts ) / 3600 ))
      say STALE "$kind" "$value" "run $run, ${age}h old"
    done < <(tail -n +2 "$m")
  done
  for wt in $(orphan_worktrees); do
    say STALE worktree "$wt" "no manifest -- named like a routine worktree"
  done
}

cmd_sweep() {
  local m wt main entry
  # A worktree whose directory someone deleted by hand stays registered in the
  # repo forever and shows up in every `git worktree list`. Prune only drops
  # registrations whose directory is already gone, so it can never lose work.
  if main=$(main_checkout "$PWD" 2>/dev/null); then
    while read -r entry; do
      [ -n "$entry" ] || continue
      if [ "$DRY_RUN" = "1" ]; then
        say WOULD-REMOVE registration "$entry" "directory is gone"
      else
        say REMOVED registration "$entry" "directory is gone"
      fi
    done < <(git -C "$main" worktree prune -n -v 2>&1 1>/dev/null | sed -n 's|^Removing worktrees/\([^:]*\):.*|\1|p')
    [ "$DRY_RUN" = "1" ] || git -C "$main" worktree prune 2>/dev/null || true
  fi
  for m in $(stale_manifests); do
    reap_manifest "$m" 0 1
  done
  for wt in $(orphan_worktrees); do
    reap_worktree "$wt"
  done
}

main() {
  local sub="${1:-help}"; shift || true
  # --older-than is shared by stale/sweep; strip it before dispatch.
  local args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --older-than) TTL_HOURS="$2"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      *) args+=("$1"); shift ;;
    esac
  done
  TTL_SECONDS=$(( TTL_HOURS * 3600 ))
  export TTL_SECONDS
  case "$sub" in
    begin)    cmd_begin "${args[@]+"${args[@]}"}" ;;
    register) cmd_register "${args[@]+"${args[@]}"}" ;;
    finish)   cmd_finish "${args[@]+"${args[@]}"}" ;;
    stale)    cmd_stale ;;
    sweep)    cmd_sweep ;;
    help|-h|--help) sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d' ;;
    *) die "unknown subcommand '$sub' -- try \`claude-sweep.sh help\`" ;;
  esac
}

main "$@"
