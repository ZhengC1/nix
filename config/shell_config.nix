{ config, lib, ... }:

{
  programs.bash = {
    enable = true;

    historyControl = [ "ignoredups" "ignorespace" ];
    historySize = 10000;
    historyFileSize = 20000;

    shellAliases = {
      ls    = if config.home.homeDirectory == "/Users/${config.home.username}" then "ls -G" else "ls --color=auto";
      ll    = "ls -alF";
      la    = "ls -A";
      l     = "ls -CF";
      grep  = "grep --color=auto";
      vim   = "nvim";
      vi    = "nvim";
      ".."  = "cd ..";
      "..." = "cd ../..";
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    initExtra = ''
      # Auto-attach to tmux if not already inside a session
      if command -v tmux &>/dev/null && [ -n "$PS1" ] && \
         [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && \
         [ -z "$TMUX" ]; then
        exec tmux
      fi
    '';
  };

  programs.zsh = {
    enable = true;

    history = {
      size = 10000;
      save = 20000;
      ignoreDups = true;
      ignoreSpace = true;
    };

    shellAliases = {
      ls    = if config.home.homeDirectory == "/Users/${config.home.username}" then "ls -G" else "ls --color=auto";
      ll    = "ls -alF";
      la    = "ls -A";
      l     = "ls -CF";
      grep  = "grep --color=auto";
      vim   = "nvim";
      vi    = "nvim";
      ".."  = "cd ..";
      "..." = "cd ../..";
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    initExtra = ''
      # Auto-attach to tmux if not already inside a session
      if command -v tmux &>/dev/null && [ -n "$PS1" ] && \
         [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && \
         [ -z "$TMUX" ]; then
        exec tmux
      fi
    '';
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    defaultOptions = [ "--height 40%" "--border" "--reverse" ];
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
