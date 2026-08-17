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

    # Containers
    #
    # On macOS the container daemon must run inside a Linux VM, so we install
    # clients here and let podman provide the VM + engine:
    #   podman machine init && podman machine start
    # podman ships a Docker-compatible API socket, so the `docker` CLI can
    # drive it — point DOCKER_HOST at the podman socket, or run
    # `podman-mac-helper` / `docker context` to wire them together.
    docker-client   # `docker` CLI only (dockerd is Linux-only; use podman's VM)
    docker-compose  # `docker compose` plugin
    podman          # rootless container engine + `podman machine` VM on macOS
  ];
}
