{ lib, config, ... }:

let
  claudeHome = "${config.home.homeDirectory}/.claude";

  # PreToolUse(Bash) guard. Claude may only create tmux sessions/windows whose
  # name starts with "claude-", so an unprefixed session is always the user's
  # own and Claude knows not to touch it. See dotfiles/claude/CLAUDE.md.
  tmuxPrefixHook = "${claudeHome}/hooks/tmux-claude-prefix.sh";

  # PreToolUse(Bash) auto-approver. dotfiles/claude/instructions.md tells Claude
  # to keep the tmux window name in sync with what it is working on; without
  # this every rename would stop for a permission prompt, which defeats the
  # point. Scoped to exactly `tmux rename-window` — everything else falls
  # through to the normal permission flow.
  tmuxRenameHook = "${claudeHome}/hooks/approve-tmux-rename.py";

  # Claude Code reads env vars from settings.json's `env` block on startup.
  # CLAUDE_CODE_DISABLE_MOUSE_CLICKS turns off click / click-drag / click-to-
  # expand handling (so the terminal's native text selection works again) while
  # leaving mouse-wheel scrolling intact. Only takes effect in the fullscreen
  # renderer (`/tui fullscreen` or CLAUDE_CODE_NO_FLICKER=1).
  settings = {
    env = {
      CLAUDE_CODE_DISABLE_MOUSE_CLICKS = "1";
    };
    # Status line shown at the bottom of the Claude Code TUI, rendered by
    # oh-my-posh's built-in `claude` segment.
    statusLine = {
      type = "command";
      command = "oh-my-posh claude";
      padding = 0;
    };
    hooks = {
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = tmuxPrefixHook;
              timeout = 5;
              statusMessage = "Checking tmux session name";
            }
            {
              type = "command";
              command = tmuxRenameHook;
              timeout = 5;
              statusMessage = "Auto-approving tmux rename-window";
            }
          ];
        }
      ];
      # Fire a native macOS notification (with sound) when Claude finishes
      # responding. The Stop hook runs when the turn ends (including /clear,
      # resume, and compact). `|| true` keeps a failed osascript from surfacing
      # as a hook error in the TUI.
      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "osascript -e 'display notification \"Claude has finished responding\" with title \"Claude Code\" sound name \"Glass\"' 2>/dev/null || true";
            }
          ];
        }
      ];
    };
  };
in
{
  # Declarative ~/.claude. Like the other generated dotfiles (gitconfig,
  # .tmux.conf) these are read-only symlinks into the Nix store — edit this
  # module or the files under dotfiles/claude/ and re-run `make home`, not the
  # copies in $HOME.
  #
  # Deliberately per-file rather than a wholesale symlink of ~/.claude: Claude
  # Code writes its own state there (sessions/, projects/, history.jsonl,
  # plugins/), which must stay mutable.
  home.file = {
    ".claude/settings.json".text = lib.generators.toJSON { } settings;

    # Global preferences injected into every session's context. instructions.md
    # is concatenated in rather than kept separate: Claude Code only auto-loads
    # CLAUDE.md, so a standalone ~/.claude/instructions.md would never be read.
    # It is still linked below so the path exists as its own file.
    ".claude/CLAUDE.md".text =
      builtins.readFile ../dotfiles/claude/CLAUDE.md
      + "\n"
      + builtins.readFile ../dotfiles/claude/instructions.md;

    ".claude/instructions.md".source = ../dotfiles/claude/instructions.md;

    # Personal slash commands. Linked per-file rather than symlinking the whole
    # commands/ directory, so a plain file dropped in ~/.claude/commands by hand
    # still works (same reason neovim is linked per-file).
    ".claude/commands/pr-triage.md".source =
      ../dotfiles/claude/commands/pr-triage.md;
    ".claude/commands/review-open-prs.md".source =
      ../dotfiles/claude/commands/review-open-prs.md;

    ".claude/skills/grill-me/SKILL.md".source =
      ../dotfiles/claude/skills/grill-me/SKILL.md;

    # Azure DevOps helpers the slash commands shell out to by absolute path.
    ".claude/scripts/ado-pr.sh" = {
      source = ../dotfiles/claude/scripts/ado-pr.sh;
      executable = true;
    };
    ".claude/scripts/ado-review.sh" = {
      source = ../dotfiles/claude/scripts/ado-review.sh;
      executable = true;
    };
    ".claude/scripts/pr-test-evidence.sh" = {
      source = ../dotfiles/claude/scripts/pr-test-evidence.sh;
      executable = true;
    };

    ".claude/hooks/tmux-claude-prefix.sh" = {
      source = ../dotfiles/claude/hooks/tmux-claude-prefix.sh;
      executable = true;
    };
    ".claude/hooks/approve-tmux-rename.py" = {
      source = ../dotfiles/claude/hooks/approve-tmux-rename.py;
      executable = true;
    };
  };
}
