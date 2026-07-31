{ pkgs, config, ... }:

{
  programs.tmux = {
    enable = true;
  };

  # Install tmux and tpm
  home.packages = with pkgs; [
    tmux
  ];

  # Create tmux config file in home directory
  home.file.".tmux.conf" = {
    source = ../dotfiles/.tmux.conf;
  };
}
