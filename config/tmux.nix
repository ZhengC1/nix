{ pkgs, config, ... }:

{
  # NOTE: programs.tmux is deliberately left off. Enabling it generates
  # ~/.config/tmux/tmux.conf from home-manager's own defaults, which tmux
  # sources *after* ~/.tmux.conf and which therefore silently overrides
  # anything set in dotfiles/.tmux.conf (mouse, default-terminal, escape-time,
  # base-index, mode-keys, ...). Installing the package directly keeps
  # dotfiles/.tmux.conf the single source of truth.
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
