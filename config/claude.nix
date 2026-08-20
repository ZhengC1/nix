{ lib, ... }:

let
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
    # Fire a native macOS notification (with sound) when Claude finishes
    # responding. The Stop hook runs when the turn ends (including /clear,
    # resume, and compact). `|| true` keeps a failed osascript from surfacing
    # as a hook error in the TUI.
    hooks = {
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
  # Declarative ~/.claude/settings.json. Like the other generated dotfiles
  # (gitconfig, .tmux.conf) this is a read-only symlink into the Nix store —
  # edit this module and re-run `make home`, not the file in $HOME.
  home.file.".claude/settings.json".text =
    lib.generators.toJSON { } settings;
}
