{ pkgs, ... }:

{
  # Install JetBrainsMono Nerd Font on every machine so terminals/editors can
  # select it (it ships ligatures + Nerd Font glyphs). Family name to pick in a
  # terminal/editor: "JetBrainsMono Nerd Font".
  home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  # Make packaged fonts discoverable. Required on Linux (fontconfig); on macOS
  # home-manager also links them into ~/Library/Fonts/HomeManager.
  fonts.fontconfig.enable = true;
}
