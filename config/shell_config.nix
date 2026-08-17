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

    # home-manager owns ~/.profile, which drops the line the Nix installer put
    # there to source nix.sh — and bash only reads ~/.profile for login shells
    # anyway, so a plain terminal never got ~/.nix-profile/bin on PATH.
    # bashrcExtra lands at the top of ~/.bashrc, ahead of the tmux exec below.
    bashrcExtra = ''
      case ":$PATH:" in
        *":$HOME/.nix-profile/bin:"*) ;;
        *)
          if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
            . "$HOME/.nix-profile/etc/profile.d/nix.sh"
          fi
          ;;
      esac

      # Put Homebrew on PATH (Apple Silicon /opt/homebrew, Intel /usr/local).
      for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$_brew" ]; then eval "$("$_brew" shellenv)"; break; fi
      done
      unset _brew
    '';

    initExtra = ''
      # Auto-attach to tmux if not already inside a session.
      # Skip under VSCode: it runs an interactive login shell at startup to
      # resolve the shell environment, and `exec tmux` would replace that shell
      # before VSCode captures PATH — leaving it unable to find nix binaries.
      if command -v tmux &>/dev/null && [ -n "$PS1" ] && \
         [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && \
         [ "$TERM_PROGRAM" != "vscode" ] && [ -z "$VSCODE_RESOLVING_ENVIRONMENT" ] && \
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

    # Same PATH fix as bash; .zshenv is read by every zsh, login or not.
    envExtra = ''
      case ":$PATH:" in
        *":$HOME/.nix-profile/bin:"*) ;;
        *)
          if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
            emulate sh -c '. "$HOME/.nix-profile/etc/profile.d/nix.sh"'
          fi
          ;;
      esac

      # Put Homebrew on PATH (Apple Silicon /opt/homebrew, Intel /usr/local).
      for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$_brew" ]; then eval "$("$_brew" shellenv)"; break; fi
      done
      unset _brew
    '';

    # initExtra is deprecated in favour of initContent.
    initContent = ''
      # Auto-attach to tmux if not already inside a session.
      # Skip under VSCode: it runs an interactive login shell at startup to
      # resolve the shell environment, and `exec tmux` would replace that shell
      # before VSCode captures PATH — leaving it unable to find nix binaries.
      if command -v tmux &>/dev/null && [ -n "$PS1" ] && \
         [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && \
         [ "$TERM_PROGRAM" != "vscode" ] && [ -z "$VSCODE_RESOLVING_ENVIRONMENT" ] && \
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
