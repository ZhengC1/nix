# Global preferences

## Worktrees

- When creating a git worktree, always give it a readable, task-derived name — pass an explicit `name` to the worktree tool; never let it fall back to a random generated codename (e.g. `peaceful-tu-fb0ada`).
- The name should tell me at a glance what the worktree is for: a short kebab-case slug from the task, e.g. `fix-broadcast-recipient-names` or `terraform-dev-init`, not the conversation's opening topic if the work has since moved on.

## tmux sessions

- Never create an unmarked tmux session. Always prefix the session name with `claude-` so I can tell at a glance which sessions are yours and not mine: `tmux new-session -d -s claude-<task-slug>`.
- Same for windows/panes you create inside an existing session — name them `claude-<what-it-runs>` (`tmux new-window -n claude-tests`).
- Use a task-derived slug after the prefix, same rule as worktrees: `claude-build-watch`, not `claude-1`.
- Tell me the session name when you start one, and don't kill or attach to sessions that lack the `claude-` prefix — those are mine.
