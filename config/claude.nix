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
  };
in
{
  # Declarative ~/.claude/settings.json. Like the other generated dotfiles
  # (gitconfig, .tmux.conf) this is a read-only symlink into the Nix store —
  # edit this module and re-run `make home`, not the file in $HOME.
  home.file.".claude/settings.json".text =
    lib.generators.toJSON { } settings;
}
