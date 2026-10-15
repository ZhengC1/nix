---
description: Close unused tmux sessions, git worktrees, and idle Claude chats — survey first, confirm, then clean.
argument-hint: "[--dry-run] [--yes] [--delete-chats] [--older-than <hours>] [--manifests-only]"
---

# Workspace cleanup

Reclaim the leftovers from finished work: `claude-` tmux sessions nobody is attached to,
git worktrees whose work has landed, and Claude chats that have gone idle.

`$ARGUMENTS`

The routines (`/pr-triage`, `/review-open-prs`, `/adversarial-review`) already reap their own
leftovers — each declares what it creates to `~/.claude/scripts/claude-sweep.sh`, cleans up on
exit, and sweeps what earlier runs abandoned once it is 24 hours old. This command is the wider,
manual pass: everything those sweeps refuse to touch (dirty worktrees, unpushed branches, chats)
plus the leftovers of work that never went through a routine at all.

Default is `--older-than 4` hours of inactivity. `--dry-run` surveys and reports without
touching anything. `--yes` skips the confirmation step. `--delete-chats` permanently deletes
chats instead of archiving them — never assume this; archive unless I passed it.

## Never touch

- **tmux sessions without a `claude-` prefix.** Those are mine. Not even to rename.
- **The current session**, its worktree, its branch, or the tmux session it is running in.
- **A worktree with uncommitted changes** (`git status --porcelain` non-empty), or one whose
  branch holds commits that exist on no other ref. Report it and move on.
- **A running Claude session** (`isRunning: true`), or a pinned one.
- The primary checkout (`git worktree list`'s first entry).

## 1. Survey

```bash
tmux list-sessions -F '#{session_name}|attached=#{session_attached}|idle_s=#{t/-:session_activity}' 2>/dev/null
git worktree list --porcelain
```

For each worktree, record branch, dirty count, and whether its branch is reachable from
`origin/main` or from any remote branch:

```bash
git -C <wt> status --porcelain | wc -l
git -C <wt> rev-list --count origin/main..HEAD
git branch -r --contains HEAD
```

List Claude chats with `mcp__ccd_session_mgmt__list_sessions`.

Ask the routines what they know they left behind, and why they would not remove it themselves:

```bash
~/.claude/scripts/claude-sweep.sh stale --older-than <hours>   # read-only
~/.claude/scripts/claude-sweep.sh sweep --older-than <hours> --dry-run
```

A `STALE` line names the run that created the artifact; a `KEPT` line from `--dry-run` says
exactly why the automatic sweep will never take it — that reason is the row's `state` in the table
below, and it is usually the thing I actually need to decide. Under `--manifests-only`, report
these and nothing else.

Correlate the three: a chat's `cwd` is usually a worktree, and archiving the chat removes that
worktree for you. So resolve chats first, then clean up whatever worktrees are left orphaned.

## 2. Classify and report

Print one table with a row per item and a verdict:

| kind | name | state | verdict |
|------|------|-------|---------|

`verdict` is `archive`, `kill`, `remove`, or `keep — <one-line reason>`. Every `keep` needs its
reason stated; silent omissions are how work gets lost. Say the totals in one line.

## 3. Confirm

Unless `--dry-run` or `--yes`, stop here and ask me to approve the list. One question, not one
per item. If I trim the list, act only on what survives.

## 4. Act

In this order, so worktree removal is mostly handled for you:

1. **Chats** — `archive_session` per chat (reversible; also stops the process and cleans its
   worktree). With `--delete-chats`, `delete_session` instead, one call for the whole batch.
   Never pass `force_worktree_cleanup`.
2. **Registered leftovers** — `~/.claude/scripts/claude-sweep.sh sweep --older-than <hours>`, so
   the routines' own manifests are consumed and retired rather than left to grow.
3. **Worktrees still present** — `git worktree remove <path>`, then `git worktree prune`. If
   removal is refused, report the refusal rather than forcing it.
4. **tmux** — `tmux kill-session -t <name>` for each `claude-`prefixed session with
   `attached=0` and idle beyond the threshold.

## 5. Report

What was archived, removed, killed, and what was kept and why. If anything failed, name the
item and the error — a cleanup that half-ran and reported success is worse than no cleanup.
