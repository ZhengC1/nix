{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Modern bash — macOS ships bash 3.2, but home-manager's generated ~/.bashrc
    # uses bash 4+ features (`shopt -s globstar`/`checkjobs`, `[[ -v ]]`), which
    # error on 3.2. Installing a current bash means interactive `bash` (resolved
    # from ~/.nix-profile/bin, ahead of /bin/bash on PATH) sources it cleanly.
    bashInteractive

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
    # tldr client is provided by programs.tealdeer below (Rust reimplementation)

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
    python3Packages.ptpython  # advanced Python REPL
    oh-my-posh   # prompt theme engine (used by Claude Code statusLine)

    # Git hooks frameworks (per-repo config lives in each project, e.g.
    # .pre-commit-config.yaml / package.json; these just provide the CLIs)
    pre-commit   # multi-language pre-commit hook manager
    husky        # git hooks for JS/Node projects

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

  # tealdeer: Rust `tldr` client, providing the `tldr` command. Replaces the
  # Python `tldr` package, which crashed with a PermissionError while probing
  # the root-owned, unreadable /usr/local/share/tldr on every lookup. tealdeer
  # only touches user/XDG cache dirs and refreshes its cache itself.
  programs.tealdeer = {
    enable = true;
    settings.updates = {
      auto_update = true;
      auto_update_interval_hours = 168;  # refresh the cache at most weekly
    };
  };
}
