{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Modern CLI replacements
    bat       # better cat with syntax highlighting
    eza       # better ls with git integration
    fd        # better find
    ripgrep   # better grep

    # File & archive management
    tree
    rsync
    unzip
    zip

    # System & process inspection
    htop
    lsof
    pstree

    # Data & text processing
    jq
    yq-go

    # Network
    wget
    curl
    nmap

    # Misc dev utilities
    tmux
    gh           # GitHub CLI
    claude-code  # Claude Code CLI
    hyperfine    # benchmarking
    tokei        # count lines of code
  ];
}
