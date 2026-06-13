{ ... }:

{
  programs.bash = {
    enable = true;

    historyControl = [ "ignoredups" "ignorespace" ];
    historySize = 10000;
    historyFileSize = 20000;

    shellAliases = {
      ls    = "ls --color=auto";
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
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    defaultOptions = [ "--height 40%" "--border" "--reverse" ];
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };
}
