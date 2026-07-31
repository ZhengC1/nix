{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    baseIndex = 1;
    historyLimit = 10000;
    mouse = true;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      resurrect
    ];

    extraConfig = ''
      # Unbind default split keys
      unbind '"'
      unbind %

      # Split panes using | and -
      bind | split-window -h
      bind - split-window -v

      # Reload config file
      bind r source-file ~/.config/tmux/tmux.conf

      # Switch panes using Alt-arrow without prefix
      bind -n M-h select-pane -L
      bind -n M-l select-pane -R
      bind -n M-k select-pane -U
      bind -n M-j select-pane -D
    '';
  };

  # Install tpm (tmux plugin manager) for custom plugins
  home.packages = with pkgs; [
    tmux
  ];
}
