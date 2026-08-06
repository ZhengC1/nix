{ pkgs, config, ... }:

{
  programs.tmux = {
    enable = true;
  };

  # Install tmux
  home.packages = with pkgs; [
    tmux
  ];

  # Create tmux config file in home directory
  home.file.".tmux.conf" = {
    source = ../dotfiles/.tmux.conf;
  };

  # Clone tpm (tmux plugin manager) to ~/.tmux/plugins/tpm
  home.activation.tmuxPluginManager = config.lib.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d ~/.tmux/plugins/tpm ]; then
      mkdir -p ~/.tmux/plugins
      ${pkgs.git}/bin/git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    fi
  '';
}
