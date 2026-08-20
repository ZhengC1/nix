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
    oh-my-posh   # prompt theme engine (used by Claude Code statusLine)

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

    # Infrastructure as code
    terraform       # unfree (BUSL) — whitelisted in flake.nix's allowedUnfree

    # Cloud CLIs
    # `az` — Azure command line, with the azure-devops extension baked in.
    # (Nix installs into a read-only store, so `az extension add` won't work;
    # extensions are declared here instead.)
    (azure-cli.withExtensions [ azure-cli.extensions.azure-devops ])
  ];
}
